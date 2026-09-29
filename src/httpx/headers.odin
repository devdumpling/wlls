package httpx

import http "../../vendor/tina/src/extensions/http/server"

// Every response the app sends goes through httpx, so security headers are
// defined here once and applied everywhere, with or without Caddy in front.
set_security_headers :: proc(response: ^http.Response) {
	_ = http.header_set(response, "Referrer-Policy", "strict-origin-when-cross-origin")
	_ = http.header_set(response, "X-Content-Type-Options", "nosniff")
	_ = http.header_set(response, "X-Frame-Options", "DENY")
}

// respond_text sends a small, complete plain-text response.
respond_text :: proc(
	response: ^http.Response,
	status: http.HTTP_Status,
	text: string,
) -> http.Route_Step {
	set_security_headers(response)
	return http.respond_text(response, status, text)
}

// not_modified answers a conditional GET whose ETag still matches.
not_modified :: proc(response: ^http.Response, content_type: string) -> http.Route_Step {
	set_security_headers(response)
	return http.respond_bytes(response, http.HTTP_STATUS_NOT_MODIFIED, content_type, {})
}
