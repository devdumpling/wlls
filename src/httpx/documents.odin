package httpx

import http "../../vendor/tina/src/extensions/http/server"
import "base:runtime"
import "core:strings"

// Document_Stream owns a rendered page until Tina has copied every byte into
// its connection buffer. The body can therefore be much larger than that
// buffer, while each individual write remains bounded by Tina's egress size.
Document_Stream :: struct {
	body:         strings.Builder,
	offset:       int,
	content_type: string,
	status:       http.HTTP_Status,
	initialized:  bool,
	started:      bool,
}

// document_begin prepares an owned, growable render buffer before a view is
// rendered. Tempo components write into this builder just as they do into a
// fixed one, but long posts no longer get silently truncated at a capacity.
document_begin :: proc(
	stream: ^Document_Stream,
	status: http.HTTP_Status,
	content_type: string,
) {
	stream^ = Document_Stream{
		content_type = content_type,
		status       = status,
		initialized  = true,
	}
	// Tina's request allocator is deliberately small and request-scoped. A page
	// can outlive several Send_Ready callbacks and exceed that budget, so this
	// response-owned buffer uses the general heap and is freed after copying.
	strings.builder_init(&stream.body, runtime.heap_allocator())
}

// document_send starts the HTTP response once, then copies as much of the
// rendered document as Tina can accept. A non-final flush returns control on
// Send_Ready so the handler can continue with the next bounded piece.
document_send :: proc(response: ^http.Response, stream: ^Document_Stream) -> http.Route_Step {
	if !stream.initialized do return http.close()

	if !stream.started {
		if result := http.begin_stream(response, stream.status, stream.content_type); result != .Begun {
			document_destroy(stream)
			// begin_stream stages a bounded 500 response if its own header commit
			// fails, so let Tina send that response as the final flush.
			return http.flush(final = true)
		}
		stream.started = true
	}

	body := transmute([]u8)strings.to_string(stream.body)
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
	strings.builder_destroy(&stream.body)
	stream^ = Document_Stream{}
}
