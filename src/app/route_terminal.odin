package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import httpx "../httpx"
import views "../views"
import "core:strings"

// The landing-page terminal is the command side of the page: each submitted
// line is a short POST, answered by SSE patches that append the result to the
// terminal's log and morph a fresh prompt in. The server owns every command,
// so new ones (and eventually the game) are added here, not in the browser.
TERMINAL_BODY_MAX :: 512

terminal_command :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	stream := cast(^httpx.Patch_Stream)state
	if _, starting := event.(http.Request_Start); !starting {
		return httpx.drive_patches(event, response, stream)
	}

	ctx := app_context(route_context)
	line, ok := form_value(http.body_buffered(request), "command", http.request_arena(request))
	if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid command")

	writer := httpx.begin_patches(stream)
	if run_command(writer, strings.trim_space(line), &ctx.content) == .Clear {
		httpx.queue_elements(stream) // an empty log, morphed over the old one
	} else {
		httpx.queue_elements(stream, {selector = "#terminal-output", mode = .Append})
	}

	// Replace (not morph) the prompt: morphing keeps a focused input's value,
	// and the next command needs an empty line. <wlls-terminal> refocuses it.
	views.terminal_prompt(writer)
	httpx.queue_elements(stream, {selector = "#terminal-prompt", mode = .Replace})

	return httpx.send_patches(response, stream)
}

// The terminal's per-request state: its queued patches and their render.
@(private)
TERMINAL_STATE_SIZE :: u16(size_of(httpx.Patch_Stream))

@(private)
Command_Result :: enum {
	Append, // output is appended to the log
	Clear, // output is an empty log that replaces the old one
}

// run_command renders a command's echo and result into output. clear renders
// an empty log instead, which replaces the old one; cd appends an element that
// navigates once Datastar patches it in.
@(private)
run_command :: proc(
	output: ^strings.Builder,
	line: string,
	repository: ^content.Repository,
) -> (
	result: Command_Result,
) {
	rest := line
	name, _ := strings.fields_iterator(&rest)
	argument := strings.trim_space(rest)
	if name == "clear" {
		views.terminal_output(output)
		return .Clear
	}

	views.terminal_echo(output, line)
	switch name {
	case "":
	case "help", "?":
		views.terminal_help(output)
	case "ls":
		views.terminal_posts(output, content.published_posts(repository))
	case "whoami":
		views.terminal_line(
			output,
			"dev. reading, writing, breaking things. doing the dad thing. bird by bird.",
		)
		views.terminal_link(output, "more in /about", "/about")
	case "cd":
		target, found := resolve_place(argument, repository)
		if !found {
			views.terminal_error(
				output,
				"cd: no such place. try blog, about, ~, or a post from ls",
			)
			return
		}
		views.terminal_line(output, target)
		views.terminal_navigate(output, target)
	case "play":
		views.terminal_line(output, "not yet. it's still being built. soon.")
	case:
		message := strings.concatenate(
			{"command not found: ", name, ". try help"},
			context.temp_allocator,
		)
		views.terminal_error(output, message)
	}
	return
}

// resolve_place maps cd arguments onto real site paths only, so navigation
// can never be steered to arbitrary URLs.
@(private = "file")
resolve_place :: proc(
	place: string,
	repository: ^content.Repository,
) -> (
	path: string,
	found: bool,
) {
	switch strings.trim(place, "/") {
	case "", "~", "..", "home":
		return "/", true
	case "blog", "posts":
		return "/blog", true
	case "about":
		return "/about", true
	}
	slug := strings.trim_prefix(strings.trim(place, "/"), "blog/")
	post := content.find_post(repository, slug) or_return
	return post.url, true
}

// form_value reads one field from an application/x-www-form-urlencoded body.
@(private = "file")
form_value :: proc(
	body: []u8,
	name: string,
	allocator := context.allocator,
) -> (
	value: string,
	ok: bool,
) {
	rest := string(body)
	for pair in strings.split_iterator(&rest, "&") {
		separator := strings.index_byte(pair, '=')
		if separator < 0 || pair[:separator] != name do continue
		raw := pair[separator + 1:]
		decoded := make([]u8, len(raw), allocator)
		size := http.percent_decode(decoded, raw) or_return
		return string(decoded[:size]), true
	}
	return "", true
}
