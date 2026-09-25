package app

import assets "../assets"
import content "../content"
import httpx "../httpx"
import views "../views"

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"

import "core:fmt"
import "core:os"

// Application_Context is the read-only view that Tina's route callbacks borrow.
// run owns the underlying startup-loaded content and assets until shutdown.
Application_Context :: struct {
	content:     content.Repository,
	assets:      assets.Bundle,
	view_assets: views.Asset_URLs,
}

Page_Stream_State :: struct {
	document: httpx.Document_Stream,
}

Static_Stream_State :: struct {
	document: httpx.Document_Stream,
}

// run validates all authored data before opening the listener. The values stay
// live on this stack frame while tina_start services requests.
run :: proc() {
	content_repository, content_error := content.load(BASE_URL)
	if content_error != "" {
		fmt.eprintln("wlls: content startup failed:", content_error)
		os.exit(1)
	}
	defer content.destroy(&content_repository)

	asset_bundle, asset_error := assets.load()
	if asset_error != "" {
		fmt.eprintln("wlls: asset startup failed:", asset_error)
		os.exit(1)
	}
	defer assets.destroy(&asset_bundle)

	application_context := Application_Context {
		content = content_repository,
		assets = asset_bundle,
		view_assets = views.Asset_URLs {
			stylesheet = asset_url(&asset_bundle, "css/site.css"),
			datastar = asset_url(&asset_bundle, "js/datastar.js"),
			favicon = "/favicon.svg",
			feed = "/feed.xml",
		},
	}
	defer {
		delete(application_context.view_assets.stylesheet)
		delete(application_context.view_assets.datastar)
	}
	app := http.App {
		application_context = rawptr(&application_context),
		routes              = []http.Route {
			page_get("/", home_page),
			page_head("/", home_page),
			page_get("/blog", blog_index),
			page_head("/blog", blog_index),
			page_get("/blog/:slug", blog_post),
			page_head("/blog/:slug", blog_post),
			page_get("/about", about_page),
			page_head("/about", about_page),
			page_get("/feed.xml", feed),
			page_head("/feed.xml", feed),
			http.get("/rss.xml", rss_compatibility),
			http.head("/rss.xml", rss_compatibility),
			page_get("/sitemap.xml", sitemap),
			page_head("/sitemap.xml", sitemap),
			page_get("/robots.txt", robots),
			page_head("/robots.txt", robots),
			asset_get("/static/*"),
			asset_head("/static/*"),
			asset_get("/images/*"),
			asset_head("/images/*"),
			asset_get("/fonts/*"),
			asset_head("/fonts/*"),
			asset_get("/favicon.svg"),
			asset_head("/favicon.svg"),
			page_get("/*", not_found),
			page_head("/*", not_found),
			http.get("/healthz", health),
			http.head("/healthz", health),
			http.get("/readyz", health),
			http.head("/readyz", health),
		},
	}
	server := http.Server {
		address = tina.ipv4(127, 0, 0, 1, PORT),
		app     = &app,
	}

	fmt.printfln("wlls.dev — listening on http://127.0.0.1:%d", PORT)
	spec := http.install_development_defaults(&server)
	tina.tina_start(&spec)
}

@(private = "file")
asset_url :: proc(bundle: ^assets.Bundle, path: string) -> string {
	return fmt.aprintf("/static/%s/%s", assets.version(bundle), path)
}

// Event handlers need per-connection state across flushes. Keep its exact
// size beside route registration so no handler can accidentally get nil state.
@(private = "file")
page_get :: proc(path: string, handler: http.Route_Event_Handler) -> http.Route {
	return http.get_event(path, handler, state_size = u16(size_of(Page_Stream_State)))
}

@(private = "file")
page_head :: proc(path: string, handler: http.Route_Event_Handler) -> http.Route {
	return http.head_event(path, handler, state_size = u16(size_of(Page_Stream_State)))
}

@(private = "file")
asset_get :: proc(path: string) -> http.Route {
	return http.get_event(path, static_asset, state_size = u16(size_of(Static_Stream_State)))
}

@(private = "file")
asset_head :: proc(path: string) -> http.Route {
	return http.head_event(path, static_asset, state_size = u16(size_of(Static_Stream_State)))
}
