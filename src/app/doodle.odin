package app

import httpx "../httpx"
import sqlite "../sqlite"
import views "../views"
import "core:fmt"

// The doodle: one shared, two-colour pixel board on /guestbook that anyone
// there can draw on, live. <sb-pixel-board> (vendored from Starbase) sends
// each stroke as a batch of cells; the server applies it, saves the board,
// and renders the Doodle frame, which every open /guestbook page morphs in.
// The board is the server's: a painter's own pixels show as pending until
// that frame confirms them.
//
// It lives beside the guestbook because it shares its database (one row) and
// its page. Like the frames, it is state isolates share, which is safe on
// one shard (see live.odin).

DOODLE_SIDE :: 32
DOODLE_CELLS :: DOODLE_SIDE * DOODLE_SIDE
// The component sends at most 60 cells per stroke batch.
DOODLE_BATCH_MAX :: 60
// A stroke sends a batch every 80 ms, so a visitor gets a burst of
// DOODLE_BURST batches, then one per DOODLE_INTERVAL_NS: enough to draw
// freely, not enough to flood the board.
@(private = "file")
DOODLE_INTERVAL_NS :: 50_000_000
@(private = "file")
DOODLE_BURST :: 40
@(private = "file")
DOODLE_LIMITS_MAX :: 128

Doodle :: struct {
	// One ASCII hex digit per cell, row by row: the component's own format,
	// so the board is stored and sent as is. '0' is blank, '1' is ink.
	cells:      [DOODLE_CELLS]u8,
	limits:     [DOODLE_LIMITS_MAX]Doodle_Limit, // the oldest is reused when full
	next_limit: int,
}

@(private = "file")
Doodle_Limit :: struct {
	visitor:  Visitor,
	ready_at: u64, // as for Chat_Limit: each batch moves it one interval later
}

Paint_Result :: enum {
	Painted,
	Unchanged, // every cell was that colour already
	Too_Fast,
	Failed, // the board changed but couldn't be saved
}

// doodle_load reads the saved board, or starts blank.
doodle_load :: proc(guestbook: ^Guestbook) {
	doodle := &guestbook.doodle
	for &cell in doodle.cells do cell = '0'
	stmt, prepared := sqlite.prepare(guestbook.db, "SELECT cells FROM doodle WHERE id = 1")
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing doodle load")
		return
	}
	defer sqlite.finalize(stmt)
	if sqlite.step(stmt) != sqlite.ROW do return
	saved := sqlite.column_string(stmt, 0)
	if len(saved) != DOODLE_CELLS do return
	for character, index in transmute([]u8)saved {
		doodle.cells[index] = character == '1' ? '1' : '0'
	}
}

// doodle_paint applies one batch of cells in one colour (0 or 1; the caller
// checks the batch) and saves the board if it changed.
doodle_paint :: proc(
	guestbook: ^Guestbook,
	visitor: Visitor,
	color: int,
	cells: []int,
	now: u64,
) -> Paint_Result {
	doodle := &guestbook.doodle
	if !doodle_allow(doodle, visitor, now) do return .Too_Fast
	digit := u8('0' + color)
	changed := false
	for index in cells {
		changed ||= doodle.cells[index] != digit
		doodle.cells[index] = digit
	}
	if !changed do return .Unchanged
	return doodle_save(guestbook) ? .Painted : .Failed
}

// doodle_wipe blanks the board: root's `wipe doodle`.
doodle_wipe :: proc(guestbook: ^Guestbook) -> bool {
	for &cell in guestbook.doodle.cells do cell = '0'
	return doodle_save(guestbook)
}

// doodle_render renders the board into its frame.
doodle_render :: proc(guestbook: ^Guestbook, frame: ^Frame) -> bool {
	buffer: httpx.Render_Buffer
	defer httpx.render_buffer_destroy(&buffer)
	views.guestbook_doodle(
		httpx.render_buffer_init(&buffer),
		string(guestbook.doodle.cells[:]),
		fmt.tprint(DOODLE_SIDE),
	)
	return frame_store(frame, &buffer)
}

@(private = "file")
doodle_save :: proc(guestbook: ^Guestbook) -> bool {
	stmt, prepared := sqlite.prepare(
		guestbook.db,
		"INSERT OR REPLACE INTO doodle (id, cells) VALUES (1, ?1)",
	)
	if prepared != sqlite.OK {
		log_failure(guestbook, "preparing doodle save")
		return false
	}
	defer sqlite.finalize(stmt)
	sqlite.bind_string(stmt, 1, string(guestbook.doodle.cells[:]))
	if sqlite.step(stmt) != sqlite.DONE {
		log_failure(guestbook, "saving the doodle")
		return false
	}
	return true
}

// doodle_allow spends one of a visitor's stroke batches, or reports that
// they are going too fast. It works like chat_allow.
@(private = "file")
doodle_allow :: proc(doodle: ^Doodle, visitor: Visitor, now: u64) -> bool {
	limit := &doodle.limits[doodle.next_limit]
	for &candidate in doodle.limits {
		if candidate.visitor == visitor {
			limit = &candidate
			break
		}
	}
	if limit.visitor != visitor {
		limit^ = {
			visitor = visitor,
		}
		doodle.next_limit = (doodle.next_limit + 1) % len(doodle.limits)
	}
	if limit.ready_at > now + (DOODLE_BURST - 1) * DOODLE_INTERVAL_NS do return false
	limit.ready_at = max(limit.ready_at, now) + DOODLE_INTERVAL_NS
	return true
}
