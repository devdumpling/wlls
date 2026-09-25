package app

import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"

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

@(private)
set_security_headers :: proc(response: ^http.Response) {
	_ = http.header_set(response, "Referrer-Policy", "strict-origin-when-cross-origin")
	_ = http.header_set(response, "X-Content-Type-Options", "nosniff")
	_ = http.header_set(response, "X-Frame-Options", "DENY")
}
