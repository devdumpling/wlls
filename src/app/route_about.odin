package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import views "../views"
import "core:strings"

about_page :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_about)
}

@(private = "file")
render_about :: proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	ctx: ^Application_Context,
) -> http.HTTP_Status {
	_ = request
	page := content.about_page(&ctx.content)
	metadata := views.Metadata {
		title       = page.title,
		description = page.description,
		canonical   = page.canonical,
		open_graph  = "website",
	}
	views.about_page(writer, page^, metadata, ctx.view_assets)
	return http.HTTP_STATUS_OK
}
