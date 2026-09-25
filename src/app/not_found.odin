package app

import views "../views"
import http "../../vendor/tina/src/extensions/http/server"
import "core:strings"

not_found :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_not_found)
}

// A missing blog slug renders the same document as a missing route.
@(private)
render_not_found :: proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	ctx: ^Application_Context,
) -> http.HTTP_Status {
	_ = request
	metadata := views.Metadata {
		title       = "Page not found | wlls.dev",
		description = "The requested page could not be found.",
		noindex     = true,
	}
	views.not_found_document(writer, metadata, ctx.view_assets)
	return http.HTTP_STATUS_NOT_FOUND
}
