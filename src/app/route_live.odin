package app

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"

// GET /live?path=<page> is the read side of everything live: one long-lived
// SSE stream per visible page. It sends the page's live frames when it opens,
// subscribes to the hub, then parks until the hub says a frame changed (or a
// heartbeat is due). Writes go through ordinary short POSTs elsewhere.

// Cloudflare closes an SSE connection after about 100 s without bytes.
@(private = "file")
LIVE_HEARTBEAT_NS :: 25 * 1_000_000_000

@(private)
Live_Stream :: struct {
	visitor: Visitor,
	place:   u16,
	topics:  Topics,
	sent:    [Topic]u64, // frame version last sent, per topic
}

@(private)
LIVE_STATE_SIZE :: u16(size_of(Live_Stream))

live_stream :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	stream := cast(^Live_Stream)state
	live := app_context(route_context).live

	switch notice in event {
	case http.Request_Start:
		path, decoded := http.query_value_decoded(request, "path")
		place, known := live.places.by_path[string(path)]
		if decoded != .Found || !known {
			return httpx.respond_text(response, http.HTTP_STATUS_NOT_FOUND, "unknown place\n")
		}
		visitor, returning := visitor_from_request(request)
		if !returning {
			visitor = visitor_new()
			cookie: [128]u8
			_ = http.header_add(response, "Set-Cookie", visitor_cookie(visitor, cookie[:]))
		}
		stream^ = {
			visitor = visitor,
			place   = place,
			topics  = place_topics(string(path)),
		}
		if !httpx.start_stream(response) do return http.close()
		subscribe(route_context, live, stream)
		return send_news(response, live, stream)

	case http.Send_Ready:
		if has_news(live, stream) do return send_news(response, live, stream)
		return http.expect_notification(
			route_context,
			LIVE_HEARTBEAT_NS,
			message_tag = TAG_LIVE_NOTIFY,
		)

	case http.Application_Notification:
		notify := tina.payload_as(Live_Notify, notice.payload_bytes)
		// The connection may have served other requests since it subscribed.
		if notify.token != http.route_request_token(route_context) {
			return http.expect_notification(
				route_context,
				LIVE_HEARTBEAT_NS,
				message_tag = TAG_LIVE_NOTIFY,
			)
		}
		if notify.refused do return http.flush(final = true)
		return send_news(response, live, stream)

	case http.Application_Reply:
		// The park timed out: keep the proxies' idle timers at bay, and remind
		// the hub we are here in case it restarted.
		subscribe(route_context, live, stream)
		if httpx.send_heartbeat(response) == .Failed do return close_live(route_context, live)
		return http.flush()

	case http.Peer_Closed, http.Server_Drain, http.Body_Chunk:
	}
	return close_live(route_context, live)
}

// send_news writes every frame newer than the one this stream last sent.
// When the egress buffer is full, it flushes and finishes on Send_Ready; by
// then a frame may have changed again, and only its latest version goes out.
@(private = "file")
send_news :: proc(response: ^http.Response, live: ^Live, stream: ^Live_Stream) -> http.Route_Step {
	for topic in stream.topics {
		frame := &live.frames[topic]
		if frame.version <= stream.sent[topic] do continue
		switch httpx.send_elements(response, string(frame_bytes(frame))) {
		case .Sent:
			stream.sent[topic] = frame.version
		case .Backpressured:
			return http.flush()
		case .Failed:
			return http.close()
		}
	}
	return http.flush()
}

@(private = "file")
has_news :: proc(live: ^Live, stream: ^Live_Stream) -> bool {
	for topic in stream.topics {
		if live.frames[topic].version > stream.sent[topic] do return true
	}
	return false
}

@(private = "file")
subscribe :: proc(route_context: http.Route_Context, live: ^Live, stream: ^Live_Stream) {
	message := Hub_Subscribe {
		token   = http.route_request_token(route_context),
		place   = stream.place,
		topics  = stream.topics,
		visitor = stream.visitor,
	}
	// A full mailbox or a restarting hub is retried on the next heartbeat.
	_ = http.route_send(route_context, live.hub, TAG_HUB_SUBSCRIBE, tina.bytes_of(&message))
}

@(private = "file")
close_live :: proc(route_context: http.Route_Context, live: ^Live) -> http.Route_Step {
	_ = http.route_send(route_context, live.hub, TAG_HUB_UNSUBSCRIBE, nil)
	return http.close()
}
