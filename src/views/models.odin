package views

import "core:strings"

import content "../content"

// Metadata and Asset_URLs are the small shared contract between feature routes
// and the common document shell. URL fingerprints are built by src/assets.
Metadata :: struct {
	// page names the resource kind for the shell: it becomes <body data-page>
	// for stylesheet hooks and marks the current primary navigation link.
	page:            Page_Kind,
	// path is the request path; the shell renders it as a breadcrumb.
	path:            string,
	title:           string,
	description:     string,
	canonical:       string,
	open_graph:      string,
	noindex:         bool,
	// structured_data is a JSON-LD document for the <head>, already escaped
	// for a <script> element. It is data, never run, so the CSP allows it.
	structured_data: string,
	// embeds are a post's interactive components: the shell loads their
	// stylesheet and scripts on that page alone.
	embeds:          content.Embeds,
}

Page_Kind :: enum {
	Home,
	Blog,
	Post,
	About,
	Resume,
	Guestbook,
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
	case .Resume:
		return "resume"
	case .Guestbook:
		return "guestbook"
	case .Not_Found:
		return "not-found"
	}
	return ""
}

// stylesheet carries structure; garden carries the swappable theme (tokens,
// type, texture, ornaments) layered over it, CSS Zen Garden style.
Asset_URLs :: struct {
	stylesheet:    string,
	garden:        string,
	datastar:      string,
	footnotes:     string,
	terminal:      string,
	// Guestbook only: Starbase components (vendored).
	relative_time: string,
	pixel_board:   string,
	// Posts with embeds only: one stylesheet, and a script per component.
	embeds:        string,
	embed_scripts: [content.Embed]string,
	favicon:       string,
	feed:          string,
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

// TERMINAL_POST sends a terminal prompt's form. Network failures aren't
// retried: a command may have run before the connection dropped.
TERMINAL_POST :: "@post('/terminal', {contentType: 'form', retryMaxCount: 0})"

// json_ld_script wraps a JSON-LD document in its <script> element. Tempo
// writes a <script>'s contents literally, so the element is built here.
json_ld_script :: proc(data: string) -> string {
	return strings.concatenate(
		{`<script type="application/ld+json">`, data, "</script>"},
		context.temp_allocator,
	)
}

// fragment is a same-page link to an element id: "#goodrx".
fragment :: proc(id: string) -> string {
	return strings.concatenate({"#", id}, context.temp_allocator)
}

// navigate_expression is the Datastar expression that loads path. Callers pass
// site paths only, never request input.
navigate_expression :: proc(path: string) -> string {
	return strings.concatenate({"window.location.assign('", path, "')"}, context.temp_allocator)
}

// Who_Row is one visitor in the `who` list: their name and the page they have
// open. The hub renders the list from fixed buffers, without allocating.
Who_Row :: struct {
	name, place: string,
}

// Chat_Row is one line of #lobby: a message (name and text) or an event
// such as "quiet-heron joined". root marks dev's own lines.
Chat_Row :: struct {
	name, text, event: string,
	root:              bool,
}

// NOT_FOUND_PLACE is where `who` shows a visitor on a 404: every missing
// path is one place, so request paths never become places.
NOT_FOUND_PLACE :: "/404"

// live_place is the place a page's live stream reports.
live_place :: proc(metadata: Metadata) -> string {
	return NOT_FOUND_PLACE if metadata.page == .Not_Found else metadata.path
}

// live_expression is the Datastar expression that opens a page's live stream.
// Callers pass site paths only, never request input.
live_expression :: proc(path: string) -> string {
	return strings.concatenate({"@get('/live?path=", path, "')"}, context.temp_allocator)
}

// Guestbook_Entry is one approved entry, as the guestbook frame shows it.
// date is when it was signed, as the page shows it without script (YYYY-MM-DD);
// iso is the same moment for <sb-relative-time> ("3 days ago").
Guestbook_Entry :: struct {
	name, message, date, iso: string,
}

// DOODLE_PALETTE is the shared board's two colours, blank and ink, as
// <sb-pixel-board> takes them. They're for light paper; garden.css flips the
// canvas in the dark.
DOODLE_PALETTE :: `["#fbf9f5","#3d3832"]`

// Pending_Entry is an unread entry, as `pending` lists it for moderation:
// its label is "#id name".
Pending_Entry :: struct {
	label, message: string,
}
