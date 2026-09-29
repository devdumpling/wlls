package app

import content "../content"
import httpx "../httpx"
import "core:fmt"
import "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_startup_prerenders_every_page :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)

	ctx, error := load(virtual.arena_allocator(&arena))
	if !testing.expect(t, error == "", error) do return

	paths := [?]string{"/", "/blog", "/about", "/feed.xml", "/sitemap.xml", "/robots.txt"}
	for path in paths {
		page, found := find_page(&ctx.site, path)
		if !testing.expectf(t, found, "no page for %s", path) do continue
		testing.expect(t, len(page.bytes) > 0)
		testing.expect(t, strings.has_prefix(page.etag, `"`))
	}
	for post in content.published_posts(&ctx.content) {
		page, found := find_page(&ctx.site, post.url)
		if !testing.expectf(t, found, "no page for %s", post.url) do continue
		testing.expect(t, strings.has_suffix(string(page.bytes), "</html>"))
	}
}

// ls renders every post into one Datastar event, which must fit Tina's egress
// buffer in one piece. A hundred long slugs is well past today's archive.
@(test)
test_terminal_ls_fits_one_event :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	repository: content.Repository
	for index in 0 ..< 100 {
		slug := fmt.aprintf("a-reasonably-long-post-slug-%03d", index)
		append(&repository.posts, content.Post{slug = slug, url = fmt.aprintf("/blog/%s", slug)})
	}

	output := strings.builder_make()
	result := run_command(&output, "ls", &repository)
	rendered := strings.to_string(output)

	testing.expect(t, !result.clear && result.navigate == "")
	testing.expect_value(t, strings.count(rendered, "<li>"), 100)
	testing.expect(t, strings.has_suffix(rendered, "</ul>"))
	// Leave room for the SSE event's field lines and chunk framing.
	testing.expectf(
		t,
		len(rendered) + 256 <= httpx.EGRESS_BUFFER_SIZE,
		"ls output is %d bytes; the egress buffer is %d",
		len(rendered),
		httpx.EGRESS_BUFFER_SIZE,
	)
}

@(test)
test_terminal_commands :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	repository: content.Repository
	append(&repository.posts, content.Post{slug = "devex", url = "/blog/devex"})
	repository.by_slug["devex"] = 0

	output := strings.builder_make()
	result := run_command(&output, "cd devex", &repository)
	testing.expect_value(t, result.navigate, "/blog/devex")

	strings.builder_reset(&output)
	result = run_command(&output, "cd https://example.com", &repository)
	testing.expect_value(t, result.navigate, "")
	testing.expect(t, strings.contains(strings.to_string(output), "no such place"))

	strings.builder_reset(&output)
	result = run_command(&output, "clear", &repository)
	testing.expect(t, result.clear)
	testing.expect(t, strings.has_prefix(strings.to_string(output), `<div id="terminal-output"`))
}
