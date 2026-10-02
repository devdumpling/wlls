// Package sqlite binds the few SQLite C calls the app uses. Odin ships no
// SQLite bindings, and the API needed is small: open a database, run
// statements, and read rows. SQLite calls block their thread. The app runs
// them from Tina handlers anyway: on one shard every handler shares the thread,
// a write commits in about a millisecond, and Tina's watchdog only steps in
// after a ~1 s stall. The busy timeout keeps a locked database (say, during a
// backup) from ever stalling that long.
package sqlite

import "core:c"
import "core:strings"

foreign import lib "system:sqlite3"

DB :: struct {}
Stmt :: struct {}

// Result is SQLite's result code. Only the codes the app checks are named.
Result :: distinct c.int
OK :: Result(0)
BUSY :: Result(5)
ROW :: Result(100)
DONE :: Result(101)

OPEN_READWRITE :: c.int(0x00000002)
OPEN_CREATE :: c.int(0x00000004)

// STATIC tells bind_text that the text outlives the statement's use of it,
// so SQLite reads it in place instead of copying.
@(private = "file")
STATIC :: rawptr(uintptr(0))

@(default_calling_convention = "c", link_prefix = "sqlite3_")
foreign lib {
	open_v2 :: proc(filename: cstring, db: ^^DB, flags: c.int, vfs: cstring) -> Result ---
	close_v2 :: proc(db: ^DB) -> Result ---
	exec :: proc(db: ^DB, sql: cstring, callback: rawptr, argument: rawptr, error: ^cstring) -> Result ---
	busy_timeout :: proc(db: ^DB, milliseconds: c.int) -> Result ---
	errmsg :: proc(db: ^DB) -> cstring ---
	changes :: proc(db: ^DB) -> c.int ---
	prepare_v2 :: proc(db: ^DB, sql: [^]u8, size: c.int, stmt: ^^Stmt, tail: ^[^]u8) -> Result ---
	bind_text :: proc(stmt: ^Stmt, index: c.int, text: [^]u8, size: c.int, destructor: rawptr) -> Result ---
	bind_int64 :: proc(stmt: ^Stmt, index: c.int, value: i64) -> Result ---
	step :: proc(stmt: ^Stmt) -> Result ---
	finalize :: proc(stmt: ^Stmt) -> Result ---
	column_int64 :: proc(stmt: ^Stmt, column: c.int) -> i64 ---
	column_text :: proc(stmt: ^Stmt, column: c.int) -> [^]u8 ---
	column_bytes :: proc(stmt: ^Stmt, column: c.int) -> c.int ---
}

// prepare compiles one statement from an Odin string (no NUL needed).
prepare :: proc(db: ^DB, sql: string) -> (stmt: ^Stmt, result: Result) {
	result = prepare_v2(db, raw_data(sql), c.int(len(sql)), &stmt, nil)
	return
}

// bind_string binds text without copying it. The string must stay valid
// until the statement is stepped; values from the current request do.
bind_string :: proc(stmt: ^Stmt, index: int, value: string) -> Result {
	return bind_text(stmt, c.int(index), raw_data(value), c.int(len(value)), STATIC)
}

// column_string borrows a text column. SQLite reuses the memory on the next
// step, reset, or finalize, so clone what must last longer.
column_string :: proc(stmt: ^Stmt, column: int) -> string {
	text := column_text(stmt, c.int(column))
	if text == nil do return ""
	return strings.string_from_ptr(text, int(column_bytes(stmt, c.int(column))))
}

// message is the last error on db, for logs.
message :: proc(db: ^DB) -> string {
	return string(errmsg(db))
}
