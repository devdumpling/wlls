package app

import content "../content"
import views "../views"
import http "../../vendor/tina/src/extensions/http/server"
import "core:strings"

blog_index :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_blog_index)
}

@(private = "file")
render_blog_index :: proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	ctx: ^Application_Context,
) -> http.HTTP_Status {
	_ = request
	metadata := views.Metadata {
		title       = "Writing | wlls.dev",
		description = "Essays and notes on software, games, and making things.",
		canonical   = CANONICAL_BLOG,
		open_graph  = "website",
	}
	views.post_index(writer, content.published_posts(&ctx.content), metadata, ctx.view_assets)
	return http.HTTP_STATUS_OK
}

blog_post :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_blog_post)
}

@(private = "file")
render_blog_post :: proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	ctx: ^Application_Context,
) -> http.HTTP_Status {
	slug := transmute(string)http.param(request, "slug")
	post, found := content.find_post(&ctx.content, slug)
	if !found {
		render_not_found(writer, request, ctx)
		return http.HTTP_STATUS_NOT_FOUND
	}
	metadata := views.Metadata {
		title       = post.title,
		description = post.description,
		canonical   = post.canonical,
		open_graph  = "article",
	}
	views.post_page(writer, post^, metadata, ctx.view_assets)
	return http.HTTP_STATUS_OK
}
