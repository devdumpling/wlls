package views

import "core:strings"

// Metadata and Asset_URLs are the small shared contract between feature routes
// and the common document shell. URL fingerprints are built by src/assets.
Metadata :: struct {
	// page names the resource kind for the shell: it becomes <body data-page>
	// for stylesheet hooks and marks the current primary navigation link.
	page:        string,
	// path is the request path; the shell renders it as a breadcrumb.
	path:        string,
	title:       string,
	description: string,
	canonical:   string,
	open_graph:  string,
	noindex:     bool,
}

// stylesheet carries structure; garden carries the swappable theme (tokens,
// type, texture, ornaments) layered over it, CSS Zen Garden style.
Asset_URLs :: struct {
	stylesheet: string,
	garden:     string,
	datastar:   string,
	footnotes:  string,
	terminal:   string,
	favicon:    string,
	feed:       string,
}

Crumb :: struct {
	label: string,
	href:  string,
}

// breadcrumbs splits a request path into linked segments under the site
// root, so /blog/devex reads "wlls.dev / blog / devex". The slices borrow
// the path and live in the temp allocator for one render.
breadcrumbs :: proc(path: string) -> []Crumb {
	crumbs := make([dynamic]Crumb, 0, 4, context.temp_allocator)
	append(&crumbs, Crumb{label = "wlls.dev", href = "/"})
	rest := path
	for segment in strings.split_iterator(&rest, "/") {
		if segment == "" do continue
		// segment aliases path, so its end offset is the prefix to link.
		end := int(uintptr(raw_data(segment)) - uintptr(raw_data(path))) + len(segment)
		append(&crumbs, Crumb{label = segment, href = path[:end]})
	}
	return crumbs[:]
}

// import_map lets Rocket components `import { rocket } from "datastar"`
// against the fingerprinted bundle URL.
import_map :: proc(assets: Asset_URLs) -> string {
	return strings.concatenate(
		{`<script type="importmap">{"imports":{"datastar":"`, assets.datastar, `"}}</script>`},
		context.temp_allocator,
	)
}
