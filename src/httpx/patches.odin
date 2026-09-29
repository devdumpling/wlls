package httpx

import datastar "../../vendor/tina/src/extensions/http/datastar"
import http "../../vendor/tina/src/extensions/http/server"
import "core:fmt"
import "core:strings"

// A Datastar response is a short SSE stream of events. The SDK writes each
// event into Tina's egress buffer in one piece (no allocation, never half an
// event), so two things follow:
//
//   - One event can be at most HTTP_EGRESS_BUFFER_SIZE minus chunk framing.
//     The build raises the buffer to 16 KiB for room to send coarse patches.
//   - A later event may not fit until earlier ones reach the client. The SDK
//     then reports .Backpressured, and we resume on Send_Ready.
//
// Patch_Stream holds a response's events until each is sent: queue them all
// on Request_Start, then send_patches drains as far as Tina allows. Event
// bodies live in one Render_Buffer and are referenced by byte range.
PATCH_STREAM_MAX :: 8

// EGRESS_BUFFER_SIZE reads the same build define as Tina's (private)
// HTTP_EGRESS_BUFFER_SIZE, with the same default, so the two always agree.
EGRESS_BUFFER_SIZE :: #config(HTTP_EGRESS_BUFFER_SIZE, 4096)

Patch_Stream :: struct {
	render:  Render_Buffer,
	events:  [PATCH_STREAM_MAX]Patch_Event,
	count:   int,
	next:    int, // first event not yet sent
	mark:    int, // render offset where the next queued event begins
	failed:  bool,
	active:  bool,
	started: bool,
}

Patch_Kind :: enum u8 {
	Elements,
	Script,
}

Patch_Event :: struct {
	kind:       Patch_Kind,
	start, end: int, // byte range of the event body in the render buffer
	options:    datastar.Patch_Elements_Options,
}

// begin_patches returns the builder that queued events render into.
begin_patches :: proc(stream: ^Patch_Stream) -> ^strings.Builder {
	stream^ = {
		active = true,
	}
	return render_buffer_init(&stream.render)
}

// queue_elements queues everything rendered since the previous queue call as
// one patch-elements event.
queue_elements :: proc(stream: ^Patch_Stream, options: datastar.Patch_Elements_Options = {}) {
	queue(stream, .Elements, options)
}

// queue_script queues a script for the browser to run once.
queue_script :: proc(stream: ^Patch_Stream, script: string) {
	strings.write_string(&stream.render.builder, script)
	queue(stream, .Script, {})
}

@(private = "file")
queue :: proc(stream: ^Patch_Stream, kind: Patch_Kind, options: datastar.Patch_Elements_Options) {
	end := strings.builder_len(stream.render.builder)
	if stream.count == len(stream.events) {
		stream.failed = true
		return
	}
	stream.events[stream.count] = {
		kind    = kind,
		start   = stream.mark,
		end     = end,
		options = options,
	}
	stream.count += 1
	stream.mark = end
}

// send_patches starts the SSE response once, then sends queued events in
// order until they are all out or Tina asks us to wait for Send_Ready.
send_patches :: proc(response: ^http.Response, stream: ^Patch_Stream) -> http.Route_Step {
	if !stream.active do return http.close()
	if !stream.started {
		if stream.failed || render_buffer_failed(&stream.render) {
			destroy_patches(stream)
			return respond_text(
				response,
				http.HTTP_STATUS_INTERNAL_SERVER_ERROR,
				"rendering failed\n",
			)
		}
		set_security_headers(response)
		if _, error := datastar.start_sse(response); error != .None {
			destroy_patches(stream)
			return http.close()
		}
		stream.started = true
	}

	sse := datastar.resume(response)
	body := string(render_buffer_bytes(&stream.render))
	for stream.next < stream.count {
		event := stream.events[stream.next]
		text := body[event.start:event.end]
		error: datastar.SSE_Send_Error
		switch event.kind {
		case .Elements:
			error = datastar.patch_elements(&sse, text, event.options)
		case .Script:
			error = datastar.execute_script(&sse, text)
		}
		#partial switch error {
		case .None:
			stream.next += 1
		case .Backpressured:
			return http.flush()
		case:
			// The stream has begun, so there is no status left to change. End it
			// cleanly; patches already sent stand. Body_Too_Large here means an
			// event outgrew HTTP_EGRESS_BUFFER_SIZE: split it or raise the limit.
			fmt.eprintfln(
				"wlls: datastar event %d of %d not sent: %v",
				stream.next + 1,
				stream.count,
				error,
			)
			destroy_patches(stream)
			return http.flush(final = true)
		}
	}
	destroy_patches(stream)
	return http.flush(final = true)
}

// drive_patches handles every event after Request_Start for a Patch_Stream.
drive_patches :: proc(
	event: http.Route_Event,
	response: ^http.Response,
	stream: ^Patch_Stream,
) -> http.Route_Step {
	#partial switch _ in event {
	case http.Send_Ready:
		return send_patches(response, stream)
	}
	destroy_patches(stream)
	return http.close()
}

// destroy_patches is shared by completion and interrupted requests; safe to repeat.
destroy_patches :: proc(stream: ^Patch_Stream) {
	if !stream.active do return
	render_buffer_destroy(&stream.render)
	stream^ = {}
}
