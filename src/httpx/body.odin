package httpx

import http "../../vendor/tina/src/extensions/http/server"
import "core:strings"

// Tina never blocks and never buffers without bound: each connection owns a
// fixed egress buffer (HTTP_EGRESS_BUFFER_SIZE). A body larger than what fits
// is written in pieces: write what Tina accepts, return flush(), and continue
// on Send_Ready. Go hides the same loop behind a blocking Write; here, the
// place in the loop lives in route state, which is what Body_Stream is.
//
// The body is either borrowed immutable bytes (embedded assets, pages
// rendered at startup) or an owned Render_Buffer rendered for this request.
// BODY_STATE_SIZE is the per-request state a route needs for a Body_Stream.
BODY_STATE_SIZE :: u16(size_of(Body_Stream))

Body_Stream :: struct {
	render:       Render_Buffer,
	bytes:        []u8,
	offset:       int,
	content_type: string,
	status:       http.HTTP_Status,
	active:       bool,
	rendered:     bool,
	started:      bool,
}

// begin_bytes streams borrowed bytes; nothing is copied or freed.
begin_bytes :: proc(
	stream: ^Body_Stream,
	status: http.HTTP_Status,
	content_type: string,
	bytes: []u8,
) {
	stream^ = Body_Stream {
		bytes        = bytes,
		content_type = content_type,
		status       = status,
		active       = true,
	}
}

// begin_render returns a builder to render the body into. Rendering finishes
// before send, so the exact Content-Length is known up front.
begin_render :: proc(
	stream: ^Body_Stream,
	status: http.HTTP_Status,
	content_type: string,
) -> ^strings.Builder {
	stream^ = Body_Stream {
		content_type = content_type,
		status       = status,
		active       = true,
		rendered     = true,
	}
	return render_buffer_init(&stream.render)
}

// send starts the response once, then copies as much of the body as Tina's
// egress buffer accepts. It returns flush() until the whole body is admitted.
send :: proc(response: ^http.Response, stream: ^Body_Stream) -> http.Route_Step {
	if !stream.active do return http.close()
	if stream.rendered && render_buffer_failed(&stream.render) {
		// No headers have gone out yet, so report the failure honestly
		// instead of serving partial HTML with a 200.
		destroy(stream)
		return respond_text(response, http.HTTP_STATUS_INTERNAL_SERVER_ERROR, "rendering failed\n")
	}

	body := stream.rendered ? render_buffer_bytes(&stream.render) : stream.bytes
	if !stream.started {
		set_security_headers(response)
		// The body is complete, so advertise its exact length: HEAD reports the
		// same length without a body, and clients can detect a cut-off response.
		if http.begin_fixed_stream(response, stream.status, stream.content_type, u64(len(body))) !=
		   .Begun {
			destroy(stream)
			// begin_fixed_stream stages a bounded 500 when it cannot commit
			// headers; let Tina send it as the final flush.
			return http.flush(final = true)
		}
		stream.started = true
	}

	stream.offset += int(http.write_bytes(response, body[stream.offset:]))
	if stream.offset < len(body) do return http.flush()

	// Every byte is now in Tina's egress buffer, so the render can be released
	// before the final send completes.
	destroy(stream)
	return http.flush(final = true)
}

// drive handles every event after Request_Start for a Body_Stream route:
// continue on Send_Ready, and release the body if the request ends early.
drive :: proc(
	event: http.Route_Event,
	response: ^http.Response,
	stream: ^Body_Stream,
) -> http.Route_Step {
	#partial switch _ in event {
	case http.Send_Ready:
		return send(response, stream)
	}
	destroy(stream)
	return http.close()
}

// destroy is shared by completion and interrupted requests; safe to repeat.
destroy :: proc(stream: ^Body_Stream) {
	if !stream.active do return
	if stream.rendered do render_buffer_destroy(&stream.render)
	stream^ = {}
}
