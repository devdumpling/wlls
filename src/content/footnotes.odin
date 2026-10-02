package content

import "core:strings"

@(private)
Footnote_Error :: enum {
	None,
	Allocation,
	Block_Content,
}

// transform_footnotes prepares footnotes for two presentations; CSS shows one.
// Every reference is bound to the word before it with a WORD JOINER (U+2060),
// so a `[1]` never wraps onto a line of its own. The first reference to each
// note is followed by a sidenote: a copy of the note that wide screens hang in
// the margin beside it, while narrow screens keep the notes section at the end
// of the post. The copy sits inside the referencing paragraph, so it may only
// hold phrasing content. A note with lists, code, or quotes is reported by its
// label instead. Raw HTML is escaped upstream, so every tag matched here came
// from cmark itself.
@(private)
transform_footnotes :: proc(
	source: string,
	allocator := context.allocator,
) -> (
	output: string,
	error: Footnote_Error,
	detail: string,
) {
	SECTION :: `<section class="footnotes" data-footnotes>`
	REF :: `<sup class="footnote-ref"><a href="#fn-`
	WORD_JOINER :: "⁠"

	// cmark renders the notes section last, after every reference.
	body, section := source, ""
	if start := strings.index(source, SECTION); start >= 0 {
		body, section = source[:start], source[start:]
	}
	notes, note_error, label := collect_sidenotes(section)
	if note_error != .None do return "", note_error, label

	builder, allocation_error := strings.builder_make(0, len(source) + len(section), allocator)
	if allocation_error != nil do return "", .Allocation, ""
	seen := make(map[string]bool, allocator = context.temp_allocator)

	rest := body
	for {
		start := strings.index(rest, REF)
		if start < 0 do break
		end := strings.index(rest[start:], "</sup>")
		if end < 0 do break
		end += start + len("</sup>")
		reference := rest[start:end]
		strings.write_string(&builder, rest[:start])
		strings.write_string(&builder, WORD_JOINER)
		strings.write_string(&builder, reference)
		rest = rest[end:]

		note_label := between(reference, REF, `"`)
		if seen[note_label] do continue
		seen[note_label] = true
		if note, found := notes[note_label]; found {
			strings.write_string(&builder, `<span class="sidenote" role="note">`)
			strings.write_string(&builder, `<span class="sidenote-number">`)
			strings.write_string(&builder, between(reference, "data-footnote-ref>", "</a>"))
			strings.write_string(&builder, "</span> ")
			strings.write_string(&builder, note)
			strings.write_string(&builder, "</span>")
		}
	}
	strings.write_string(&builder, rest)
	strings.write_string(&builder, section)
	return strings.to_string(builder), .None, ""
}

// collect_sidenotes maps each note's label to its sidenote copy: every
// paragraph of the note becomes a span, without the links back to the text.
@(private = "file")
collect_sidenotes :: proc(
	section: string,
) -> (
	notes: map[string]string,
	error: Footnote_Error,
	label: string,
) {
	ITEM :: `<li id="fn-`
	BACKREF :: `<a href="#fnref-`

	notes = make(map[string]string, allocator = context.temp_allocator)
	rest := section
	for {
		start := strings.index(rest, ITEM)
		if start < 0 do break
		rest = rest[start + len(ITEM):]
		label_end := strings.index(rest, `">`)
		end := strings.index(rest, "</li>")
		if label_end < 0 || end < label_end do break
		label = rest[:label_end]
		note := strings.trim_space(rest[label_end + len(`">`):end])
		rest = rest[end:]

		builder := strings.builder_make(context.temp_allocator)
		for note != "" {
			paragraph_end := strings.index(note, "</p>")
			if !strings.has_prefix(note, "<p>") || paragraph_end < 0 {
				return notes, .Block_Content, label
			}
			text := note[len("<p>"):paragraph_end]
			note = strings.trim_left_space(note[paragraph_end + len("</p>"):])

			strings.write_string(&builder, `<span class="sidenote-para">`)
			for {
				backref := strings.index(text, BACKREF)
				if backref < 0 do break
				strings.write_string(&builder, strings.trim_right_space(text[:backref]))
				backref_end := strings.index(text[backref:], "</a>")
				text = backref_end < 0 ? "" : text[backref + backref_end + len("</a>"):]
			}
			strings.write_string(&builder, text)
			strings.write_string(&builder, "</span>")
		}
		notes[label] = strings.to_string(builder)
	}
	return notes, .None, ""
}

// between returns the text after the first open and before the next close.
@(private = "file")
between :: proc(text, open, close: string) -> string {
	start := strings.index(text, open)
	if start < 0 do return ""
	rest := text[start + len(open):]
	end := strings.index(rest, close)
	return end < 0 ? "" : rest[:end]
}
