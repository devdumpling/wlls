package views

import content "../content"
import "core:strings"
import "core:testing"

@(test)
test_post_document_escapes_metadata_and_inserts_rendered_markdown :: proc(t: ^testing.T) {
	post := content.Post {
		slug        = "sample-post",
		title       = `<script>alert("title")</script>`,
		description = `Quotes " & <angle>`,
		topic       = "Engineering",
		date        = "2026-01-02",
		html        = content.Markdown_HTML("<p><strong>Rendered Markdown</strong></p>"),
	}
	metadata := Metadata {
		page        = .Post,
		path        = "/blog/sample-post",
		title       = post.title,
		description = post.description,
		canonical   = "https://wlls.dev/blog/sample-post",
		open_graph  = "article",
	}
	assets := Asset_URLs {
		stylesheet = "/static/test/css/site.css",
		garden     = "/static/test/css/garden.css",
		datastar   = "/static/test/js/datastar-rocket.js",
		footnotes  = "/static/test/js/footnotes.js",
		terminal   = "/static/test/js/terminal.js",
		favicon    = "/favicon.svg",
		feed       = "/feed.xml",
	}

	buffer: [8192]byte
	builder := strings.builder_from_bytes(buffer[:])
	post_page(&builder, post, metadata, assets)
	page := strings.to_string(builder)
	testing.expect(
		t,
		strings.contains(page, `&lt;script&gt;alert(&quot;title&quot;)&lt;/script&gt;`),
	)
	testing.expect(t, strings.contains(page, `content="Quotes &quot; &amp; &lt;angle&gt;"`))
	testing.expect(t, strings.contains(page, `<strong>Rendered Markdown</strong>`))
	testing.expect(t, strings.contains(page, `<body data-page="post">`))
	testing.expect(t, strings.contains(page, `<a href="/blog" aria-current="page">`))
	testing.expect(
		t,
		strings.contains(
			page,
			`<li><a href="/">wlls.dev</a></li><li><a href="/blog">blog</a></li><li><a href="/blog/sample-post" aria-current="page">sample-post</a></li>`,
		),
	)
	testing.expect(
		t,
		strings.contains(page, `<script type="module" src="/static/test/js/datastar-rocket.js">`),
	)
	// The CSP allows no inline scripts.
	testing.expect(
		t,
		!strings.contains(page, "<script>") && !strings.contains(page, `type="importmap"`),
	)
	testing.expect(t, strings.contains(page, `href="/static/test/css/garden.css"`))
	testing.expect(t, strings.contains(page, `src="/static/test/js/footnotes.js"`))
	testing.expect(t, strings.has_suffix(page, "</html>"))
}

@(test)
test_breadcrumbs_link_each_path_prefix :: proc(t: ^testing.T) {
	crumbs := breadcrumbs("/blog/devex")
	testing.expect_value(t, len(crumbs), 3)
	if len(crumbs) == 3 {
		testing.expect_value(t, crumbs[0], Crumb{label = "wlls.dev", href = "/"})
		testing.expect_value(t, crumbs[1], Crumb{label = "blog", href = "/blog"})
		testing.expect_value(t, crumbs[2], Crumb{label = "devex", href = "/blog/devex"})
	}
	testing.expect_value(t, len(breadcrumbs("/")), 1)
	testing.expect_value(t, len(breadcrumbs("//blog//")), 2)
}
