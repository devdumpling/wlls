package app

import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"
import views "../views"
import "core:mem/virtual"

// Tina calls an event route once per event of a request (Request_Start, then
// Send_Ready after each flush, or Peer_Closed). Every handler below follows
// the same shape: on Request_Start, choose a response and begin streaming it;
// on any later event, let httpx.drive continue or clean up.

// serve_page answers every page rendered at startup, looked up by path.
serve_page :: proc(
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
	page, found := find_page(&ctx.site, string(http.path(request)))
	if !found do return render_not_found(request, response, ctx, stream)

	_ = http.header_set(response, "Cache-Control", page.cache_control)
	_ = http.header_set(response, "ETag", page.etag)
	if page.content_type == HTML do set_speculation_rules(response)
	if httpx.etag_matches(request, page.etag) {
		return httpx.not_modified(response, page.content_type)
	}
	httpx.begin_bytes(stream, http.HTTP_STATUS_OK, page.content_type, page.bytes)
	return httpx.send(response, stream)
}

// not_found is the one page rendered per request, because its breadcrumb
// echoes the requested path. It is the model for future request-dependent
// pages: render into httpx.begin_render, then send.
not_found :: proc(
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
	return render_not_found(request, response, app_context(route_context), stream)
}

@(private = "file")
render_not_found :: proc(
	request: ^http.Request,
	response: ^http.Response,
	ctx: ^Application_Context,
	stream: ^httpx.Body_Stream,
) -> http.Route_Step {
	scratch: virtual.Arena
	context.temp_allocator = httpx.scratch_allocator(&scratch)
	defer virtual.arena_destroy(&scratch)

	writer := httpx.begin_render(stream, http.HTTP_STATUS_NOT_FOUND, "text/html; charset=utf-8")
	metadata := views.Metadata {
		page        = .Not_Found,
		path        = string(http.path(request)),
		title       = "404 | wlls.dev",
		description = "Sorry fam it's not here idk what to tell you.",
		noindex     = true,
	}
	views.not_found_document(writer, metadata, ctx.view_assets)
	_ = http.header_set(response, "Cache-Control", "public, max-age=0, must-revalidate")
	set_speculation_rules(response)
	return httpx.send(response, stream)
}

rss_compatibility :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = http.header_set(response, "Cache-Control", "public, max-age=3600")
	_ = http.header_set(response, "Location", "/feed.xml")
	return httpx.respond_text(response, http.HTTP_STATUS_MOVED_PERMANENTLY, "")
}

health :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = http.header_set(response, "Cache-Control", "no-store")
	return httpx.respond_text(response, http.HTTP_STATUS_OK, "ok\n")
}

// app_context recovers the immutable startup data every route borrows.
@(private)
app_context :: proc(route_context: http.Route_Context) -> ^Application_Context {
	ctx := cast(^Application_Context)route_context.application_context
	assert(ctx != nil, "route registered without the application context")
	return ctx
}

// stream_get registers a GET route whose per-request state is a Body_Stream.
// Tina routes HEAD to the GET handler when no explicit HEAD route exists.
@(private)
stream_get :: proc(path: string, handler: http.Route_Event_Handler) -> http.Route {
	return http.get_event(path, handler, state_size = httpx.BODY_STATE_SIZE)
}
