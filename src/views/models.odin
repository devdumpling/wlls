package views

// The Markdown content pipeline may construct Trusted_HTML only after rendering
// authored Markdown with raw HTML disabled. Template expressions escape by default.
Trusted_HTML :: distinct string

Article :: struct {
	title:       string,
	description: string,
	date:        string,
	body:        Trusted_HTML,
}
