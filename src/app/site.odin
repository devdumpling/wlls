package app

import content "../content"
import httpx "../httpx"
import views "../views"
import "core:crypto/sha2"
import "core:encoding/hex"
import "core:fmt"
import "core:strings"

// Every page depends only on startup data, so each is rendered once, before
// the server accepts requests, into immutable bytes served like an embedded
// asset. Requests never allocate for pages, and a page that fails to render
// is a startup error that blocks the deploy rather than a 500 in production.
Page :: struct {
	path:          string,
	bytes:         []u8,
	content_type:  string,
	cache_control: string,
	etag:          string,
}

Site :: struct {
	pages:   [dynamic]Page,
	by_path: map[string]int,
}

find_page :: proc(site: ^Site, path: string) -> (^Page, bool) {
	index, found := site.by_path[path]
	if !found do return nil, false
	return &site.pages[index], true
}

@(private = "file")
HTML :: "text/html; charset=utf-8"
@(private = "file")
HTML_CACHE :: "public, max-age=0, must-revalidate"
@(private = "file")
DISCOVERY_CACHE :: "public, max-age=3600"

// prerender renders every page with context.allocator, which the caller points
// at the startup arena.
@(require_results)
prerender :: proc(ctx: ^Application_Context) -> (site: Site, error: string) {
	renderer: Renderer
	posts := content.published_posts(&ctx.content)

	views.home(
		begin(&renderer),
		posts[0],
		views.Metadata {
			page = .Home,
			path = "/",
			title = "Home | wlls.dev",
			description = "Just my corner of the internet. Feel free to stay a while.",
			canonical = BASE_URL + "/",
			open_graph = "website",
		},
		ctx.view_assets,
	)
	finish(&renderer, &site, "/", HTML, HTML_CACHE)

	views.post_index(
		begin(&renderer),
		posts,
		views.Metadata {
			page = .Blog,
			path = "/blog",
			title = "Posts | wlls.dev",
			description = "You can read it if you want.",
			canonical = CANONICAL_BLOG,
			open_graph = "website",
		},
		ctx.view_assets,
	)
	finish(&renderer, &site, "/blog", HTML, HTML_CACHE)

	for post in posts {
		views.post_page(
			begin(&renderer),
			post,
			views.Metadata {
				page = .Post,
				path = post.url,
				title = post.title,
				description = post.description,
				canonical = post.canonical,
				open_graph = "article",
			},
			ctx.view_assets,
		)
		finish(&renderer, &site, post.url, HTML, HTML_CACHE)
	}

	about := content.about_page(&ctx.content)
	views.about_page(
		begin(&renderer),
		about^,
		views.Metadata {
			page = .About,
			path = "/about",
			title = about.title,
			description = about.description,
			canonical = about.canonical,
			open_graph = "website",
		},
		ctx.view_assets,
	)
	finish(&renderer, &site, "/about", HTML, HTML_CACHE)

	write_feed(begin(&renderer), posts)
	finish(&renderer, &site, "/feed.xml", "application/rss+xml; charset=utf-8", DISCOVERY_CACHE)

	write_sitemap(begin(&renderer), posts)
	finish(&renderer, &site, "/sitemap.xml", "application/xml; charset=utf-8", DISCOVERY_CACHE)

	write_robots(begin(&renderer))
	finish(&renderer, &site, "/robots.txt", "text/plain; charset=utf-8", DISCOVERY_CACHE)

	if renderer.failed_path != "" {
		return site, fmt.tprintf("rendering %s failed", renderer.failed_path)
	}
	return site, ""
}

// Renderer lets prerender read as a flat list of pages: begin hands out a
// fresh builder, finish records the page, and the first failure is reported
// once at the end.
@(private = "file")
Renderer :: struct {
	tracker:     httpx.Allocation_Tracker,
	builder:     strings.Builder,
	failed_path: string,
}

@(private = "file")
begin :: proc(renderer: ^Renderer) -> ^strings.Builder {
	renderer.tracker = {
		backing = context.allocator,
	}
	renderer.builder = strings.builder_make(httpx.tracking_allocator(&renderer.tracker))
	return &renderer.builder
}

@(private = "file")
finish :: proc(renderer: ^Renderer, site: ^Site, path, content_type, cache_control: string) {
	bytes := renderer.builder.buf[:]
	if renderer.tracker.failed || len(bytes) == 0 {
		if renderer.failed_path == "" do renderer.failed_path = path
		return
	}
	site.by_path[path] = len(site.pages)
	append(
		&site.pages,
		Page {
			path = path,
			bytes = bytes,
			content_type = content_type,
			cache_control = cache_control,
			etag = etag(bytes),
		},
	)
}

// etag is a short content hash, so it changes exactly when the page does.
@(private = "file")
etag :: proc(bytes: []u8) -> string {
	digest: [sha2.DIGEST_SIZE_256]byte
	hash: sha2.Context_256
	sha2.init_256(&hash)
	sha2.update(&hash, bytes)
	sha2.final(&hash, digest[:])
	return fmt.aprintf(`"%s"`, string(hex.encode(digest[:8], context.temp_allocator)))
}
