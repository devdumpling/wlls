package app

import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"
import views "../views"
import "core:encoding/json"
import "core:fmt"
import "core:mem/virtual"
import "core:strings"
import "core:time"

// Name and note, percent-encoded: 280 characters of UTF-8 can triple in size.
GUESTBOOK_BODY_MAX :: 4096
// One stroke batch as JSON: a colour and up to 60 cell indices.
DOODLE_BODY_MAX :: 1024

// serve_guestbook renders the page per request around the current Guestbook
// frame, so it is complete without JavaScript and never a version behind.
// The postcard comes signed with your name here (your nick, or the handle the
// visitor cookie gives you), as `sign` in the terminal would use, so the page
// is private to you.
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

	scratch: virtual.Arena
	context.temp_allocator = httpx.scratch_allocator(&scratch)
	defer virtual.arena_destroy(&scratch)

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
	doodle := string(frame_bytes(&ctx.live.frames[.Doodle]))
	from := ""
	if visitor, known := visitor_from_request(request); known {
		name := display_name(&ctx.live.nicks, visitor)
		from = strings.clone(name_string(&name), context.temp_allocator)
	}
	views.guestbook_page(writer, entries, doodle, from, metadata, ctx.view_assets)
	_ = http.header_set(response, "Cache-Control", "private, no-cache")
	set_speculation_rules(response)
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

	scratch: virtual.Arena
	context.temp_allocator = httpx.scratch_allocator(&scratch)
	defer virtual.arena_destroy(&scratch)

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
		year, month, day := time.date(time.now())
		views.guestbook_thanks(writer, fmt.tprintf("%04d-%02d-%02d", year, int(month), day))
	} else {
		views.guestbook_status(writer, sign_reply(result))
	}
	httpx.queue_elements(stream)
	return httpx.send_patches(response, stream)
}

// Paint is one batch of a stroke, as <sb-pixel-board>'s sb-paint event
// sends it: a colour and the cells it touched.
@(private = "file")
Paint :: struct {
	color: int,
	cells: []int,
}

// paint_doodle applies a stroke batch to the shared board. Whatever happens,
// it answers with the board as it now stands, so the painter's pending cells
// settle at once (or fall back, when they were going too fast); everyone
// else gets the board from their live stream.
paint_doodle :: proc(
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

	scratch: virtual.Arena
	context.temp_allocator = httpx.scratch_allocator(&scratch)
	defer virtual.arena_destroy(&scratch)

	ctx := app_context(route_context)
	caller := caller_of(request)
	paint: Paint
	parse_error := json.unmarshal(
		http.body_buffered(request),
		&paint,
		allocator = http.request_arena(request),
	)
	if parse_error != nil || !valid_paint(paint) {
		return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid paint\n")
	}
	// Painting needs the visitor cookie the page's live stream sets, so the
	// rate limit has someone to hold to.
	if caller.visitor == 0 {
		return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "not connected\n")
	}

	guestbook, frame := &ctx.guestbook, &ctx.live.frames[.Doodle]
	painted := doodle_paint(guestbook, caller.visitor, paint.color, paint.cells, caller.now)
	if painted == .Painted && doodle_render(guestbook, frame) do publish(ctx.live, .Doodle)

	writer := httpx.begin_patches(stream)
	strings.write_bytes(writer, frame_bytes(frame))
	httpx.queue_elements(stream)
	return httpx.send_patches(response, stream)
}

@(private = "file")
valid_paint :: proc(paint: Paint) -> bool {
	if paint.color < 0 || paint.color > 1 do return false
	if len(paint.cells) == 0 || len(paint.cells) > DOODLE_BATCH_MAX do return false
	for index in paint.cells {
		if index < 0 || index >= DOODLE_CELLS do return false
	}
	return true
}
