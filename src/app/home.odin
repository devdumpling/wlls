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
	_ = request
	posts := content.published_posts(&ctx.content)
	posts = posts[:min(len(posts), 5)]
	metadata := views.Metadata {
		title       = "Devon Wells | wlls.dev",
		description = "Writing about software, games, craft, and the odd paths between them.",
		canonical   = BASE_URL + "/",
		open_graph  = "website",
	}
	views.home(writer, posts, metadata, ctx.view_assets)
	return http.HTTP_STATUS_OK
}
