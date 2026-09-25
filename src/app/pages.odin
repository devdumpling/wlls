package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import httpx "../httpx"
import views "../views"

import "core:strings"

Page_Renderer :: #type proc(
	writer: ^strings.Builder,
	request: ^http.Request,
	application_context: ^Application_Context,
) -> http.HTTP_Status

// document_event handles the shared HTTP lifecycle for complete server-rendered pages.
// feature renderers only choose data, metadata, and their Tempo view.
// this adapter handles chunking, headers, backpressure, and disconnect cleanup.
document_event :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
	render: Page_Renderer,
) -> http.Route_Step {
	page_state := cast(^Stream_State)state
	switch _ in event {
	case http.Request_Start:
		application_context := cast(^Application_Context)route_context.application_context
		if application_context == nil do return http.close()

		httpx.document_begin(&page_state.document, http.HTTP_STATUS_OK, "text/html; charset=utf-8")
		status := render(&page_state.document.body, request, application_context)
		page_state.document.status = status
		set_security_headers(response)
		_ = http.header_set(response, "Cache-Control", "public, max-age=0, must-revalidate")
		return httpx.document_send(response, &page_state.document)
	case http.Send_Ready:
		return httpx.document_send(response, &page_state.document)
	case http.Peer_Closed, http.Server_Drain:
		httpx.document_destroy(&page_state.document)
		return http.close()
	case http.Body_Chunk, http.Application_Reply, http.Application_Notification:
		return http.close()
	}
	return http.close()
}

home_page :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_home)
}

blog_index :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_blog_index)
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

about_page :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_about)
}

not_found :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	return document_event(event, request, response, route_context, state, render_not_found)
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

@(private = "file")
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

@(private)
set_security_headers :: proc(response: ^http.Response) {
	_ = http.header_set(response, "Referrer-Policy", "strict-origin-when-cross-origin")
	_ = http.header_set(response, "X-Content-Type-Options", "nosniff")
	_ = http.header_set(response, "X-Frame-Options", "DENY")
}
