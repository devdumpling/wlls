package content

import "core:strings"
import "core:testing"

@(test)
test_markdown_renders_commonmark_and_gfm_without_raw_html :: proc(t: ^testing.T) {
	source :=
		"## Heading\n\nA **strong** word and ~~deleted~~ text.\n\n" +
		"| key | value |\n| --- | --- |\n| one | two |\n\n" +
		"<script>alert('raw')</script>\n"
	html, error, _ := render_markdown(source)
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
	html, error, _ := render_markdown(source)
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

@(private = "file")
fake_image_size :: proc(data: rawptr, url: string) -> (width, height: int, found: bool) {
	if url == "/images/missing.webp" do return 0, 0, false
	return 1200, 800, true
}

@(test)
test_markdown_renders_image_paragraphs_as_plates :: proc(t: ^testing.T) {
	images := Image_Sizes {
		lookup = fake_image_size,
	}
	source :=
		"![A heron](/images/heron.webp \"Morning at the pond | wide pixel\")\n\n" +
		"![one](/images/a.webp)\n![two](/images/b.webp \"Second\")\n\n" +
		"Some ![inline](/images/c.webp) prose.\n\n" +
		"![remote](https://example.com/x.png)\n"
	html, error, _ := render_markdown(source, images)
	testing.expect_value(t, error, Markdown_Error.None)
	defer delete(string(html))
	rendered := string(html)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<figure class="plate" data-size="wide" data-pixel><img src="/images/heron.webp" alt="A heron" loading="lazy" decoding="async" width="1200" height="800" /><figcaption>Morning at the pond</figcaption></figure>`,
		),
	)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<div class="plates"><figure class="plate"><img src="/images/a.webp"`,
		),
	)
	testing.expect(
		t,
		strings.contains(rendered, "<figcaption>Second</figcaption></figure>\n</div>"),
	)
	testing.expect(
		t,
		strings.contains(rendered, `<p>Some <img src="/images/c.webp" alt="inline" /> prose.</p>`),
	)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<img src="https://example.com/x.png" alt="remote" loading="lazy" decoding="async" />`,
		),
	)
	testing.expect_value(t, strings.count(rendered, `<figure class="plate"`), 4)
}

@(test)
test_markdown_rejects_missing_images_and_unknown_options :: proc(t: ^testing.T) {
	images := Image_Sizes {
		lookup = fake_image_size,
	}
	_, error, detail := render_markdown("![gone](/images/missing.webp)\n", images)
	testing.expect_value(t, error, Markdown_Error.Missing_Image)
	testing.expect_value(t, detail, "/images/missing.webp")

	_, error, detail = render_markdown("![x](/images/x.webp \"Caption | huge\")\n", images)
	testing.expect_value(t, error, Markdown_Error.Invalid_Image_Option)
	testing.expect_value(t, detail, "huge")
}

@(test)
test_markdown_headings_get_unique_ids_and_permalinks :: proc(t: ^testing.T) {
	source := "## Hello, `World`!\n\n## Hello World\n\n### Q&A: 10x?\n\n# Title stays bare\n"
	html, error, _ := render_markdown(source)
	testing.expect_value(t, error, Markdown_Error.None)
	defer delete(string(html))
	rendered := string(html)
	testing.expect(
		t,
		strings.contains(
			rendered,
			`<h2 id="hello-world">Hello, <code>World</code>! <a class="heading-anchor" href="#hello-world" aria-label="Link to this section">#</a></h2>`,
		),
	)
	testing.expect(t, strings.contains(rendered, `<h2 id="hello-world-2">`))
	testing.expect(t, strings.contains(rendered, `<h3 id="q-a-10x">`))
	testing.expect(t, strings.contains(rendered, "<h1>Title stays bare</h1>"))
}
