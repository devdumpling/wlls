package app

import httpx "../httpx"
import sqlite "../sqlite"
import views "../views"
import "core:fmt"
import "core:hash"
import "core:mem/virtual"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

// The guestbook: visitors sign, I approve from the terminal, and approved
// entries appear live for everyone on /guestbook. Signing, approving, and
// rejecting are commands against SQLite. The read side is the Guestbook frame,
// rendered from the database at startup and after every approval, so there
// is no in-memory list to keep in step with the table.
//
// Like the live frames, this state is shared by every connection isolate,
// which is safe on one shard (see live.odin).

// Production runs in /var/lib/wlls (systemd's StateDirectory).
DATABASE_PATH :: "bin/guestbook.db" when WLLS_DEV else "guestbook.db"

GUESTBOOK_NAME_MAX :: 40 // characters
GUESTBOOK_MESSAGE_MAX :: 280
// Past this many unread entries, signing pauses until I catch up.
GUESTBOOK_PENDING_MAX :: 100
// The frame shows the newest approved entries, fewer if they outgrow it.
GUESTBOOK_SHOWN_MAX :: 50
// One signature per visitor, and per network address, every ten minutes.
SIGN_INTERVAL_NS :: 10 * 60 * 1_000_000_000

Guestbook :: struct {
	db:     ^sqlite.DB,
	recent: [32]Signature, // recent signers, oldest overwritten first
	next:   int,
}

@(private = "file")
Signature :: struct {
	key: u64, // a visitor id or a hash of the client address
	at:  u64, // monotonic ns
}

@(private = "file")
SCHEMA :: `
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
CREATE TABLE IF NOT EXISTS entries (
	id         INTEGER PRIMARY KEY,
	name       TEXT    NOT NULL,
	message    TEXT    NOT NULL,
	visitor    TEXT    NOT NULL,
	created_at INTEGER NOT NULL DEFAULT (unixepoch()),
	status     TEXT    NOT NULL DEFAULT 'pending'
	           CHECK (status IN ('pending', 'approved', 'rejected'))
);
CREATE INDEX IF NOT EXISTS entries_by_status ON entries (status, id);
`

guestbook_open :: proc(guestbook: ^Guestbook, path: cstring) -> (error: string) {
	if sqlite.open_v2(path, &guestbook.db, sqlite.OPEN_READWRITE | sqlite.OPEN_CREATE, nil) !=
	   sqlite.OK {
		return fmt.tprintf("opening %s: %s", path, sqlite.message(guestbook.db))
	}
	sqlite.busy_timeout(guestbook.db, 100)
	if sqlite.exec(guestbook.db, SCHEMA, nil, nil, nil) != sqlite.OK {
		return fmt.tprintf("creating the guestbook schema: %s", sqlite.message(guestbook.db))
	}
	return ""
}

guestbook_close :: proc(guestbook: ^Guestbook) {
	sqlite.close_v2(guestbook.db)
	guestbook.db = nil
}

Sign_Result :: enum {
	Signed,
	Invalid, // empty, too long, or not text
	Too_Soon,
	Full, // too many entries waiting for me
	Failed,
}

// sign_reply is what signing says back, on the page and in the terminal.
sign_reply :: proc(result: Sign_Result) -> string {
	switch result {
	case .Signed:
		return "Signed. It will appear once I've read it."
	case .Too_Soon:
		return "You signed a moment ago. Try again in a few minutes."
	case .Full:
		return "Lots of unread notes right now. Try again later."
	case .Invalid:
		return "A name (up to 40 characters) and a note (up to 280) are both needed."
	case .Failed:
	}
	return "That didn't work on my end. Try again in a bit."
}

// guestbook_sign records a pending entry. client is the visitor's network
// address as Caddy reports it ("" when unknown); now is monotonic ns.
guestbook_sign :: proc(
	guestbook: ^Guestbook,
	name, message: string,
	visitor: Visitor,
	client: string,
	now: u64,
) -> Sign_Result {
	// Browsers submit a textarea's line breaks as CRLF.
	unix_message, _ := strings.replace_all(message, "\r\n", "\n", context.temp_allocator)
	entry_name, entry_message := strings.trim_space(name), strings.trim_space(unix_message)
	if !is_plain_text(entry_name, GUESTBOOK_NAME_MAX, multiline = false) ||
	   !is_plain_text(entry_message, GUESTBOOK_MESSAGE_MAX, multiline = true) {
		return .Invalid
	}

	keys := [2]u64{u64(visitor), client == "" ? 0 : hash.fnv64a(transmute([]u8)client)}
	for signature in guestbook.recent {
		if signature.key == 0 || now - signature.at >= SIGN_INTERVAL_NS do continue
		if signature.key == keys[0] || signature.key == keys[1] do return .Too_Soon
	}

	pending, ok := count_pending(guestbook)
	if !ok do return .Failed
	if pending >= GUESTBOOK_PENDING_MAX do return .Full

	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"INSERT INTO entries (name, message, visitor) VALUES (?1, ?2, ?3)",
	)
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing sign")
		return .Failed
	}
	defer sqlite.finalize(stmt)
	visitor_hex: [16]u8
	sqlite.bind_string(stmt, 1, entry_name)
	sqlite.bind_string(stmt, 2, entry_message)
	sqlite.bind_string(stmt, 3, fmt.bprintf(visitor_hex[:], "%016x", u64(visitor)))
	if sqlite.step(stmt) != sqlite.DONE {
		log_failure(guestbook, "signing")
		return .Failed
	}

	for key in keys {
		if key == 0 do continue
		guestbook.recent[guestbook.next] = {key, now}
		guestbook.next = (guestbook.next + 1) % len(guestbook.recent)
	}
	return .Signed
}

