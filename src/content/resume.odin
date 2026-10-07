package content

import "core:fmt"
import "core:strings"

// The resume is one Markdown file (content/pages/resume.md) that reads well
// as plain Markdown, since it is also served as /resume.md, and still has
// enough structure for a designed page:
//
//	# Name
//	Headline, one line
//	Anything else under the name: contact links, a summary.
//	## Section              Experience, Education, Toolkit, …
//	### Entry               a company, school, or project
//	*Dates*                 an emphasized line right under an entry or role
//	#### Role               a title held at the entry
//	> **The story**         a quote is a story: collapsed on screen, not printed
// Text under any heading is ordinary Markdown.
Resume :: struct {
	title:       string,
	description: string,
	updated:     string, // the front matter's date, YYYY-MM-DD
	canonical:   string,
	name:        string,
	headline:    string,
	intro:       Markdown_HTML,
	sections:    [dynamic]Resume_Section,
	links:       [dynamic]string, // http(s) links under the name, such as GitHub
	pdf_name:    string, // the download's file name: devon-wells-resume.pdf
	markdown:    string, // the file without front matter, links made absolute
}

Resume_Section :: struct {
	id:      string,
	title:   string,
	body:    Markdown_HTML,
	entries: [dynamic]Resume_Entry,
}

Resume_Entry :: struct {
	id:    string,
	name:  string, // the heading as plain text, for the terminal
	title: Markdown_HTML, // the heading as inline HTML; a project's is a link
	dates: string,
	body:  Markdown_HTML,
	roles: [dynamic]Resume_Role,
}

Resume_Role :: struct {
	title: Markdown_HTML,
	dates: string,
	body:  Markdown_HTML,
}

// parse_resume reads the resume at startup. A misplaced heading, a missing
// field, or a link to a post that doesn't exist is a startup error, as it is
// for posts. Posts must already be loaded, so links to them can be checked.
@(private)
parse_resume :: proc(
	path, source, base_url: string,
	repository: ^Repository,
	images: Image_Sizes,
) -> (
	resume: Resume,
	error: string,
) {
	metadata, body, split_error := split_front_matter(path, source)
	if split_error != "" do return resume, split_error
	fields, parse_error := parse_metadata(path, metadata)
	if parse_error != "" do return resume, parse_error
	if fields.title == "" || fields.description == "" || fields.date == "" {
		return resume, fmt.tprintf("%s requires title, description, and date", path)
	}
	resume.title = fields.title
	resume.description = fields.description
	resume.updated = fields.date
	resume.canonical = fmt.aprintf("%s/resume", base_url)

	if link_error := check_post_links(path, body, repository); link_error != "" {
		return resume, link_error
	}

	// The resume leaves the site as Markdown and as a PDF, where a relative
	// link means nothing (or points at whatever server printed it), so its
	// site links are made absolute before anything renders.
	body, _ = strings.replace_all(body, "](/", fmt.tprintf("](%s/", base_url))

	ids := make(map[string]bool, allocator = context.temp_allocator)
	for block in split_headings(body) {
		text := block.text
		switch block.level {
		case 0:
			if strings.trim_space(text) != "" {
				return resume, fmt.tprintf("%s has text before its # name heading", path)
			}
		case 1:
			resume.name = block.heading
			intro: string
			resume.headline, intro = split_headline(text)
			if resume.headline == "" {
				return resume, fmt.tprintf("%s needs a one-line headline under the name", path)
			}
			resume.intro, error = render_resume_markdown(path, intro, images)
			collect_links(&resume.links, intro)
		case 2:
			section := Resume_Section {
				title = block.heading,
				id    = heading_slug(block.heading),
			}
			section.body, error = render_resume_markdown(path, text, images)
			append(&resume.sections, section)
		case 3:
			if len(resume.sections) == 0 {
				return resume, fmt.tprintf(
					"%s: ### %s is not under a ## section",
					path,
					block.heading,
				)
			}
			section := &resume.sections[len(resume.sections) - 1]
			entry: Resume_Entry
			entry.title, error = render_inline(path, block.heading)
			entry.name = plain_text(string(entry.title))
			entry.id = heading_slug(string(entry.title))
			entry.dates, text = take_dateline(text)
			if error == "" do entry.body, error = render_resume_markdown(path, text, images)
			append(&section.entries, entry)
		case 4:
			if len(resume.sections) == 0 ||
			   len(resume.sections[len(resume.sections) - 1].entries) == 0 {
				return resume, fmt.tprintf(
					"%s: #### %s is not under a ### entry",
					path,
					block.heading,
				)
			}
			entries := &resume.sections[len(resume.sections) - 1].entries
			role: Resume_Role
			role.title, error = render_inline(path, block.heading)
			role.dates, text = take_dateline(text)
			if error == "" do role.body, error = render_resume_markdown(path, text, images)
			append(&entries[len(entries) - 1].roles, role)
		}
		if error != "" do return
	}
	if resume.name == "" do return resume, fmt.tprintf("%s needs a # name heading", path)

	// Section and entry ids share the page, so they must not collide.
	for section in resume.sections {
		if section.id in ids do return resume, fmt.tprintf("%s repeats the heading %s", path, section.title)
		ids[section.id] = true
		for entry in section.entries {
			if entry.id in ids do return resume, fmt.tprintf("%s repeats the heading %s", path, entry.name)
			ids[entry.id] = true
		}
	}

	resume.pdf_name = fmt.aprintf("%s-resume.pdf", heading_slug(resume.name))
	resume.markdown = strings.trim_left(body, "\n")
	return resume, ""
}

