package app

import http "../../vendor/tina/src/extensions/http/server"
import assets "../assets"
import httpx "../httpx"
import "core:strings"

// static_asset implements both fingerprinted asset URLs and short-lived legacy
// paths used by existing Markdown posts and bookmarks.
static_asset :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	stream := cast(^httpx.Body_Stream)state
	if _, starting := event.(http.Request_Start); !starting {
		return httpx.drive(event, response, stream)
	}

	ctx := app_context(route_context)
	asset_path, immutable := resolve_asset_path(&ctx.assets, string(http.path(request)))
	asset, found := assets.find(&ctx.assets, asset_path)
	if !found {
		_ = http.header_set(response, "Cache-Control", "no-store")
		return httpx.respond_text(response, http.HTTP_STATUS_NOT_FOUND, "Not Found\n")
	}

	if immutable {
		_ = http.header_set(response, "Cache-Control", "public, max-age=31536000, immutable")
	} else {
		_ = http.header_set(response, "Cache-Control", "public, max-age=3600")
	}
	_ = http.header_set(response, "ETag", asset.etag)
	if string(http.header(request, "If-None-Match")) == asset.etag {
		return httpx.not_modified(response, asset.content_type)
	}
	httpx.begin_bytes(stream, http.HTTP_STATUS_OK, asset.content_type, asset.bytes)
	return httpx.send(response, stream)
}

@(private = "file")
resolve_asset_path :: proc(
	bundle: ^assets.Bundle,
	request_path: string,
) -> (
	asset_path: string,
	immutable: bool,
) {
	if strings.has_prefix(request_path, "/static/") {
		version_and_path := request_path[len("/static/"):]
		separator := strings.index(version_and_path, "/")
		if separator < 0 || version_and_path[:separator] != assets.version(bundle) {
			return "", true
		}
		return version_and_path[separator + 1:], true
	}
	if strings.has_prefix(request_path, "/images/") ||
	   strings.has_prefix(request_path, "/fonts/") {
		return request_path[1:], false
	}
	if request_path == "/favicon.svg" do return "favicon.svg", false
	return "", false
}
