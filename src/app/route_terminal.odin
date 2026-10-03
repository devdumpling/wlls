package app

import http "../../vendor/tina/src/extensions/http/server"
import content "../content"
import httpx "../httpx"
import views "../views"
import "core:fmt"
import "core:mem/virtual"
import "core:strconv"
import "core:strings"

// The terminal is the command side of every page: each submitted line is a
// short POST, answered by SSE patches that append the result to the
// terminal's log and morph a fresh prompt in. The server owns every command,
// so new ones (and eventually the game) are added here, not in the browser.

// A chat line is up to 200 characters, which percent-encoding can triple.
TERMINAL_BODY_MAX :: 2048

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

	scratch: virtual.Arena
	context.temp_allocator = httpx.scratch_allocator(&scratch)
	defer virtual.arena_destroy(&scratch)

	ctx := app_context(route_context)
	body, arena := http.body_buffered(request), http.request_arena(request)
	caller := caller_of(request)
	caller.session, caller.admin = admin_session(&ctx.admin, request, caller.now)

	// Each prompt posts its own field: a command, sudo's password, or a line
	// said in #lobby.
	writer := httpx.begin_patches(stream)
	result: Command_Result
	notice: string
	switch {
	case form_has(body, "say"):
		said, ok := form_value(body, "say", arena)
		if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid form")
		result, notice = chat_input(writer, strings.trim_space(said), ctx, caller)
		// In the room, output only goes to the log on the way out.
		if result == .Append do httpx.queue_elements(stream, {selector = "#terminal-output", mode = .Append})
	case form_has(body, "password"):
		password, ok := form_value(body, "password", arena)
		if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid form")
		cookie: [160]u8
		sudo, set_cookie := admin_sudo(&ctx.admin, password, caller.client, caller.now, cookie[:])
		if set_cookie != "" do _ = http.header_add(response, "Set-Cookie", set_cookie)
		views.terminal_line(writer, "[sudo] password:")
		sudo_reply(writer, sudo)
		httpx.queue_elements(stream, {selector = "#terminal-output", mode = .Append})
	case:
		line, ok := form_value(body, "command", arena)
		if !ok do return httpx.respond_text(response, http.HTTP_STATUS_BAD_REQUEST, "invalid command")
		result = run_command(writer, strings.trim_space(line), ctx, caller)
		if result == .Clear {
			httpx.queue_elements(stream) // an empty log, morphed over the old one
		} else {
			httpx.queue_elements(stream, {selector = "#terminal-output", mode = .Append})
		}
	}

	// In the room, the sender sees it at once; their stream brings the same
	// frame a moment later, and the morph makes the second one a no-op.
	if result == .Chat {
		strings.write_bytes(writer, frame_bytes(&ctx.live.frames[.Chat]))
		httpx.queue_elements(stream)
	}

	// Replace (not morph) the prompt: morphing keeps a focused input's value,
	// and the next command needs an empty line. <wlls-terminal> refocuses it.
	#partial switch result {
	case .Password:
		views.terminal_password_prompt(writer)
	case .Chat:
		views.terminal_chat_prompt(writer, notice)
	case:
		views.terminal_prompt(writer)
	}
	httpx.queue_elements(stream, {selector = "#terminal-prompt", mode = .Replace})

	return httpx.send_patches(response, stream)
}