// Resume_Block is a heading (levels 1–4) and the text under it, up to the
// next one. Level 0 is any text before the first heading.
@(private = "file")
Resume_Block :: struct {
	level:   int,
	heading: string,
	text:    string,
}

// split_headings cuts Markdown at its ATX headings, skipping fenced code,
// where a # line is code, not a heading. Every string borrows source.
@(private = "file")
split_headings :: proc(source: string) -> []Resume_Block {
	blocks := make([dynamic]Resume_Block, context.temp_allocator)
	current := Resume_Block{}
	text_start := 0
	in_fence := false
	offset := 0
	rest := source
	for line in strings.split_lines_after_iterator(&rest) {
		line_start := offset
		offset += len(line)
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "```") || strings.has_prefix(trimmed, "~~~") {
			in_fence = !in_fence
		}
		if in_fence do continue
		level := heading_level(trimmed)
		if level == 0 do continue

		current.text = source[text_start:line_start]
		append(&blocks, current)
		current = {
			level   = level,
			heading = strings.trim_space(trimmed[level:]),
		}
		text_start = offset
	}
	current.text = source[text_start:]
	append(&blocks, current)
	return blocks[:]
}

// heading_level counts a line's leading #s, if they make a heading the resume
// structures (1–4). Deeper headings stay part of the text.
@(private = "file")
heading_level :: proc(line: string) -> int {
	level := 0
	for level < len(line) && line[level] == '#' do level += 1
	if level == 0 || level > 4 || level == len(line) || line[level] != ' ' do return 0
	return level
}

// split_headline takes the first line of text as the headline; the rest is
// the intro.
@(private = "file")
split_headline :: proc(text: string) -> (headline, rest: string) {
	trimmed := strings.trim_left(text, " \t\n")
	end := strings.index_byte(trimmed, '\n')
	if end < 0 do return strings.trim_space(trimmed), ""
	return strings.trim_space(trimmed[:end]), trimmed[end + 1:]
}

// take_dateline returns the dates when the text opens with one emphasized
// line (*Feb 2025 – Present*), and the text after it.
@(private = "file")
take_dateline :: proc(text: string) -> (dates, rest: string) {
	trimmed := strings.trim_left(text, " \t\n")
	end := strings.index_byte(trimmed, '\n')
	if end < 0 do end = len(trimmed)
	line := strings.trim_space(trimmed[:end])
	if len(line) < 3 do return "", text
	mark := line[0]
	if (mark != '*' && mark != '_') || line[len(line) - 1] != mark || line[1] == mark {
		return "", text
	}
	return strings.trim_space(line[1:len(line) - 1]), trimmed[end:]
}

