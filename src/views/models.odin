package views

import "core:strings"

// Metadata and Asset_URLs are the small shared contract between feature routes
// and the common document shell. URL fingerprints are built by src/assets.
Metadata :: struct {
	// page names the resource kind for the shell: it becomes <body data-page>
	// for stylesheet hooks and marks the current primary navigation link.
	page:        Page_Kind,
	// path is the request path; the shell renders it as a breadcrumb.
	path:        string,
	title:       string,
	description: string,
	canonical:   string,
	open_graph:  string,
	noindex:     bool,
}

Page_Kind :: enum {
	Home,
	Blog,
	Post,
	About,
	Not_Found,
}

// page_name is the data-page value stylesheets select on.
page_name :: proc(kind: Page_Kind) -> string {
	switch kind {
	case .Home:
		return "home"
	case .Blog:
		return "blog"
	case .Post:
		return "post"
	case .About:
		return "about"
	case .Not_Found:
		return "not-found"
	}
	return ""
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

// navigate_expression is the Datastar expression that loads path. Callers pass
// site paths only, never request input.
navigate_expression :: proc(path: string) -> string {
	return strings.concatenate({"window.location.assign('", path, "')"}, context.temp_allocator)
}
