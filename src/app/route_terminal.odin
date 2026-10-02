package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import httpx "../httpx"
import views "../views"
import "core:fmt"
import "core:strconv"
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
	body, arena := http.body_buffered(request), http.request_arena(request)
	caller := caller_of(request)
	caller.session, caller.admin = admin_session(&ctx.admin, request, caller.now)

	// sudo's password prompt posts a password field instead of a command.
	writer := httpx.begin_patches(stream)
	result: Command_Result
	if form_has(body, "password") {
		password, ok := form_value(body, "password", arena)
		if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid form")
		cookie: [160]u8
		sudo, set_cookie := admin_sudo(&ctx.admin, password, caller.now, cookie[:])
		if set_cookie != "" do _ = http.header_add(response, "Set-Cookie", set_cookie)
		views.terminal_line(writer, "[sudo] password:")
		sudo_reply(writer, sudo)
	} else {
		line, ok := form_value(body, "command", arena)
		if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid command")
		result = run_command(writer, strings.trim_space(line), ctx, caller)
	}
	if result == .Clear {
		httpx.queue_elements(stream) // an empty log, morphed over the old one
	} else {
		httpx.queue_elements(stream, {selector = "#terminal-output", mode = .Append})
	}

	// Replace (not morph) the prompt: morphing keeps a focused input's value,
	// and the next command needs an empty line. <wlls-terminal> refocuses it.
	if result == .Password {
		views.terminal_password_prompt(writer)
	} else {
		views.terminal_prompt(writer)
	}
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
	Password, // output is appended, and the prompt asks for sudo's password
}

// run_command renders a command's echo and result into output. clear renders
// an empty log instead, which replaces the old one; cd appends an element that
// navigates once Datastar patches it in. exit never arrives: <wlls-terminal>
// handles it in the browser.
@(private)
run_command :: proc(
	output: ^strings.Builder,
	line: string,
	ctx: ^Application_Context,
	caller: Caller,
) -> (
	result: Command_Result,
) {
	repository := &ctx.content
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
				"cd: no such place. try blog, guestbook, about, ~, or a post from ls",
			)
			return
		}
		views.terminal_line(output, target)
		views.terminal_navigate(output, target)
	case "who":
		// The hub keeps the list current; a visitor without a cookie has no
		// live stream yet, so they are not on it.
		strings.write_bytes(output, frame_bytes(&ctx.live.who))
		if caller.visitor != 0 {
			adjective, animal := visitor_name(caller.visitor)
			views.terminal_line(
				output,
				strings.concatenate({"you are ", adjective, "-", animal}, context.temp_allocator),
			)
		}
	case "sign":
		// Signing from the terminal uses your handle as the name.
		if argument == "" {
			views.terminal_line(output, "usage: sign <a short note>")
			views.terminal_link(output, "or sign with a name at /guestbook", "/guestbook")
			return
		}
		adjective, animal := visitor_name(caller.visitor)
		name := strings.concatenate({adjective, "-", animal}, context.temp_allocator)
		result := guestbook_sign(
			&ctx.guestbook,
			name,
			argument,
			caller.visitor,
			caller.client,
			caller.now,
		)
		if result == .Signed {
			views.terminal_line(output, sign_reply(result))
		} else {
			views.terminal_error(output, sign_reply(result))
		}
	case "sudo":
		switch {
		case argument == "-k" && caller.admin:
			admin_sign_out(&ctx.admin, caller.session)
			views.terminal_line(output, "signed out.")
		case caller.admin:
			views.terminal_line(output, "already root. try pending, or sudo -k to sign out.")
		case !ctx.admin.enabled:
			views.terminal_error(output, "sudo: nobody here can do that.")
		case:
			return .Password
		}
	case "pending", "approve", "reject":
		if !caller.admin {
			command_not_found(output, name)
			return
		}
		moderate(output, name, argument, ctx)
	case "play":
		views.terminal_line(output, "not yet. it's still being built. soon.")
	case:
		command_not_found(output, name)
	}
	return
}

@(private = "file")
command_not_found :: proc(output: ^strings.Builder, name: string) {
	message := strings.concatenate(
		{"command not found: ", name, ". try help"},
		context.temp_allocator,
	)
	views.terminal_error(output, message)
}

@(private = "file")
sudo_reply :: proc(output: ^strings.Builder, result: Sudo_Result) {
	switch result {
	case .Granted:
		views.terminal_line(output, "root. try pending, approve <id>, reject <id>, or sudo -k.")
	case .Denied:
		views.terminal_error(output, "sudo: incorrect password.")
	case .Locked:
		views.terminal_error(output, "sudo: too many tries. locked for a while.")
	case .Disabled:
		views.terminal_error(output, "sudo: nobody here can do that.")
	}
}

// moderate runs the root-only guestbook commands. An approval re-renders the
// guestbook frame, and publishing it updates every open /guestbook page.
@(private = "file")
moderate :: proc(output: ^strings.Builder, name, argument: string, ctx: ^Application_Context) {
	if name == "pending" {
		entries, total, ok := guestbook_pending(&ctx.guestbook, context.temp_allocator)
		switch {
		case !ok:
			views.terminal_error(output, "pending: couldn't read the guestbook.")
		case total == 0:
			views.terminal_line(output, "nothing waiting.")
		case:
			summary := fmt.tprintf("%d waiting. approve <id> or reject <id>", total)
			views.terminal_pending(output, entries, summary)
		}
		return
	}

	id, parsed := strconv.parse_i64(strings.trim_prefix(argument, "#"))
	if !parsed {
		views.terminal_error(output, fmt.tprintf("usage: %s <id>", name))
		return
	}
	approve := name == "approve"
	switch guestbook_moderate(&ctx.guestbook, id, approve, &ctx.live.frames[.Guestbook]) {
	case .Done:
		if approve do publish(ctx.live, .Guestbook)
		views.terminal_line(output, fmt.tprintf("%sd #%d.", name, id))
	case .Not_Found:
		views.terminal_error(output, fmt.tprintf("%s: no unread entry #%d.", name, id))
	case .Failed:
		views.terminal_error(output, fmt.tprintf("%s: that didn't work; see the logs.", name))
	}
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
	case "guestbook":
		return "/guestbook", true
	}
	slug := strings.trim_prefix(strings.trim(place, "/"), "blog/")
	post := content.find_post(repository, slug) or_return
	return post.url, true
}

// form_has reports whether an application/x-www-form-urlencoded body has a
// field, even an empty one.
@(private)
form_has :: proc(body: []u8, name: string) -> bool {
	rest := string(body)
	for pair in strings.split_iterator(&rest, "&") {
		key, _, _ := strings.partition(pair, "=")
		if key == name do return true
	}
	return false
}

// form_value reads one field from an application/x-www-form-urlencoded body.
@(private)
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
