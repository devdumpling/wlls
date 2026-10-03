package app

import httpx "../httpx"
import views "../views"
import "core:fmt"
import "core:mem/virtual"
import "core:strings"

// #lobby, the terminal's chatroom. `msg` joins; every line typed after that is
// a message (or a :command); `:q` leaves, as does closing your last page. Everything is in
// memory and gone on deploy: the last CHAT_LINES lines, who is in the room,
// and who is muted. Like the frames, it is state isolates share (live.odin):
// /terminal POSTs post messages, and the hub posts "left" lines.
//
// Membership is per visitor, not per page, so the room follows you from page
// to page: a new page's stream sees you are in #lobby and opens the chat
// prompt itself.

CHAT_LINES :: 40
CHAT_TEXT_MAX :: 200 // characters
@(private = "file")
CHAT_MEMBERS_MAX :: 128
@(private = "file")
CHAT_MUTED_MAX :: 32
// Each visitor gets a burst of CHAT_BURST room actions (joining, talking,
// renaming), then one per CHAT_INTERVAL_NS. Limits are kept apart from
// membership, so leaving and rejoining doesn't reset them.
@(private = "file")
CHAT_INTERVAL_NS :: 1_000_000_000
@(private = "file")
CHAT_BURST :: 5
@(private = "file")
CHAT_LIMITS_MAX :: 256

Chat :: struct {
	lines:        [CHAT_LINES]Chat_Line, // a ring; the oldest is overwritten
	first, count: int,
	members:      [CHAT_MEMBERS_MAX]Chat_Member,
	member_count: int,
	muted:        [CHAT_MUTED_MAX]Visitor,
	muted_count:  int,
	limits:       [CHAT_LIMITS_MAX]Chat_Limit, // the oldest is reused when full
	next_limit:   int,
}

Chat_Line_Kind :: enum u8 {
	Message,
	Joined,
	Left,
	Renamed, // text is the new name
}

Chat_Line :: struct {
	kind:      Chat_Line_Kind,
	root:      bool, // said by root, who always shows as dev
	visitor:   Visitor,
	name:      Name, // as they were named when they said it
	text:      [CHAT_TEXT_MAX * 4]u8, // UTF-8
	text_size: u16,
}

Chat_Member :: struct {
	visitor: Visitor,
	root:    bool,
}

@(private = "file")
Chat_Limit :: struct {
	visitor:  Visitor,
	// When the next action is allowed without dipping into the burst; each
	// action moves it CHAT_INTERVAL_NS later.
	ready_at: u64,
}

// chat_allow spends one of a visitor's room actions, or reports that they
// are going too fast.
chat_allow :: proc(chat: ^Chat, visitor: Visitor, now: u64) -> bool {
	limit := &chat.limits[chat.next_limit]
	for &candidate in chat.limits {
		if candidate.visitor == visitor {
			limit = &candidate
			break
		}
	}
	if limit.visitor != visitor {
		limit^ = {
			visitor = visitor,
		}
		chat.next_limit = (chat.next_limit + 1) % len(chat.limits)
	}
	if limit.ready_at > now + (CHAT_BURST - 1) * CHAT_INTERVAL_NS do return false
	limit.ready_at = max(limit.ready_at, now) + CHAT_INTERVAL_NS
	return true
}

chat_is_member :: proc(chat: ^Chat, visitor: Visitor) -> bool {
	_, found := find_member(chat, visitor)
	return found
}

Join_Result :: enum {
	Joined,
	Already_Here,
	Too_Fast,
	Full,
}

// chat_join adds a visitor to #lobby.
chat_join :: proc(live: ^Live, visitor: Visitor, root: bool, now: u64) -> Join_Result {
	chat := &live.chat
	if chat_is_member(chat, visitor) do return .Already_Here
	if chat.member_count == len(chat.members) do return .Full
	if !chat_allow(chat, visitor, now) do return .Too_Fast
	chat.members[chat.member_count] = {
		visitor = visitor,
		root    = root,
	}
	chat.member_count += 1
	post(
		chat,
		{kind = .Joined, root = root, visitor = visitor, name = chat_name(live, visitor, root)},
	)
	return .Joined
}

// chat_leave removes a visitor from #lobby; false if they weren't in it.
chat_leave :: proc(live: ^Live, visitor: Visitor) -> bool {
	chat := &live.chat
	index := find_member(chat, visitor) or_return
	member := chat.members[index]
	chat.member_count -= 1
	chat.members[index] = chat.members[chat.member_count]
	post(
		chat,
		{
			kind = .Left,
			root = member.root,
			visitor = visitor,
			name = chat_name(live, visitor, member.root),
		},
	)
	return true
}

Say_Result :: enum {
	Sent,
	Invalid, // empty, too long, or not text
	Too_Fast,
	Muted,
	Not_Member,
}

chat_say :: proc(live: ^Live, visitor: Visitor, root: bool, text: string, now: u64) -> Say_Result {
	chat := &live.chat
	for muted in chat.muted[:chat.muted_count] {
		if muted == visitor do return .Muted
	}
	if !is_plain_text(text, CHAT_TEXT_MAX, multiline = false) do return .Invalid
	if !chat_is_member(chat, visitor) do return .Not_Member
	if !chat_allow(chat, visitor, now) do return .Too_Fast

	line := Chat_Line {
		kind    = .Message,
		root    = root,
		visitor = visitor,
		name    = chat_name(live, visitor, root),
	}
	line.text_size = u16(copy(line.text[:], text))
	post(chat, line)
	return .Sent
}

