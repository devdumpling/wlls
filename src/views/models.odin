package views

// Metadata and Asset_URLs are the small shared contract between feature routes
// and the common document shell. URL fingerprints are built by src/assets.
Metadata :: struct {
	title:       string,
	description: string,
	canonical:   string,
	open_graph:  string,
	noindex:     bool,
}

Asset_URLs :: struct {
	stylesheet: string,
	datastar:   string,
	favicon:    string,
	feed:       string,
}
