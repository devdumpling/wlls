package views

import content "../content"
import "core:strings"
import "core:testing"

@(test)
test_post_document_escapes_metadata_and_inserts_rendered_markdown :: proc(t: ^testing.T) {
	post := content.Post{
		slug        = "sample-post",
		title       = `<script>alert("title")</script>`,
		description = `Quotes " & <angle>`,
		topic       = "Engineering",
		date        = "2026-01-02",
		html        = content.Markdown_HTML("<p><strong>Rendered Markdown</strong></p>"),
	}
	metadata := Metadata{
		title       = post.title,
		description = post.description,
		canonical   = "https://wlls.dev/blog/sample-post",
		open_graph  = "article",
	}
	assets := Asset_URLs{
		stylesheet = "/static/test/css/site.css",
		datastar   = "/static/test/js/datastar.js",
		favicon    = "/favicon.svg",
		feed       = "/feed.xml",
	}

	buffer: [4096]byte
	builder := strings.builder_from_bytes(buffer[:])
	post_page(&builder, post, metadata, assets)
	page := strings.to_string(builder)
	testing.expect(t, strings.contains(page, `&lt;script&gt;alert(&quot;title&quot;)&lt;/script&gt;`))
	testing.expect(t, strings.contains(page, `content="Quotes &quot; &amp; &lt;angle&gt;"`))
	testing.expect(t, strings.contains(page, `<strong>Rendered Markdown</strong>`))
	testing.expect(t, strings.has_suffix(page, "</html>"))
}
