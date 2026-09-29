package app

import datastar "../../vendor/tina/src/extensions/http/datastar"
import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
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
	_ = state
	request_start, is_start := event.(http.Request_Start)
	if !is_start do return http.close()
	_ = request_start

	ctx := cast(^Application_Context)route_context.application_context
	if ctx == nil do return http.close()

	allocator := http.request_arena(request)
	line, ok := form_value(http.body_buffered(request), "command", allocator)
	if !ok {
		return http.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid command")
	}
	line = strings.trim_space(line)

	sse, start_error := datastar.start_sse(response)
	if start_error != .None do return http.close()

	output := strings.builder_make(0, 2048, allocator)
	result := run_command(&output, line, &ctx.content)

	if result.clear {
		cleared := strings.builder_make(0, 256, allocator)
		views.terminal_output(&cleared)
		if datastar.patch_elements(&sse, strings.to_string(cleared)) != .None {
			return http.close()
		}
	} else if datastar.patch_elements(
		   &sse,
		   strings.to_string(output),
		   datastar.Patch_Elements_Options{selector = "#terminal-output", mode = .Append},
	   ) !=
	   .None {
		return http.close()
	}

	// Replace (not morph) the prompt: morphing keeps a focused input's value,
	// and the next command needs an empty line. <wlls-terminal> refocuses it.
	prompt := strings.builder_make(0, 512, allocator)
	views.terminal_prompt(&prompt)
	if datastar.patch_elements(
		   &sse,
		   strings.to_string(prompt),
		   datastar.Patch_Elements_Options{selector = "#terminal-prompt", mode = .Replace},
	   ) !=
	   .None {
		return http.close()
	}

	if result.navigate != "" {
		script := strings.concatenate({"location.assign('", result.navigate, "')"}, allocator)
		if datastar.execute_script(&sse, script) != .None do return http.close()
	}
	return http.flush(final = true)
}

@(private = "file")
Command_Result :: struct {
	clear:    bool,
	navigate: string, // a site path known to be safe to assign
}

// run_command renders a command's echo and result into output.
@(private = "file")
run_command :: proc(
	output: ^strings.Builder,
	line: string,
	repository: ^content.Repository,
) -> (
	result: Command_Result,
) {
	if line == "" {
		views.terminal_echo(output, "")
		return
	}
	views.terminal_echo(output, line)

	rest := line
	name, _ := strings.fields_iterator(&rest)
	argument := strings.trim_space(rest)

	switch name {
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
				"cd: no such place. try posts, about, ~, or a post from ls",
			)
			return
		}
		views.terminal_line(output, target)
		result.navigate = target
	case "play":
		views.terminal_line(output, "not yet. it's still being built. soon.")
	case "clear":
		result.clear = true
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
	case "posts", "blog":
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
