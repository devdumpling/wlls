package content

import "core:strings"

// Embed names an interactive component a post places with a fenced code
// block whose language is `embed:<name>`:
//
//     ```embed:copilot
//     // check if a string is a palindrome
//     ```
//
// Raw HTML stays disabled, so this is the one way a post asks for a custom
// element. Each component lives in src/assets/static/js/embed-<name>.js, and
// a post's page loads only the scripts (and css/embeds.css) it uses.
Embed :: enum u8 {
	Copilot,
	Latency,
	Ping,
	Slow,
}
Embeds :: bit_set[Embed]

// Embed_Fallback is what a reader without the component sees: no
// JavaScript, a feed reader, or print. The component enhances it in place.
Embed_Fallback :: enum u8 {
	// The fence as a code block; its text is also the component's script.
	Code,
	// Nothing. The fence must be empty.
	None,
	// The paragraph right after the fence, which must be empty.
	Next_Paragraph,
}

Embed_Spec :: struct {
	name:     string, // after `embed:`, and in the script's file name
	element:  string,
	fallback: Embed_Fallback,
	// margin embeds hang beside the text where the margin has room, like
	// sidenotes; elsewhere they sit in the text column.
	margin:   bool,
}

@(rodata)
EMBED_SPECS := [Embed]Embed_Spec {
	.Copilot = {name = "copilot", element = "wlls-copilot", fallback = .Code, margin = true},
	.Latency = {name = "latency", element = "wlls-latency", fallback = .None},
	.Ping    = {name = "ping", element = "wlls-ping", fallback = .None},
	.Slow    = {name = "slow", element = "wlls-slow", fallback = .Next_Paragraph},
}

@(private)
Embed_Error :: enum {
	None,
	Allocation,
	Unknown,
	// An embed without a code fallback was given text, or one that enhances
	// the next paragraph wasn't followed by one.
	Misused,
}

// transform_embeds wraps each `embed:` code block in its component:
//
//     <div class="embed" data-embed="copilot" data-margin><wlls-copilot>
//       fallback
//     </wlls-copilot></div>
//
// used collects the kinds found, so the page can load just their scripts.
// cmark escapes the fence's text, so it is copied through verbatim.
@(private)
transform_embeds :: proc(
	source: string,
	allocator := context.allocator,
) -> (
	output: string,
	used: Embeds,
	error: Embed_Error,
	detail: string,
) {
	OPEN :: `<pre><code class="language-embed:`
	CLOSE :: "</code></pre>\n"
	PARAGRAPH_CLOSE :: "</p>\n"

	builder, allocation_error := strings.builder_make(0, len(source) + 256, allocator)
	if allocation_error != nil do return "", {}, .Allocation, ""
	defer if error != .None do strings.builder_destroy(&builder)

	rest := source
	for {
		start := strings.index(rest, OPEN)
		if start < 0 do break
		strings.write_string(&builder, rest[:start])
		rest = rest[start + len(OPEN):]

		name_end := strings.index(rest, `">`)
		body_end := strings.index(rest, CLOSE)
		if name_end < 0 || body_end < name_end do return "", used, .Misused, rest[:max(name_end, 0)]
		name := rest[:name_end]
		body := rest[name_end + len(`">`):body_end]
		rest = rest[body_end + len(CLOSE):]

		kind, found := embed_named(name)
		if !found do return "", used, .Unknown, name
		spec := EMBED_SPECS[kind]
		used += {kind}

		strings.write_string(&builder, `<div class="embed" data-embed="`)
		strings.write_string(&builder, spec.name)
		strings.write_string(&builder, spec.margin ? `" data-margin><` : `"><`)
		strings.write_string(&builder, spec.element)
		strings.write_string(&builder, ">")
		switch spec.fallback {
		case .Code:
			strings.write_string(&builder, "<pre><code>")
			strings.write_string(&builder, body)
			strings.write_string(&builder, "</code></pre>")
		case .None:
			if strings.trim_space(body) != "" do return "", used, .Misused, name
		case .Next_Paragraph:
			paragraph_end := strings.index(rest, PARAGRAPH_CLOSE)
			if strings.trim_space(body) != "" || !strings.has_prefix(rest, "<p>") || paragraph_end < 0 {
				return "", used, .Misused, name
			}
			strings.write_string(&builder, rest[:paragraph_end + len("</p>")])
			rest = rest[paragraph_end + len(PARAGRAPH_CLOSE):]
		}
		strings.write_string(&builder, "</")
		strings.write_string(&builder, spec.element)
		strings.write_string(&builder, "></div>\n")
	}
	strings.write_string(&builder, rest)
	return strings.to_string(builder), used, .None, ""
}

@(private = "file")
embed_named :: proc(name: string) -> (Embed, bool) {
	for spec, kind in EMBED_SPECS {
		if spec.name == name do return kind, true
	}
	return {}, false
}
