package app

import assets "../assets"
import content "../content"
import views "../views"

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"

import "base:runtime"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:strings"

// Application_Context is the read-only view that Tina's route callbacks borrow.
// run owns the underlying startup-loaded content and assets until shutdown.
Application_Context :: struct {
	content:     content.Repository,
	assets:      assets.Bundle,
	view_assets: views.Asset_URLs,
	site:        Site,
}

// Load and validate content before accepting requests. tina_start blocks until
// shutdown, so the application context remains valid for every route callback.
run :: proc() {
	// Everything loaded at startup lives until shutdown, so one arena owns it
	// and releases it in a single call instead of per-field destroy procs.
	startup: virtual.Arena
	if error := virtual.arena_init_growing(&startup); error != nil {
		fmt.eprintln("wlls: startup arena failed:", error)
		os.exit(1)
	}
	defer virtual.arena_destroy(&startup)

	application_context, load_error := load(virtual.arena_allocator(&startup))
	if load_error != "" {
		fmt.eprintln("wlls: startup failed:", load_error)
		os.exit(1)
	}

	// Route registration: every path the site answers, in one place.
	app := http.App {
		application_context = rawptr(&application_context),
		routes              = []http.Route {
			stream_get("/", serve_page),
			stream_get("/blog", serve_page),
			stream_get("/blog/:slug", serve_page),
			stream_get("/about", serve_page),
			stream_get("/feed.xml", serve_page),
			stream_get("/sitemap.xml", serve_page),
			stream_get("/robots.txt", serve_page),
			http.post_event(
				"/terminal",
				terminal_command,
				body_size_max = TERMINAL_BODY_MAX,
				body_mode = .Buffered,
			),
			http.get("/rss.xml", rss_compatibility),
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

// load builds the immutable application context: assets first (content
// rendering sizes and validates images from them), then content, then every
// page rendered from both.
@(private = "file")
load :: proc(allocator: runtime.Allocator) -> (ctx: Application_Context, error: string) {
	context.allocator = allocator

	ctx.assets, error = assets.load()
	if error != "" do return

	images := content.Image_Sizes {
		data   = &ctx.assets,
		lookup = embedded_image_size,
	}
	ctx.content, error = content.load(BASE_URL, images)
	if error != "" do return

	ctx.view_assets = views.Asset_URLs {
		stylesheet = assets.url(&ctx.assets, "css/site.css"),
		garden     = assets.url(&ctx.assets, "css/garden.css"),
		datastar   = assets.url(&ctx.assets, "js/datastar-rocket.js"),
		footnotes  = assets.url(&ctx.assets, "js/footnotes.js"),
		terminal   = assets.url(&ctx.assets, "js/terminal.js"),
		favicon    = "/favicon.svg",
		feed       = "/feed.xml",
	}

	ctx.site, error = prerender(&ctx)
	return
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
