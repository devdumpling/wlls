package httpx

import http "../../vendor/tina/src/extensions/http/server"
import "core:strings"

// CONTENT_SECURITY_POLICY allows only same-origin resources and no inline
// script or style, so it is static and pages can still be rendered once and
// cached. What the site needs, and why:
//
//   - script-src 'unsafe-eval': Datastar compiles data-* expressions with
//     Function(). Its nonce mode avoids this, but a nonce must be fresh per
//     response, which pages rendered at startup and cached at the edge cannot
//     have. Inline scripts stay blocked: no import map (modules import each
//     other relatively) and no execute-script events (see patches.odin).
//   - img-src data: the theme's paper texture is an inline SVG in garden.css.
//   - style-src 'self': a Rocket component with its own `css` injects a
//     <style>; that would need a hash here.
//
// frame-ancestors repeats X-Frame-Options for browsers that honor only one.
CONTENT_SECURITY_POLICY ::
	"default-src 'self'; " +
	"script-src 'self' 'unsafe-eval'; " +
	"style-src 'self'; " +
	"img-src 'self' data:; " +
	"font-src 'self'; " +
	"connect-src 'self'; " +
	"object-src 'none'; " +
	"base-uri 'none'; " +
	"form-action 'self'; " +
	"frame-ancestors 'none'"

// Every response the app sends goes through httpx, so security headers are
// defined here once and applied everywhere, with or without Caddy in front.
set_security_headers :: proc(response: ^http.Response) {
	_ = http.header_set(response, "Content-Security-Policy", CONTENT_SECURITY_POLICY)
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

// etag_matches reports whether a request's If-None-Match covers etag. The
// header may list several tags or be "*", and it uses weak comparison: a proxy
// that re-compresses a response (Cloudflare does) hands clients W/"tag", and
// that still identifies the same content.
etag_matches :: proc(request: ^http.Request, etag: string) -> bool {
	return if_none_match_covers(string(http.header(request, "If-None-Match")), etag)
}

@(private)
if_none_match_covers :: proc(header, etag: string) -> bool {
	rest := header
	for candidate in strings.split_iterator(&rest, ",") {
		tag := strings.trim_space(candidate)
		if tag == "*" do return true
		if strings.trim_prefix(tag, "W/") == strings.trim_prefix(etag, "W/") do return true
	}
	return false
}