@(private)
Command_Result :: enum {
	Append, // output is appended to the log
	Clear, // output is an empty log that replaces the old one
	Password, // output is appended, and the prompt asks for sudo's password
	Chat, // any output is appended, and the room replaces the log (chat mode)
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
		// A visitor without a cookie has no live stream yet, so isn't listed.
		render_who(output, ctx.live)
		if caller.visitor != 0 {
			name := display_name(&ctx.live.nicks, caller.visitor)
			views.terminal_line(output, fmt.tprintf("you are %s", name_string(&name)))
		}
	case "sign":
		// Signing from the terminal uses your name (nick or handle), which
		// comes with the cookie the page's live stream sets.
		if argument == "" {
			views.terminal_line(output, "usage: sign <a short note>")
			views.terminal_link(output, "or sign with a name at /guestbook", "/guestbook")
			return
		}
		if caller.visitor == 0 {
			views.terminal_error(output, NOT_CONNECTED)
			return
		}
		name := display_name(&ctx.live.nicks, caller.visitor)
		result := guestbook_sign(
			&ctx.guestbook,
			name_string(&name),
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
	case "msg":
		if caller.visitor == 0 {
			views.terminal_error(output, NOT_CONNECTED)
			return
		}
		switch chat_join(ctx.live, caller.visitor, caller.admin, caller.now) {
		case .Joined:
			if chat_render(ctx.live) do publish(ctx.live, .Chat)
		case .Already_Here:
		case .Too_Fast:
			views.terminal_error(output, "msg: slow down a little.")
			return
		case .Full:
			views.terminal_error(output, "msg: #lobby is full right now.")
			return
		}
		views.terminal_line(output, "#lobby. :help for commands, :q to go back.")
		return .Chat
	case "nick":
		if argument == "" {
			name := display_name(&ctx.live.nicks, caller.visitor)
			views.terminal_line(
				output,
				fmt.tprintf("you are %s. nick <name> to change it", name_string(&name)),
			)
			return
		}
		reply, ok := change_nick(ctx, caller, argument)
		if ok {
			views.terminal_line(output, reply)
		} else {
			views.terminal_error(output, reply)
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
		moderate_guestbook(output, name, argument, ctx)
	case "play":
		views.terminal_line(output, "not yet. it's still being built. soon.")
	case:
		command_not_found(output, name)
	}
	return
}

// chat_input handles a line said at the #lobby prompt: a :command, or else a
// message. A line is a command only when its first word is one, so messages
// that start with a colon (":)", ":D") are still messages. It returns .Chat
// to stay in the room (with an optional notice for the prompt) or .Append
// after writing a farewell to the log.
@(private = "file")
chat_input :: proc(
	output: ^strings.Builder,
	said: string,
	ctx: ^Application_Context,
	caller: Caller,
) -> (
	result: Command_Result,
	notice: string,
) {
	live := ctx.live
	if caller.visitor == 0 {
		views.terminal_error(output, NOT_CONNECTED)
		return .Append, ""
	}
	if said == "" do return .Chat, ""

	rest := said
	command, _ := strings.fields_iterator(&rest)
	argument := strings.trim_space(rest)
	switch command {
	case ":q", ":leave":
		if chat_leave(live, caller.visitor) && chat_render(live) do publish(live, .Chat)
		views.terminal_line(output, "you left #lobby.")
		return .Append, ""
	case ":who":
		if live.chat.member_count == 0 do return .Chat, "nobody's here yet."
		return .Chat, fmt.tprintf("here: %s", chat_members(live))
	case ":nick":
		reply, _ := change_nick(ctx, caller, argument)
		return .Chat, reply
	case ":help":
		if caller.admin {
			return .Chat,
				":who · :nick <name> · :q to leave · root: :mute, :unmute, :rm <name> · :wipe"
		}
		return .Chat, ":who · :nick <name> · :q to leave"
	case ":mute", ":unmute", ":rm", ":wipe":
		if caller.admin do return .Chat, moderate_chat(live, command, argument)
	}
	return .Chat, chat_message(live, caller, said)
}

// chat_message says a line in #lobby, and returns a notice if it didn't go
// out. A chat prompt left open after leaving (in another tab, say) rejoins.
@(private = "file")
chat_message :: proc(live: ^Live, caller: Caller, said: string) -> (notice: string) {
	joined := chat_join(live, caller.visitor, caller.admin, caller.now)
	changed := joined == .Joined
	switch chat_say(live, caller.visitor, caller.admin, said, caller.now) {
	case .Sent:
		changed = true
	case .Too_Fast:
		notice = "slow down a little."
	case .Muted:
		notice = "you can't post in #lobby right now."
	case .Invalid:
		notice = "messages are one line, up to 200 characters."
	case .Not_Member:
		notice = "#lobby is full right now." if joined == .Full else "slow down a little."
	}
	if changed && chat_render(live) do publish(live, .Chat)
	return
}

// moderate_chat runs root's #lobby commands and says what happened.
@(private = "file")
moderate_chat :: proc(live: ^Live, command, name: string) -> string {
	if command == ":wipe" {
		chat_wipe(&live.chat)
		if chat_render(live) do publish(live, .Chat)
		return "wiped #lobby."
	}
	visitor, found := chat_find(live, name)
	if !found do return fmt.tprintf("%s: nobody called %q in #lobby.", command, name)
	switch command {
	case ":mute":
		if !chat_mute(&live.chat, visitor) do return ":mute: the mute list is full."
		return fmt.tprintf("muted %s.", name)
	case ":unmute":
		chat_unmute(&live.chat, visitor)
		return fmt.tprintf("unmuted %s.", name)
	}
	removed := chat_remove(&live.chat, visitor)
	if removed > 0 && chat_render(live) do publish(live, .Chat)
	return fmt.tprintf("removed %d of %s's messages.", removed, name)
}

// change_nick renames the caller everywhere: `who`, #lobby, and signing.
@(private = "file")
change_nick :: proc(
	ctx: ^Application_Context,
	caller: Caller,
	name: string,
) -> (
	reply: string,
	ok: bool,
) {
	live := ctx.live
	if caller.visitor == 0 do return NOT_CONNECTED, false
	if !chat_allow(&live.chat, caller.visitor, caller.now) do return "nick: slow down a little.", false
	old := display_name(&live.nicks, caller.visitor)
	switch nick_set(&live.nicks, caller.visitor, name, caller.admin) {
	case .Set:
		if chat_renamed(live, caller.visitor, old) && chat_render(live) do publish(live, .Chat)
		return fmt.tprintf("you are now %s.", name), true
	case .Invalid:
		return "nick: 2–20 characters of a–z, 0–9, and -.", false
	case .Taken:
		return fmt.tprintf("nick: %s is taken.", name), false
	}
	return "", false
}

// Visitors get their cookie (and so their name) from the page's live stream.
@(private = "file")
NOT_CONNECTED :: "reload the page first, so it can connect."

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

// moderate_guestbook runs root's guestbook commands. An approval re-renders
// the guestbook frame, and publishing it updates every open /guestbook page.
@(private = "file")
moderate_guestbook :: proc(
	output: ^strings.Builder,
	name, argument: string,
	ctx: ^Application_Context,
) {
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
