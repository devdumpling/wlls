package site

import "net/url"

type Metadata struct {
	Title       string
	Description string
	Canonical   string
	Type        string
	NoIndex     bool
}

type Assets struct {
	Stylesheet string
	Datastar   string
	Favicon    string
}

func Canonical(base *url.URL, path string) string {
	return base.ResolveReference(&url.URL{Path: path}).String()
}