// chat_renamed notes a nick change in the room, if the visitor is in it.
chat_renamed :: proc(live: ^Live, visitor: Visitor, old: Name) -> bool {
	chat := &live.chat
	index := find_member(chat, visitor) or_return
	if chat.members[index].root do return false // root shows as dev regardless
	line := Chat_Line {
		kind    = .Renamed,
		visitor = visitor,
		name    = old,
	}
	new := display_name(&live.nicks, visitor)
	line.text_size = u16(copy(line.text[:], name_string(&new)))
	post(chat, line)
	return true
}

// chat_find resolves a name as it appears in the room to a visitor: someone
// here, or else whoever said something under that name most recently (so a
// spammer who already left can still be cleaned up).
chat_find :: proc(live: ^Live, name: string) -> (visitor: Visitor, found: bool) {
	chat := &live.chat
	for member in chat.members[:chat.member_count] {
		shown := chat_name(live, member.visitor, member.root)
		if name_string(&shown) == name do return member.visitor, true
	}
	for offset := chat.count - 1; offset >= 0; offset -= 1 {
		line := &chat.lines[(chat.first + offset) % CHAT_LINES]
		if line.kind == .Message && name_string(&line.name) == name do return line.visitor, true
	}
	return 0, false
}

chat_mute :: proc(chat: ^Chat, visitor: Visitor) -> bool {
	for muted in chat.muted[:chat.muted_count] {
		if muted == visitor do return true
	}
	if chat.muted_count == len(chat.muted) do return false
	chat.muted[chat.muted_count] = visitor
	chat.muted_count += 1
	return true
}

chat_unmute :: proc(chat: ^Chat, visitor: Visitor) -> bool {
	for muted, index in chat.muted[:chat.muted_count] {
		if muted != visitor do continue
		chat.muted_count -= 1
		chat.muted[index] = chat.muted[chat.muted_count]
		return true
	}
	return false
}

// chat_remove deletes a visitor's messages from the history, closing the
// gaps in place: kept lines only ever move toward the front.
chat_remove :: proc(chat: ^Chat, visitor: Visitor) -> (removed: int) {
	kept := 0
	for offset in 0 ..< chat.count {
		line := &chat.lines[(chat.first + offset) % CHAT_LINES]
		if line.kind == .Message && line.visitor == visitor {
			removed += 1
			continue
		}
		if kept != offset do chat.lines[(chat.first + kept) % CHAT_LINES] = line^
		kept += 1
	}
	chat.count = kept
	return
}

chat_wipe :: proc(chat: ^Chat) {
	chat.first, chat.count = 0, 0
}

// chat_members lists who is in the room, as names, for :who.
chat_members :: proc(live: ^Live, allocator := context.temp_allocator) -> string {
	builder := strings.builder_make(allocator)
	for member, index in live.chat.members[:live.chat.member_count] {
		if index > 0 do strings.write_string(&builder, ", ")
		name := chat_name(live, member.visitor, member.root)
		strings.write_string(&builder, name_string(&name))
	}
	return strings.to_string(builder)
}

// chat_render renders the room into its frame: the newest lines that fit.
chat_render :: proc(live: ^Live) -> bool {
	chat := &live.chat
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil do return false
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	lines := make([]views.Chat_Row, chat.count, allocator)
	for offset in 0 ..< chat.count {
		line := &chat.lines[(chat.first + offset) % CHAT_LINES]
		name := name_string(&line.name)
		text := string(line.text[:line.text_size])
		view := views.Chat_Row {
			name = strings.clone(name, allocator),
			root = line.root,
		}
		switch line.kind {
		case .Message:
			view.text = strings.clone(text, allocator)
		case .Joined:
			view.event = fmt.aprintf("%s joined", name, allocator = allocator)
		case .Left:
			view.event = fmt.aprintf("%s left", name, allocator = allocator)
		case .Renamed:
			view.event = fmt.aprintf("%s is now %s", name, text, allocator = allocator)
		}
		lines[offset] = view
	}
	summary := fmt.aprintf("#lobby · %d here", chat.member_count, allocator = allocator)

	// Long lines can outgrow one frame; drop the oldest until they fit.
	for start := 0;; start = start * 2 + 1 {
		buffer: httpx.Render_Buffer
		writer := httpx.render_buffer_init(&buffer)
		views.terminal_chat(writer, lines[min(start, len(lines)):], summary)
		fits :=
			!httpx.render_buffer_failed(&buffer) &&
			len(httpx.render_buffer_bytes(&buffer)) <= FRAME_MAX
		stored := fits && frame_store(&live.frames[.Chat], &buffer)
		httpx.render_buffer_destroy(&buffer)
		if stored do return true
		if start >= len(lines) do return false
	}
}

// chat_name is how a visitor shows in the room: root is always dev.
@(private = "file")
chat_name :: proc(live: ^Live, visitor: Visitor, root: bool) -> Name {
	return name_of("dev") if root else display_name(&live.nicks, visitor)
}

@(private = "file")
find_member :: proc(chat: ^Chat, visitor: Visitor) -> (index: int, found: bool) {
	for member, member_index in chat.members[:chat.member_count] {
		if member.visitor == visitor do return member_index, true
	}
	return -1, false
}

@(private = "file")
post :: proc(chat: ^Chat, line: Chat_Line) {
	if chat.count < CHAT_LINES {
		chat.lines[(chat.first + chat.count) % CHAT_LINES] = line
		chat.count += 1
	} else {
		chat.lines[chat.first] = line
		chat.first = (chat.first + 1) % CHAT_LINES
	}
}
