package content

import "core:crypto/sha2"
import "core:encoding/hex"
import "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_embedded_blog_content_loads_and_sorts_by_publication_date :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	repository, error := load("https://wlls.dev")
	if error != "" {
		testing.expect(t, false, error)
		return
	}

	testing.expect_value(t, len(repository.posts), 10)
	if len(repository.posts) > 0 {
		testing.expect_value(t, repository.posts[0].slug, "ai-reflections-fatigue")
		testing.expect_value(t, repository.posts[0].date, "2026-04-13")
	}

	devex, found := find_post(&repository, "devex")
	testing.expect(t, found)
	if found {
		testing.expect(t, strings.contains(string(devex.html), "<sup"))
	}
	tailwind, has_tailwind := find_post(&repository, "on-tailwind")
	testing.expect(t, has_tailwind)
	if has_tailwind do testing.expect(t, strings.contains(string(tailwind.html), "<pre"))
	_, found = find_post(&repository, "missing-post")
	testing.expect(t, !found)

	about := about_page(&repository)
	testing.expect_value(t, about.title, "Roots")
	testing.expect(t, strings.contains(string(about.html), "Blue Ridge Mountains"))

	resume := resume_page(&repository)
	testing.expect_value(t, resume.name, "Devon Wells")
	testing.expect_value(t, resume.sections[0].id, "experience")
	goodrx := resume.sections[0].entries[1]
	testing.expect_value(t, goodrx.id, "goodrx")
	testing.expect_value(t, goodrx.dates, "Jan 2022 – Feb 2025")
	testing.expect_value(t, len(goodrx.roles), 3)
	story := string(goodrx.roles[2].body)
	testing.expect(t, strings.contains(story, `<summary>The story</summary>`))
	testing.expect(t, !strings.contains(story, "blockquote"))
	testing.expect(t, strings.contains(resume.markdown, "](https://wlls.dev/blog/"))
}

// The PDF is printed from the page by `just resume-pdf`, which records the
// SHA-256 of the resume.md it printed. Editing the resume without printing
// it again fails here, before a stale PDF ships.
@(test)
test_resume_pdf_matches_its_source :: proc(t: ^testing.T) {
	digest: [sha2.DIGEST_SIZE_256]byte
	hash: sha2.Context_256
	sha2.init_256(&hash)
	sha2.update(&hash, EMBEDDED_RESUME)
	sha2.final(&hash, digest[:])
	printed_from := strings.trim_space(EMBEDDED_RESUME_PDF_SOURCE)
	current := string(hex.encode(digest[:], context.temp_allocator))
	testing.expectf(
		t,
		current == printed_from,
		"content/pages/resume.pdf was printed from an older resume.md: run just resume-pdf",
	)
	free_all(context.temp_allocator)
}

@(test)
test_invalid_authored_post_fails_before_serving :: proc(t: ^testing.T) {
	good := "---\ntitle: Example\ndescription: An example\ndate: 2025-01-02\n---\nBody"
	_, _, error := parse_post("Not-a-slug.md", good, "https://wlls.dev")
	testing.expect(t, strings.contains(error, "kebab-case"))

	bad_date := "---\ntitle: Example\ndescription: An example\ndate: 2025-02-30\n---\nBody"
	_, _, error = parse_post("example.md", bad_date, "https://wlls.dev")
	testing.expect(t, strings.contains(error, "invalid date"))

	_, _, error = parse_post("example.md", "No front matter", "https://wlls.dev")
	testing.expect(t, strings.contains(error, "opening"))
}
