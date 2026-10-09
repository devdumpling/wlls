package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import httpx "../httpx"
import views "../views"
import "core:crypto/sha2"
import "core:encoding/hex"
import "core:encoding/json"
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

@(private)
HTML :: "text/html; charset=utf-8"
@(private = "file")
HTML_CACHE :: "public, max-age=0, must-revalidate"
@(private = "file")
DISCOVERY_CACHE :: "public, max-age=3600"

// Every page prefetches a same-site link's HTML once the pointer rests on it
// (or it is pressed), so the click finds the response already downloaded. The
// rules arrive by header, not an inline <script>, so the CSP stays static.
// Files, feeds, and the resume's PDF and Markdown are left out: only pages
// are worth fetching early.
@(private = "file")
SPECULATION_RULES_PATH :: "/speculation-rules.json"
@(private = "file")
SPECULATION_RULES ::
	`{"prefetch":[{"where":{"and":[` +
	`{"href_matches":"/*"},` +
	`{"not":{"href_matches":["/static/*","/images/*","/fonts/*","/*.xml","/*.txt","/*.pdf","/*.md"]}}` +
	`]},"eagerness":"moderate"}]}`

// set_speculation_rules points an HTML response at the site's prefetch rules.
set_speculation_rules :: proc(response: ^http.Response) {
	_ = http.header_set(response, "Speculation-Rules", `"` + SPECULATION_RULES_PATH + `"`)
}

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
			title = "Blog | wlls.dev",
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
				embeds = post.embeds,
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

	resume := content.resume_page(&ctx.content)
	views.resume_page(
		begin(&renderer),
		resume^,
		views.Metadata {
			page = .Resume,
			path = "/resume",
			title = resume.title,
			description = resume.description,
			canonical = resume.canonical,
			open_graph = "profile",
			structured_data = resume_structured_data(resume),
		},
		ctx.view_assets,
	)
	finish(&renderer, &site, "/resume", HTML, HTML_CACHE)

	// The resume also comes as the Markdown it is written in, and as a PDF
	// printed from the page above (`just resume-pdf`). Until that recipe has
	// run once, the PDF is empty and isn't served.
	strings.write_string(begin(&renderer), resume.markdown)
	finish(&renderer, &site, "/resume.md", "text/markdown; charset=utf-8", DISCOVERY_CACHE)
	if len(content.EMBEDDED_RESUME_PDF) > 0 {
		strings.write_bytes(begin(&renderer), content.EMBEDDED_RESUME_PDF)
		finish(&renderer, &site, "/resume.pdf", "application/pdf", DISCOVERY_CACHE)
	}

	write_feed(begin(&renderer), posts)
	finish(&renderer, &site, "/feed.xml", "application/rss+xml; charset=utf-8", DISCOVERY_CACHE)

	write_sitemap(begin(&renderer), posts)
	finish(&renderer, &site, "/sitemap.xml", "application/xml; charset=utf-8", DISCOVERY_CACHE)

	write_robots(begin(&renderer))
	finish(&renderer, &site, "/robots.txt", "text/plain; charset=utf-8", DISCOVERY_CACHE)

	strings.write_string(begin(&renderer), SPECULATION_RULES)
	finish(
		&renderer,
		&site,
		SPECULATION_RULES_PATH,
		"application/speculationrules+json",
		DISCOVERY_CACHE,
	)

	if renderer.failed_path != "" {
		return site, fmt.tprintf("rendering %s failed", renderer.failed_path)
	}
	return site, ""
}

// resume_structured_data describes /resume to search engines as JSON-LD: a
// profile page about a person, with their profiles elsewhere.
@(private = "file")
resume_structured_data :: proc(resume: ^content.Resume) -> string {
	Person :: struct {
		type:      string `json:"@type"`,
		name:      string `json:"name"`,
		job_title: string `json:"jobTitle"`,
		url:       string `json:"url"`,
		same_as:   []string `json:"sameAs"`,
	}
	Profile_Page :: struct {
		schema:        string `json:"@context"`,
		type:          string `json:"@type"`,
		url:           string `json:"url"`,
		date_modified: string `json:"dateModified"`,
		main_entity:   Person `json:"mainEntity"`,
	}
	page := Profile_Page {
		schema = "https://schema.org",
		type = "ProfilePage",
		url = resume.canonical,
		date_modified = resume.updated,
		main_entity = {
			type = "Person",
			name = resume.name,
			job_title = resume.headline,
			url = BASE_URL,
			same_as = resume.links[:],
		},
	}
	data, error := json.marshal(page, allocator = context.temp_allocator)
	if error != nil do return ""
	// Inside <script>, only "</" could end the element early.
	escaped, _ := strings.replace_all(string(data), "</", `<\/`, context.temp_allocator)
	return escaped
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
