package main

import tina "../vendor/tina/src"
import http "../vendor/tina/src/extensions/http/server"
import datastar "../vendor/tina/src/extensions/http/datastar"
import httpx "httpx"
import views "views"
import "core:fmt"
import "core:strings"

PORT :: #config(WLLS_PORT, 8080)
// Tina reserves its own response headers in the 4 KiB egress buffer.
PAGE_BUFFER_SIZE :: #config(HTTP_EGRESS_BUFFER_SIZE, 4096) - 512
TEMPLATE_BUFFER_SIZE :: 16 * 1024

PREVIEW_ARTICLE :: views.Article {
	title = "Article template preview",
	description = "A sample article for the Odin rendering spike.",
	date = "2026-09-23",
	body = views.Trusted_HTML("<p>This sample contains <strong>trusted rendered Markdown</strong>.</p>"),
}

Preview_Application_Context :: struct {
	article: views.Article,
}

Preview_Stream_State :: struct {
	document: httpx.Document_Stream,
}

Preview_Event_State :: struct {
	waiting_for_send: bool,
}

index :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	buffer: [TEMPLATE_BUFFER_SIZE]u8
	b := strings.builder_from_bytes(buffer[:])
	views.home(&b)
	page := strings.to_string(b)
	if len(page) > PAGE_BUFFER_SIZE || !strings.has_suffix(page, "</html>") {
		return http.respond_text(response, http.HTTP_STATUS_INTERNAL_SERVER_ERROR, "page too large\n")
	}
	return http.respond_bytes(response, http.HTTP_STATUS_OK, "text/html; charset=utf-8", transmute([]u8)page)
}

preview_article :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	_ = request
	stream_state := cast(^Preview_Stream_State)state
	switch _ in event {
	case http.Request_Start:
		// Application data is installed once at startup and borrowed by each
		// route invocation; it remains alive for the server's entire lifetime.
		app_context := cast(^Preview_Application_Context)route_context.application_context
		if app_context == nil do return http.close()
		httpx.document_begin(&stream_state.document, http.HTTP_STATUS_OK, "text/html; charset=utf-8")
		views.article_page(&stream_state.document.body, app_context.article)
		return httpx.document_send(response, &stream_state.document)
	case http.Send_Ready:
		return httpx.document_send(response, &stream_state.document)
	case http.Peer_Closed, http.Server_Drain:
		httpx.document_destroy(&stream_state.document)
		return http.close()
	case http.Body_Chunk, http.Application_Reply, http.Application_Notification:
		return http.close()
	}
	return http.close()
}

preview_fragment :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	buffer: [TEMPLATE_BUFFER_SIZE]u8
	b := strings.builder_from_bytes(buffer[:])
	views.article_element(&b, PREVIEW_ARTICLE)
	fragment := strings.to_string(b)
	if len(fragment) > PAGE_BUFFER_SIZE || !strings.has_suffix(fragment, "</article>") {
		return http.respond_text(response, http.HTTP_STATUS_INTERNAL_SERVER_ERROR, "fragment too large\n")
	}
	_ = http.header_set(response, "Cache-Control", "no-store")
	return http.respond_bytes(response, http.HTTP_STATUS_OK, "text/html; charset=utf-8", transmute([]u8)fragment)
}

preview_events :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	_ = request
	_ = route_context
	stream_state := cast(^Preview_Event_State)state
	switch _ in event {
	case http.Request_Start:
		stream_state^ = Preview_Event_State{waiting_for_send = true}
		sse, error := datastar.start_sse(response)
		if error != .None do return http.close()
		if datastar.patch_elements(&sse, `<article id="article-preview"><p>Rendering article…</p></article>`) != .None {
			return http.close()
		}
		return http.flush()
	case http.Send_Ready:
		if !stream_state.waiting_for_send do return http.close()
		stream_state.waiting_for_send = false
		buffer: [TEMPLATE_BUFFER_SIZE]u8
		b := strings.builder_from_bytes(buffer[:])
		views.article_element(&b, PREVIEW_ARTICLE)
		fragment := strings.to_string(b)
		if len(fragment) > PAGE_BUFFER_SIZE || !strings.has_suffix(fragment, "</article>") {
			return http.close()
		}
		sse := datastar.resume(response)
		if datastar.patch_elements(&sse, fragment) != .None do return http.close()
		return http.flush(final = true)
	case http.Body_Chunk, http.Peer_Closed, http.Server_Drain,
	     http.Application_Reply, http.Application_Notification:
		return http.close()
	}
	return http.close()
}

health :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = http.header_set(response, "Cache-Control", "no-store")
	return http.respond_text(response, http.HTTP_STATUS_OK, "ok\n")
}

main :: proc() {
	// This context owns the data shared by handlers. Tina only stores the
	// pointer, so keep the value alive for the complete tina_start call.
	application_context := Preview_Application_Context{article = PREVIEW_ARTICLE}
	app := http.App {
		application_context = rawptr(&application_context),
		routes = []http.Route {
			http.get("/", index),
			http.get_event(
				"/template-preview",
				preview_article,
				state_size = u16(size_of(Preview_Stream_State)),
			),
			http.get("/template-preview/fragment", preview_fragment),
			http.get_event("/template-preview/events", preview_events, state_size = u16(size_of(Preview_Event_State))),
			http.get("/healthz", health),
			http.get("/readyz", health),
		},
	}
	server := http.Server {
		address = tina.ipv4(127, 0, 0, 1, PORT),
		app     = &app,
	}

	spec := http.install_development_defaults(&server)

	fmt.printfln("Wlls server — open http://127.0.0.1:%d", PORT)

	tina.tina_start(&spec)
}
