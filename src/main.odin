package main

import tina "../vendor/tina/src"
import http "../vendor/tina/src/extensions/http/server"
import datastar "../vendor/tina/src/extensions/http/datastar"
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

Preview_Stream_State :: struct {
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

preview_article :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	buffer: [TEMPLATE_BUFFER_SIZE]u8
	b := strings.builder_from_bytes(buffer[:])
	views.article_page(&b, PREVIEW_ARTICLE)
	page := strings.to_string(b)
	if len(page) > PAGE_BUFFER_SIZE || !strings.has_suffix(page, "</html>") {
		return http.respond_text(response, http.HTTP_STATUS_INTERNAL_SERVER_ERROR, "page too large\n")
	}
	return http.respond_bytes(
		response,
		http.HTTP_STATUS_OK,
		"text/html; charset=utf-8",
		transmute([]u8)page,
	)
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
	stream_state := cast(^Preview_Stream_State)state
	switch _ in event {
	case http.Request_Start:
		stream_state^ = Preview_Stream_State{waiting_for_send = true}
		// This Tina revision closes Connection: close streams after the first
		// flush. Send one complete event for those clients instead.
		if strings.equal_fold(string(http.header(request, "Connection")), "close") {
			buffer: [TEMPLATE_BUFFER_SIZE]u8
			b := strings.builder_from_bytes(buffer[:])
			views.article_element(&b, PREVIEW_ARTICLE)
			fragment := strings.to_string(b)
			if len(fragment) > PAGE_BUFFER_SIZE || !strings.has_suffix(fragment, "</article>") {
				return http.respond_text(response, http.HTTP_STATUS_INTERNAL_SERVER_ERROR, "fragment too large\n")
			}
			sse, error := datastar.start_sse(response)
			if error != .None do return http.close()
			if datastar.patch_elements(&sse, fragment) != .None do return http.close()
			return http.flush(final = true)
		}
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
	app := http.App {
		routes = []http.Route {
			http.get("/", index),
			http.get("/template-preview", preview_article),
			http.get("/template-preview/fragment", preview_fragment),
			http.get_event("/template-preview/events", preview_events, state_size = u16(size_of(Preview_Stream_State))),
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
