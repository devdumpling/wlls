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

	paths := [?]string {
		"/",
		"/blog",
		"/about",
		"/resume",
		"/resume.md",
		"/resume.pdf",
		"/feed.xml",
		"/sitemap.xml",
		"/robots.txt",
		"/speculation-rules.json",
	}
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

	ctx := Application_Context {
		live = new(Live),
	}
	for index in 0 ..< 100 {
		slug := fmt.aprintf("a-reasonably-long-post-slug-%03d", index)
		append(&ctx.content.posts, content.Post{slug = slug, url = fmt.aprintf("/blog/%s", slug)})
	}

	output := strings.builder_make()
	result := run_command(&output, "ls", &ctx, {})
	rendered := strings.to_string(output)

	testing.expect_value(t, result, Command_Result.Append)
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

	ctx := Application_Context {
		live = new(Live),
	}
	append(&ctx.content.posts, content.Post{slug = "devex", url = "/blog/devex"})
	ctx.content.by_slug["devex"] = 0

	output := strings.builder_make()
	navigated := run_command(&output, "cd devex", &ctx, {})
	testing.expect_value(t, navigated, Command_Result.Navigate)
	testing.expect(
		t,
		strings.contains(
			strings.to_string(output),
			`data-init="window.location.assign(&#39;/blog/devex&#39;)"`,
		),
	)

	strings.builder_reset(&output)
	run_command(&output, "cd https://example.com", &ctx, {})
	testing.expect(t, strings.contains(strings.to_string(output), "no such place"))
	testing.expect(t, !strings.contains(strings.to_string(output), "data-init"))

	strings.builder_reset(&output)
	result := run_command(&output, "clear", &ctx, {})
	testing.expect_value(t, result, Command_Result.Clear)
	testing.expect(t, strings.has_prefix(strings.to_string(output), `<div id="terminal-output"`))
}

// The guestbook's whole life against an in-memory database: signing (and its
// guards), the moderation queue, and an approval reaching the frame.
@(test)
test_guestbook_sign_and_moderate :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	guestbook: Guestbook
	if error := guestbook_open(&guestbook, ":memory:"); !testing.expect(t, error == "", error) do return
	defer guestbook_close(&guestbook)
	frame := new(Frame)

	minute :: u64(60 * 1_000_000_000)
	testing.expect_value(
		t,
		guestbook_sign(&guestbook, "Jo", "hi <there>\r\nfriend", 7, "", 0),
		Sign_Result.Signed,
	)
	testing.expect_value(
		t,
		guestbook_sign(&guestbook, "Jo", "again", 7, "", minute),
		Sign_Result.Too_Soon,
	)
	testing.expect_value(
		t,
		guestbook_sign(&guestbook, "Al", "same network", 8, "10.0.0.1", minute),
		Sign_Result.Signed,
	)
	testing.expect_value(
		t,
		guestbook_sign(&guestbook, "Bo", "", 9, "", minute),
		Sign_Result.Invalid,
	)
	testing.expect_value(
		t,
		guestbook_sign(&guestbook, "Cy", "\x07", 9, "", minute),
		Sign_Result.Invalid,
	)

	pending, total, ok := guestbook_pending(&guestbook)
	testing.expect(t, ok)
	testing.expect_value(t, total, 2)
	testing.expect_value(t, pending[0].label, "#1 Jo")
	testing.expect_value(t, pending[0].message, "hi <there> friend")

	testing.expect_value(t, guestbook_moderate(&guestbook, 1, true, frame), Moderation.Done)
	testing.expect_value(t, guestbook_moderate(&guestbook, 1, true, frame), Moderation.Not_Found)
	testing.expect_value(t, guestbook_moderate(&guestbook, 2, false, frame), Moderation.Done)
	rendered := string(frame_bytes(frame))
	testing.expect(t, strings.contains(rendered, "hi &lt;there&gt;\nfriend"), rendered)
	testing.expect(t, !strings.contains(rendered, "same network"))
	testing.expect_value(t, frame.version, 1)
}

// #lobby in memory: joining, the shared action limit (which leaving and
// rejoining can't reset), nicks and their guards, root's removal, and
// leaving, as they reach the rendered room.
@(test)
test_chat_room :: proc(t: ^testing.T) {
	arena: virtual.Arena
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)
	live := new(Live)
	second :: u64(1_000_000_000)

	testing.expect_value(t, chat_join(live, 1, false, 0), Join_Result.Joined)
	testing.expect_value(t, chat_join(live, 1, false, 0), Join_Result.Already_Here)
	testing.expect_value(t, chat_join(live, 2, true, 0), Join_Result.Joined)
	for _ in 0 ..< 4 do testing.expect_value(t, chat_say(live, 1, false, "hi <b>", 0), Say_Result.Sent)
	testing.expect_value(t, chat_say(live, 1, false, "one too many", 0), Say_Result.Too_Fast)
	testing.expect_value(t, chat_say(live, 1, false, "later", 2 * second), Say_Result.Sent)
	testing.expect_value(t, chat_say(live, 3, false, "not here", 0), Say_Result.Not_Member)

	// Leaving and rejoining spends the same budget as talking, so a
	// leave/join loop runs dry instead of flooding the room.
	testing.expect(t, chat_leave(live, 1))
	testing.expect_value(t, chat_join(live, 1, false, 2 * second), Join_Result.Joined)
	testing.expect(t, chat_leave(live, 1))
	testing.expect_value(t, chat_join(live, 1, false, 2 * second), Join_Result.Too_Fast)
	testing.expect_value(t, chat_join(live, 1, false, 4 * second), Join_Result.Joined)

	testing.expect_value(t, nick_set(&live.nicks, 1, "jo", false), Nick_Result.Set)
	testing.expect_value(t, nick_set(&live.nicks, 3, "jo", false), Nick_Result.Taken)
	testing.expect_value(t, nick_set(&live.nicks, 3, "dev", false), Nick_Result.Taken)
	testing.expect_value(t, nick_set(&live.nicks, 3, "quiet-heron", false), Nick_Result.Taken)
	testing.expect_value(t, nick_set(&live.nicks, 3, "Jo!", false), Nick_Result.Invalid)

	visitor, found := chat_find(live, "jo")
	testing.expect(t, found && visitor == 1)
	testing.expect_value(t, chat_remove(&live.chat, 1), 5)
	testing.expect(t, chat_leave(live, 1))

	testing.expect(t, chat_render(live))
	rendered := string(frame_bytes(&live.frames[.Chat]))
	testing.expect(t, strings.contains(rendered, "#lobby · 1 here"), rendered)
	testing.expect(t, strings.contains(rendered, "dev joined"))
	testing.expect(t, strings.contains(rendered, "jo left"))
	testing.expect(t, !strings.contains(rendered, "hi &lt;b&gt;"))
}
