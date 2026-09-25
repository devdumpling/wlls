package httpx

import http "../../vendor/tina/src/extensions/http/server"
import "base:runtime"
import "core:strings"

// Document_Stream owns a rendered page until Tina has copied every byte into
// its connection buffer. The body can therefore be much larger than that
// buffer, while each individual write remains bounded by Tina's egress size.
Document_Stream :: struct {
	body:          strings.Builder,
	bytes:         []u8,
	offset:        int,
	content_type:  string,
	status:        http.HTTP_Status,
	initialized:   bool,
	owns_body:     bool,
	render_failed: bool,
	started:       bool,
}

// document_begin prepares an owned, growable render buffer before a view is
// rendered. Tempo components write into this builder just as they do into a
// fixed one, but long posts no longer get silently truncated at a capacity.
document_begin :: proc(stream: ^Document_Stream, status: http.HTTP_Status, content_type: string) {
	stream^ = Document_Stream {
		content_type = content_type,
		status       = status,
		initialized  = true,
		owns_body    = true,
	}
	// Tina's request allocator is deliberately small. This response-owned
	// builder uses the heap instead; the wrapper records allocation failures
	// even though Tempo's generated write calls discard their return values.
	allocator := runtime.Allocator {
		procedure = tracked_heap,
		data      = &stream.render_failed,
	}
	_, error := strings.builder_init(&stream.body, allocator)
	if error != nil do stream.render_failed = true
}

@(private = "file")
tracked_heap :: proc(
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
	bytes, error := runtime.heap_allocator_proc(
		nil,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
		location,
	)
	if error != nil {
		failed := cast(^bool)data
		failed^ = true
	}
	return bytes, error
}

// Static assets are already immutable embedded bytes.
// We borrow them directly instead of allocating and copying a huge image for every request.
bytes_begin :: proc(
	stream: ^Document_Stream,
	status: http.HTTP_Status,
	content_type: string,
	bytes: []u8,
) {
	stream^ = Document_Stream {
		bytes        = bytes,
		content_type = content_type,
		status       = status,
		initialized  = true,
	}
}

// document_send starts the HTTP response once, then copies as much of the
// rendered document as Tina can accept. A non-final flush returns control on
// Send_Ready so the handler can continue with the next bounded piece.
document_send :: proc(response: ^http.Response, stream: ^Document_Stream) -> http.Route_Step {
	if !stream.initialized do return http.close()
	if stream.render_failed {
		// No response headers have been sent yet; report a render failure
		// instead of quietly serving partial HTML with a 200 status.
		document_destroy(stream)
		return http.respond_text(
			response,
			http.HTTP_STATUS_INTERNAL_SERVER_ERROR,
			"page rendering failed\n",
		)
	}

	body := stream.bytes
	if stream.owns_body do body = transmute([]u8)strings.to_string(stream.body)
	if !stream.started {
		// The body is already rendered, so advertise the exact length. Tina
		// still sends it incrementally; HEAD can report the same length without
		// sending the document, and clients can detect an interrupted response.
		if result := http.begin_fixed_stream(
			response,
			stream.status,
			stream.content_type,
			u64(len(body)),
		); result != .Begun {
			document_destroy(stream)
			// begin_stream stages a bounded 500 response if its own header commit
			// fails, so let Tina send that response as the final flush.
			return http.flush(final = true)
		}
		stream.started = true
	}

	written := http.write_bytes(response, body[stream.offset:])
	stream.offset += int(written)
	if stream.offset < len(body) {
		return http.flush()
	}

	// write_bytes copies admitted bytes into Tina's egress buffer, so the
	// potentially large render buffer can be released before the final send.
	document_destroy(stream)
	return http.flush(final = true)
}

// document_destroy is shared by normal completion and interrupted requests.
// It is safe to call more than once, including when the stream never started.
document_destroy :: proc(stream: ^Document_Stream) {
	if !stream.initialized do return
	if stream.owns_body do strings.builder_destroy(&stream.body)
	stream^ = Document_Stream{}
}