// render_resume_markdown renders a block of text, turning quotes into story
// disclosures. Empty text renders as nothing.
@(private = "file")
render_resume_markdown :: proc(
	path, text: string,
	images: Image_Sizes,
) -> (
	html: Markdown_HTML,
	error: string,
) {
	if strings.trim_space(text) == "" do return "", ""
	rendered, markdown_error, detail := render_markdown(text, images)
	if markdown_error != .None do return "", markdown_error_message(path, markdown_error, detail)
	return Markdown_HTML(transform_stories(string(rendered))), ""
}

// render_inline renders one line of Markdown, such as a heading, without the
// paragraph cmark wraps it in.
@(private = "file")
render_inline :: proc(path, text: string) -> (html: Markdown_HTML, error: string) {
	rendered, markdown_error, detail := render_markdown(text)
	if markdown_error != .None do return "", markdown_error_message(path, markdown_error, detail)
	paragraph := strings.trim_suffix(strings.trim_space(string(rendered)), "</p>")
	return Markdown_HTML(strings.trim_prefix(paragraph, "<p>")), ""
}

// transform_stories turns each blockquote into a collapsed <details>. A
// first paragraph that is all bold (> **The story**) becomes its summary.
// Raw HTML is escaped upstream, so every <blockquote> here came from cmark.
@(private = "file")
transform_stories :: proc(html: string) -> string {
	OPEN :: "<blockquote>\n"
	LEAD_OPEN :: "<p><strong>"
	LEAD_CLOSE :: "</strong></p>\n"

	builder := strings.builder_make(0, len(html) + 128)
	rest := html
	for {
		open := strings.index(rest, OPEN)
		if open < 0 do break
		strings.write_string(&builder, rest[:open])
		rest = rest[open + len(OPEN):]

		summary := "More"
		if strings.has_prefix(rest, LEAD_OPEN) {
			if end := strings.index(rest, LEAD_CLOSE); end > 0 {
				summary = rest[len(LEAD_OPEN):end]
				rest = rest[end + len(LEAD_CLOSE):]
			}
		}
		strings.write_string(&builder, `<details class="resume-story"><summary>`)
		strings.write_string(&builder, summary)
		strings.write_string(&builder, "</summary>\n<div class=\"resume-story-body\">\n")
	}
	strings.write_string(&builder, rest)
	output, _ := strings.replace_all(
		strings.to_string(builder),
		"</blockquote>",
		"</div>\n</details>",
	)
	return output
}

// collect_links finds the absolute web links in Markdown: profiles to list
// in the page's structured data.
@(private = "file")
collect_links :: proc(links: ^[dynamic]string, text: string) {
	rest := text
	for {
		start := strings.index(rest, "](http")
		if start < 0 do return
		rest = rest[start + 2:]
		end := strings.index_byte(rest, ')')
		if end < 0 do return
		append(links, rest[:end])
		rest = rest[end:]
	}
}

// check_post_links fails when the resume links to a post that isn't
// published, so a renamed post can't leave a dead link behind.
@(private = "file")
check_post_links :: proc(path, text: string, repository: ^Repository) -> string {
	PREFIX :: "](/blog/"
	rest := text
	for {
		start := strings.index(rest, PREFIX)
		if start < 0 do return ""
		rest = rest[start + len(PREFIX):]
		end := strings.index_any(rest, ")#")
		if end < 0 do end = len(rest)
		if _, found := find_post(repository, rest[:end]); !found {
			return fmt.tprintf(
				"%s links to /blog/%s, which is not a published post",
				path,
				rest[:end],
			)
		}
	}
}

// plain_text strips tags from inline HTML and decodes the entities cmark
// writes, for places that want text, like the terminal.
@(private = "file")
plain_text :: proc(html: string) -> string {
	builder := strings.builder_make(0, len(html))
	in_tag := false
	for character in transmute([]u8)html {
		switch {
		case character == '<':
			in_tag = true
		case character == '>':
			in_tag = false
		case !in_tag:
			strings.write_byte(&builder, character)
		}
	}
	ENTITIES :: [?][2]string {
		{"&lt;", "<"},
		{"&gt;", ">"},
		{"&quot;", `"`},
		{"&#39;", "'"},
		{"&amp;", "&"},
	}
	text := strings.to_string(builder)
	for entity in ENTITIES {
		text, _ = strings.replace_all(text, entity[0], entity[1])
	}
	return text
}
