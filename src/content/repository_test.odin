package content

import "core:strings"
import "core:testing"

@(test)
test_embedded_blog_content_loads_and_sorts_by_publication_date :: proc(t: ^testing.T) {
	repository, error := load()
	if error != "" {
		testing.expect(t, false, error)
		return
	}
	defer destroy(&repository)

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
