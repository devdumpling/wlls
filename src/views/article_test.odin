package views

import "core:strings"
import "core:testing"

@(test)
test_article_component_and_document :: proc(t: ^testing.T) {
	article := Article {
		title = `<img src=x onerror="alert(1)">&`,
		description = `Quotes " and ' & <script>`,
		date = "2026-09-23",
		body = Trusted_HTML("<p><strong>Rendered Markdown</strong></p>"),
	}
	buffer: [4096]u8
	b := strings.builder_from_bytes(buffer[:])
	article_page(&b, article)
	page := strings.to_string(b)
	testing.expect(t, strings.contains(page, `&lt;img src=x onerror=&quot;alert(1)&quot;&gt;&amp;`))
	testing.expect(t, strings.contains(page, `Quotes &quot; and &#39; &amp; &lt;script&gt;`))
	testing.expect(t, strings.contains(page, `<strong>Rendered Markdown</strong>`))
	testing.expect(t, strings.contains(page, `content="noindex"`))
	testing.expect(t, strings.has_suffix(page, "</html>"))

	strings.builder_reset(&b)
	article_element(&b, article)
	fragment := strings.to_string(b)
	testing.expect(t, strings.has_prefix(fragment, `<article id="article-preview">`))
	testing.expect(t, strings.contains(page, fragment))
	testing.expect(t, !strings.contains(fragment, "<html"))
}
