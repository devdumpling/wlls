package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import views "../views"
import "core:strings"

home_page :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_home)
}

@(private = "file")
render_home :: proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	ctx: ^Application_Context,
) -> http.HTTP_Status {
	posts := content.published_posts(&ctx.content)
	metadata := views.Metadata {
		page        = "home",
		path        = transmute(string)http.path(request),
		title       = "Home | wlls.dev",
		description = "Just my corner of the internet. Feel free to stay a while.",
		canonical   = BASE_URL + "/",
		open_graph  = "website",
	}
	views.home(writer, posts[0], metadata, ctx.view_assets)
	return http.HTTP_STATUS_OK
}
