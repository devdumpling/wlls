package httpx

import "base:runtime"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

// Tempo's generated components discard strings.write_* results, so a failed
// allocation would otherwise truncate a render silently. Every builder we
// render into therefore uses a tracking allocator: it forwards to a backing
// allocator and records any failure, which callers check before sending.
Allocation_Tracker :: struct {
	backing: runtime.Allocator,
	failed:  bool,
}

tracking_allocator :: proc(tracker: ^Allocation_Tracker) -> runtime.Allocator {
	return runtime.Allocator{procedure = tracked, data = tracker}
}

// RENDER_BUFFER_MAX caps what one per-request render may produce. Pages that
// depend only on startup data are rendered once at boot instead; this bound is
// for responses that must be rendered per request (404, Datastar patches).
RENDER_BUFFER_MAX :: #config(WLLS_RENDER_BUFFER_MAX, 1 * mem.Megabyte)

@(private = "file")
RENDER_BUFFER_COMMIT :: 64 * mem.Kilobyte

// Render_Buffer is a builder backed by its own static virtual arena. The arena
// reserves RENDER_BUFFER_MAX of address space up front and commits pages as
// the builder grows. The builder is always the arena's most recent allocation,
// so it grows in place: no copies, no fragmentation, and a hard ceiling.
// Destroying the arena releases everything at once.
//
// The builder's allocator points into this struct, so a Render_Buffer must
// not be copied or moved after render_buffer_init.
Render_Buffer :: struct {
	arena:   virtual.Arena,
	tracker: Allocation_Tracker,
	builder: strings.Builder,
	active:  bool,
}

// render_buffer_init returns the builder to render into. If the arena cannot
// be reserved, the buffer reports failed and every write is dropped.
render_buffer_init :: proc(buffer: ^Render_Buffer) -> ^strings.Builder {
	buffer^ = {active = true}
	if virtual.arena_init_static(&buffer.arena, RENDER_BUFFER_MAX, RENDER_BUFFER_COMMIT) != nil {
		buffer.tracker = {backing = runtime.nil_allocator(), failed = true}
	} else {
		buffer.tracker.backing = virtual.arena_allocator(&buffer.arena)
	}
	buffer.builder = strings.builder_make(tracking_allocator(&buffer.tracker))
	return &buffer.builder
}

render_buffer_failed :: proc(buffer: ^Render_Buffer) -> bool {
	return buffer.tracker.failed
}

render_buffer_bytes :: proc(buffer: ^Render_Buffer) -> []u8 {
	return buffer.builder.buf[:]
}

// render_buffer_destroy is safe to call more than once.
render_buffer_destroy :: proc(buffer: ^Render_Buffer) {
	if !buffer.active do return
	virtual.arena_destroy(&buffer.arena)
	buffer^ = {}
}

@(private = "file")
tracked :: proc(
	data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]byte,
	runtime.Allocator_Error,
) {
	tracker := cast(^Allocation_Tracker)data
	bytes, error := tracker.backing.procedure(
		tracker.backing.data,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
		location,
	)
	// Arenas cannot free individual allocations; that is not a render failure.
	if error != nil && error != .Mode_Not_Implemented do tracker.failed = true
	return bytes, error
}
