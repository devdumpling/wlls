package app

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"
import views "../views"

// Name and note, percent-encoded: 280 characters of UTF-8 can triple in size.
GUESTBOOK_BODY_MAX :: 4096

// serve_guestbook renders the page per request around the current Guestbook
// frame, so it is complete without JavaScript and never a version behind.
serve_guestbook :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	stream := cast(^httpx.Body_Stream)state
	if _, starting := event.(http.Request_Start); !starting {
		return httpx.drive(event, response, stream)
	}

	ctx := app_context(route_context)
	writer := httpx.begin_render(stream, http.HTTP_STATUS_OK, "text/html; charset=utf-8")
	metadata := views.Metadata {
		page        = .Guestbook,
		path        = "/guestbook",
		title       = "Guestbook | wlls.dev",
		description = "Leave a note.",
		canonical   = BASE_URL + "/guestbook",
		open_graph  = "website",
	}
	entries := string(frame_bytes(&ctx.live.frames[.Guestbook]))
	views.guestbook_page(writer, entries, metadata, ctx.view_assets)
	_ = http.header_set(response, "Cache-Control", "no-cache")
	return httpx.send(response, stream)
}

// sign_guestbook is the command side: it records a pending entry and answers
// with a patch, thanks in place of the form or a reason it didn't take.
sign_guestbook :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	stream := cast(^httpx.Patch_Stream)state
	if _, starting := event.(http.Request_Start); !starting {
		return httpx.drive_patches(event, response, stream)
	}

	ctx := app_context(route_context)
	body, arena := http.body_buffered(request), http.request_arena(request)
	name, name_ok := form_value(body, "name", arena)
	message, message_ok := form_value(body, "message", arena)
	if !name_ok || !message_ok {
		return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid form\n")
	}

	caller := caller_of(request)
	result := guestbook_sign(
		&ctx.guestbook,
		name,
		message,
		caller.visitor,
		caller.client,
		caller.now,
	)
	writer := httpx.begin_patches(stream)
	if result == .Signed {
		views.guestbook_thanks(writer)
	} else {
		views.guestbook_status(writer, sign_reply(result))
	}
	httpx.queue_elements(stream)
	return httpx.send_patches(response, stream)
}

// Caller is who sent a command: their visitor id, their network address as
// Caddy reports it (empty without Caddy, as in development), and when.
Caller :: struct {
	visitor: Visitor,
	client:  string,
	now:     u64, // monotonic ns
	admin:   bool, // signed in with sudo (the terminal checks)
	session: int, // the sudo session, when admin
}

caller_of :: proc(request: ^http.Request) -> Caller {
	visitor, _ := visitor_from_request(request)
	return Caller {
		visitor = visitor,
		client = string(http.header(request, "X-Client-IP")),
		now = u64(tina.ctx_monotonic_time_ns()),
	}
}
