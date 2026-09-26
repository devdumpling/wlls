package views

// Metadata and Asset_URLs are the small shared contract between feature routes
// and the common document shell. URL fingerprints are built by src/assets.
Metadata :: struct {
	// page names the resource kind for the shell: it becomes <body data-page>
	// for stylesheet hooks and marks the current primary navigation link.
	page:        string,
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
	favicon:    string,
	feed:       string,
}
