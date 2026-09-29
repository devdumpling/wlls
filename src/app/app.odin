package app

import assets "../assets"
import content "../content"
import httpx "../httpx"
import views "../views"

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"

import "core:fmt"
import "core:os"
import "core:strings"

// Application_Context is the read-only view that Tina's route callbacks borrow.
// run owns the underlying startup-loaded content and assets until shutdown.
Application_Context :: struct {
	content:     content.Repository,
	assets:      assets.Bundle,
	view_assets: views.Asset_URLs,
}

Stream_State :: struct {
	document: httpx.Document_Stream,
}

// Load and validate content before accepting requests. tina_start blocks until
// shutdown, so the application context remains valid for every route callback.
run :: proc() {
	// Load assets first: content rendering sizes and validates images from them.
	asset_bundle, asset_error := assets.load()
	if asset_error != "" {
		fmt.eprintln("wlls: asset startup failed:", asset_error)
		os.exit(1)
	}
	defer assets.destroy(&asset_bundle)

	// Load static content into memory
	images := content.Image_Sizes {
		data   = &asset_bundle,
		lookup = embedded_image_size,
	}
	content_repository, content_error := content.load(BASE_URL, images)
	if content_error != "" {
		fmt.eprintln("wlls: content startup failed:", content_error)
		os.exit(1)
	}
	defer content.destroy(&content_repository)

	// Aggregate into Application_Context
	application_context := Application_Context {
		content = content_repository,
		assets = asset_bundle,
		view_assets = views.Asset_URLs {
			stylesheet = asset_url(&asset_bundle, "css/site.css"),
			garden = asset_url(&asset_bundle, "css/garden.css"),
			datastar = asset_url(&asset_bundle, "js/datastar-rocket.js"),
			footnotes = asset_url(&asset_bundle, "js/footnotes.js"),
			terminal = asset_url(&asset_bundle, "js/terminal.js"),
			favicon = "/favicon.svg",
			feed = "/feed.xml",
		},
	}
	defer {
		delete(application_context.view_assets.stylesheet)
		delete(application_context.view_assets.garden)
		delete(application_context.view_assets.datastar)
		delete(application_context.view_assets.footnotes)
		delete(application_context.view_assets.terminal)
	}

	// Init Tina app with our context and routes
	// Note this is effectively route registration
	// Edit this routes array to register new routes.
	app := http.App {
		application_context = rawptr(&application_context),
		routes              = []http.Route {
			stream_get("/", home_page),
			stream_get("/blog", blog_index),
			stream_get("/blog/:slug", blog_post),
			stream_get("/about", about_page),
			http.post_event(
				"/terminal",
				terminal_command,
				body_size_max = TERMINAL_BODY_MAX,
				body_mode = .Buffered,
			),
			stream_get("/feed.xml", feed),
			http.get("/rss.xml", rss_compatibility),
			stream_get("/sitemap.xml", sitemap),
			stream_get("/robots.txt", robots),
			stream_get("/static/*", static_asset),
			stream_get("/images/*", static_asset),
			stream_get("/fonts/*", static_asset),
			stream_get("/favicon.svg", static_asset),
			stream_get("/*", not_found),
			http.get("/healthz", health),
			http.get("/readyz", health),
		},
	}

	// Init Tina server
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

// Tina routes HEAD to the GET handler when no explicit HEAD route exists.
// Event handlers also need state across flushes; allocate it for every route.
@(private = "file")
stream_get :: proc(path: string, handler: http.Route_Event_Handler) -> http.Route {
	return http.get_event(path, handler, state_size = u16(size_of(Stream_State)))
}

// embedded_image_size resolves a content image URL (for example
// /images/posts/x.webp) against the embedded asset bundle.
@(private = "file")
embedded_image_size :: proc(data: rawptr, url: string) -> (width, height: int, found: bool) {
	bundle := cast(^assets.Bundle)data
	asset := assets.find(bundle, strings.trim_prefix(url, "/")) or_return
	width, height, _ = assets.image_size(asset.bytes)
	return width, height, true
}
