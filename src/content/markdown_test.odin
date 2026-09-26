package content

import "core:strings"
import "core:testing"

@(test)
test_markdown_renders_commonmark_and_gfm_without_raw_html :: proc(t: ^testing.T) {
	source :=
		"## Heading\n\nA **strong** word and ~~deleted~~ text.\n\n" +
		"| key | value |\n| --- | --- |\n| one | two |\n\n" +
		"<script>alert('raw')</script>\n"
	html, error := render_markdown(source)
	testing.expect_value(t, error, Markdown_Error.None)
	defer delete(string(html))
	rendered := string(html)
	testing.expect(t, strings.contains(rendered, "<h2"))
	testing.expect(t, strings.contains(rendered, "<strong>strong</strong>"))
	testing.expect(t, strings.contains(rendered, "<del>deleted</del>"))
	testing.expect(t, strings.contains(rendered, "<table>"))
	testing.expect(t, !strings.contains(rendered, "<script>"))
}

@(test)
test_markdown_renders_github_alerts_as_callouts :: proc(t: ^testing.T) {
	source :=
		"> [!NOTE]\n> **Aside title**\n>\n> Body text.\n\n" +
		"> [!WARNING]\n>\n> Standalone marker.\n\n" +
		"> Plain quote.\n>\n> > Nested quote.\n\n" +
		"> [!UNKNOWN]\n> Left alone.\n"
	html, error := render_markdown(source)
	testing.expect_value(t, error, Markdown_Error.None)
	defer delete(string(html))
	rendered := string(html)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<aside class="callout" data-kind="note"><p class="callout-label">Note</p>` +
			"\n<p><strong>Aside title</strong></p>",
		),
	)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<aside class="callout" data-kind="warning"><p class="callout-label">Warning</p>` +
			"\n<p>Standalone marker.</p>\n</aside>",
		),
	)
	testing.expect(t, !strings.contains(rendered, "[!NOTE]"))
	testing.expect(t, strings.contains(rendered, "[!UNKNOWN]"))
	testing.expect_value(t, strings.count(rendered, "<aside"), 2)
	testing.expect_value(t, strings.count(rendered, "</aside>"), 2)
	testing.expect_value(t, strings.count(rendered, "<blockquote>"), 3)
	testing.expect_value(t, strings.count(rendered, "</blockquote>"), 3)
}
