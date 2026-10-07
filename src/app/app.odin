package app

import assets "../assets"
import content "../content"
import httpx "../httpx"
import views "../views"

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"

import "base:runtime"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:strings"

// Application_Context is what Tina's route callbacks borrow. run owns it, and
// the startup-loaded content and assets in it, until shutdown. Everything is
// read-only except live (the frames live features share) and guestbook, which
// every connection uses; both rely on running one shard (live.odin).
Application_Context :: struct {
	content:     content.Repository,
	assets:      assets.Bundle,
	view_assets: views.Asset_URLs,
	site:        Site,
	live:        ^Live,
	guestbook:   Guestbook,
	admin:       Admin,
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
	guestbook := &application_context.guestbook
	if error := guestbook_open(guestbook, DATABASE_PATH); error != "" {
		fmt.eprintln("wlls: startup failed:", error)
		os.exit(1)
	}
	defer guestbook_close(guestbook)
	if warning := admin_load(&application_context.admin); warning != "" {
		fmt.eprintln("wlls:", warning)
	}
	if !guestbook_render(guestbook, &application_context.live.frames[.Guestbook]) {
		fmt.eprintln("wlls: startup failed: rendering the guestbook")
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
			stream_get("/resume", serve_page),
			stream_get("/resume.md", serve_page),
			stream_get("/resume.pdf", serve_page),
			stream_get("/feed.xml", serve_page),
			stream_get("/sitemap.xml", serve_page),
			stream_get("/robots.txt", serve_page),
			stream_get("/speculation-rules.json", serve_page),
			http.get_event("/live", live_stream, state_size = LIVE_STATE_SIZE),
			stream_get("/guestbook", serve_guestbook),
			http.post_event(
				"/guestbook",
				sign_guestbook,
				body_size_max = GUESTBOOK_BODY_MAX,
				body_mode = .Buffered,
				state_size = httpx.PATCH_STATE_SIZE,
			),
			http.post_event(
				"/terminal",
				terminal_command,
				body_size_max = TERMINAL_BODY_MAX,
				body_mode = .Buffered,
				state_size = httpx.PATCH_STATE_SIZE,
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
	when WLLS_DEV {
		spec := http.install_development(&server, CONNECTION_SLOTS)
	} else {
		spec := http.install(
			&server,
			shard_count = SHARD_COUNT,
			connection_slot_count = CONNECTION_SLOTS,
		)
	}
	install_hub(&spec, application_context.live)
	tina.tina_start(&spec)
}

// load builds the immutable application context: assets first (content
// rendering sizes and validates images from them), then content, then every
// page rendered from both.
@(private)
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
	if error != "" do return

	// Every HTML page is a place a live stream may report.
	ctx.live = new(Live)
	for page in ctx.site.pages {
		if strings.has_prefix(page.content_type, "text/html") do place_add(&ctx.live.places, page.path)
	}
	place_add(&ctx.live.places, "/guestbook")
	place_add(&ctx.live.places, views.NOT_FOUND_PLACE)

	// #lobby starts empty, but its frame and prompt are sent as soon as
	// someone joins, so render both now.
	if !chat_render(ctx.live) do return ctx, "rendering #lobby failed"
	buffer: httpx.Render_Buffer
	views.terminal_chat_prompt(httpx.render_buffer_init(&buffer), "")
	stored := frame_store(&ctx.live.chat_prompt, &buffer)
	httpx.render_buffer_destroy(&buffer)
	if !stored do return ctx, "rendering the #lobby prompt failed"
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
