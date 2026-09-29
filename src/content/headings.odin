package content

import "base:runtime"
import "core:strconv"
import "core:strings"

// transform_headings gives each h2–h4 a slug id derived from its text and
// appends a permalink, so any section can be linked to. Duplicate slugs get
// numeric suffixes. cmark emits bare heading tags, so matching them is exact.
@(private)
transform_headings :: proc(
	source: string,
	allocator := context.allocator,
) -> (
	output: string,
	error: runtime.Allocator_Error,
) {
	builder := strings.builder_make(0, len(source) + 512, allocator) or_return
	seen := make(map[string]int, allocator = context.temp_allocator)

	rest := source
	for {
		start := strings.index(rest, "<h")
		if start < 0 || start + 4 > len(rest) do break
		level := rest[start + 2]
		if level < '2' || level > '4' || rest[start + 3] != '>' {
			strings.write_string(&builder, rest[:start + 2])
			rest = rest[start + 2:]
			continue
		}
		closing := [5]byte{'<', '/', 'h', level, '>'}
		inner_start := start + 4
		inner_end := strings.index(rest[inner_start:], string(closing[:]))
		if inner_end < 0 do break
		inner := rest[inner_start:inner_start + inner_end]

		slug := heading_slug(inner)
		if slug == "" do slug = "section"
		count := seen[slug]
		seen[slug] = count + 1
		if count > 0 {
			buffer: [8]byte
			slug = strings.concatenate(
				{slug, "-", strconv.write_int(buffer[:], i64(count + 1), 10)},
				context.temp_allocator,
			)
		}

		strings.write_string(&builder, rest[:start])
		strings.write_string(&builder, "<h")
		strings.write_byte(&builder, level)
		strings.write_string(&builder, ` id="`)
		strings.write_string(&builder, slug)
		strings.write_string(&builder, `">`)
		strings.write_string(&builder, inner)
		strings.write_string(&builder, ` <a class="heading-anchor" href="#`)
		strings.write_string(&builder, slug)
		strings.write_string(&builder, `" aria-label="Link to this section">#</a>`)
		strings.write_string(&builder, string(closing[:]))
		rest = rest[inner_start + inner_end + len(closing):]
	}
	strings.write_string(&builder, rest)
	return strings.to_string(builder), nil
}

// heading_slug lowercases the heading's visible text, keeping ASCII letters
// and digits and collapsing everything else (tags, entities, punctuation)
// into single hyphens.
@(private = "file")
heading_slug :: proc(inner: string) -> string {
	builder := strings.builder_make(0, len(inner), context.temp_allocator)
	in_tag, in_entity, pending_hyphen := false, false, false
	for character in transmute([]byte)inner {
		switch {
		case in_tag:
			in_tag = character != '>'
			continue
		case character == '<':
			in_tag = true
			continue
		case in_entity:
			in_entity = character != ';'
			if !in_entity do pending_hyphen = true
			continue
		case character == '&':
			in_entity = true
			continue
		}
		lower := character
		if lower >= 'A' && lower <= 'Z' do lower += 'a' - 'A'
		if (lower >= 'a' && lower <= 'z') || (lower >= '0' && lower <= '9') {
			if pending_hyphen && strings.builder_len(builder) > 0 {
				strings.write_byte(&builder, '-')
			}
			pending_hyphen = false
			strings.write_byte(&builder, lower)
		} else {
			pending_hyphen = true
		}
	}
	return strings.to_string(builder)
}