// guestbook_render renders the newest approved entries into the frame.
guestbook_render :: proc(guestbook: ^Guestbook, frame: ^Frame) -> bool {
	// The rows are copied out of SQLite into an arena that lives for this
	// render only; one call frees them all.
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil do return false
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"SELECT name, message, created_at FROM entries WHERE status = 'approved' ORDER BY id DESC LIMIT ?1",
	)
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing render")
		return false
	}
	entries := make([dynamic]views.Guestbook_Entry, 0, GUESTBOOK_SHOWN_MAX, allocator)
	sqlite.bind_int64(stmt, 1, GUESTBOOK_SHOWN_MAX)
	for sqlite.step(stmt) == sqlite.ROW {
		year, month, day := time.date(time.unix(sqlite.column_int64(stmt, 2), 0))
		append(
			&entries,
			views.Guestbook_Entry {
				name = strings.clone(sqlite.column_string(stmt, 0), allocator),
				message = strings.clone(sqlite.column_string(stmt, 1), allocator),
				date = fmt.aprintf("%04d-%02d-%02d", year, int(month), day, allocator = allocator),
			},
		)
	}
	sqlite.finalize(stmt)

	// Long entries can outgrow one frame; show fewer until they fit.
	for count := len(entries);; count /= 2 {
		buffer: httpx.Render_Buffer
		writer := httpx.render_buffer_init(&buffer)
		views.guestbook_entries(writer, entries[:count])
		fits :=
			!httpx.render_buffer_failed(&buffer) &&
			len(httpx.render_buffer_bytes(&buffer)) <= FRAME_MAX
		stored := fits && frame_store(frame, &buffer)
		httpx.render_buffer_destroy(&buffer)
		if stored do return true
		if count == 0 do return false
	}
}

// The terminal lists this many unread entries at a time, each cut short.
@(private = "file")
PENDING_SHOWN_MAX :: 20
@(private = "file")
PENDING_PREVIEW_MAX :: 80 // characters

// guestbook_pending lists the oldest unread entries for `pending`, copied
// into allocator, along with how many are waiting in all.
guestbook_pending :: proc(
	guestbook: ^Guestbook,
	allocator := context.allocator,
) -> (
	entries: []views.Pending_Entry,
	total: int,
	ok: bool,
) {
	total = count_pending(guestbook) or_return
	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"SELECT id, name, message FROM entries WHERE status = 'pending' ORDER BY id LIMIT ?1",
	)
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing pending")
		return
	}
	defer sqlite.finalize(stmt)
	sqlite.bind_int64(stmt, 1, PENDING_SHOWN_MAX)
	list := make([dynamic]views.Pending_Entry, 0, PENDING_SHOWN_MAX, allocator)
	for sqlite.step(stmt) == sqlite.ROW {
		append(
			&list,
			views.Pending_Entry {
				label = fmt.aprintf(
					"#%d %s",
					sqlite.column_int64(stmt, 0),
					sqlite.column_string(stmt, 1),
					allocator = allocator,
				),
				message = preview(sqlite.column_string(stmt, 2), allocator),
			},
		)
	}
	return list[:], total, true
}

Moderation :: enum {
	Done,
	Not_Found, // no unread entry with that id
	Failed,
}

// guestbook_moderate approves or rejects an unread entry. An approval also
// re-renders the frame; the caller publishes it.
guestbook_moderate :: proc(
	guestbook: ^Guestbook,
	id: i64,
	approve: bool,
	frame: ^Frame,
) -> Moderation {
	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"UPDATE entries SET status = ?1 WHERE id = ?2 AND status = 'pending'",
	)
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing moderation")
		return .Failed
	}
	defer sqlite.finalize(stmt)
	sqlite.bind_string(stmt, 1, approve ? "approved" : "rejected")
	sqlite.bind_int64(stmt, 2, id)
	if sqlite.step(stmt) != sqlite.DONE {
		log_failure(guestbook, "moderating")
		return .Failed
	}
	if sqlite.changes(guestbook.db) != 1 do return .Not_Found
	if approve && !guestbook_render(guestbook, frame) do return .Failed
	return .Done
}

// preview cuts text to PENDING_PREVIEW_MAX characters, on one line.
@(private = "file")
preview :: proc(text: string, allocator := context.allocator) -> string {
	builder := strings.builder_make(0, len(text), allocator)
	count := 0
	for character in text {
		if count == PENDING_PREVIEW_MAX {
			strings.write_string(&builder, "…")
			break
		}
		strings.write_rune(&builder, character == '\n' ? ' ' : character)
		count += 1
	}
	return strings.to_string(builder)
}

// is_plain_text accepts 1–limit characters of valid UTF-8 with no control
// characters (multiline text may keep its line breaks).
@(private)
is_plain_text :: proc(text: string, limit: int, multiline: bool) -> bool {
	if text == "" || !utf8.valid_string(text) do return false
	count := 0
	for character in text {
		count += 1
		if count > limit do return false
		if character == '\n' && multiline do continue
		if character < ' ' || character == 0x7f do return false
	}
	return true
}

@(private = "file")
count_pending :: proc(guestbook: ^Guestbook) -> (count: int, ok: bool) {
	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"SELECT count(*) FROM entries WHERE status = 'pending'",
	)
	if prepared != sqlite.OK do return 0, false
	defer sqlite.finalize(stmt)
	if sqlite.step(stmt) != sqlite.ROW do return 0, false
	return int(sqlite.column_int64(stmt, 0)), true
}

@(private = "file")
log_failure :: proc(guestbook: ^Guestbook, doing: string) {
	fmt.eprintfln("wlls: guestbook %s: %s", doing, sqlite.message(guestbook.db))
}
