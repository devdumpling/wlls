package content

import "embed"

// Files contains all authored Markdown content.
//
//go:embed posts/*.md pages/*.md
var Files embed.FS
