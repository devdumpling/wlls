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
