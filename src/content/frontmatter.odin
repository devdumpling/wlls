package content

import "core:fmt"
import "core:strings"

// The authored files use a deliberately small front-matter vocabulary. Keep
// parsing here, separate from repository indexing and Markdown rendering.
@(private)
Front_Matter :: struct {
	title:       string,
	description: string,
	topic:       string,
	date:        string,
	draft:       bool,
}

@(private)
split_front_matter :: proc(path, source: string) -> (metadata, body, error: string) {
	if !strings.has_prefix(source, "---\n") {
		return "", "", fmt.tprintf("content %s is missing its opening --- front-matter line", path)
	}
	rest := source[4:]
	end := strings.index(rest, "\n---\n")
	if end < 0 do return "", "", fmt.tprintf("content %s is missing its closing --- front-matter line", path)
	return rest[:end], rest[end + 5:], ""
}

@(private)
parse_metadata :: proc(path, source: string) -> (fields: Front_Matter, error: string) {
	remaining := source
	for len(remaining) > 0 {
		line_end := strings.index(remaining, "\n")
		line := remaining
		if line_end >= 0 {
			line = remaining[:line_end]
			remaining = remaining[line_end + 1:]
		} else {
			remaining = ""
		}
		line = strings.trim_space(line)
		if line == "" do continue
		separator := strings.index(line, ":")
		if separator <= 0 {
			return fields, fmt.tprintf("content %s has invalid metadata", path)
		}
		key := strings.trim_space(line[:separator])
		value, value_error := metadata_value(line[separator + 1:])
		if value_error != "" {
			return fields, fmt.tprintf(
				"content %s has invalid %s metadata: %s",
				path,
				key,
				value_error,
			)
		}
		switch key {
		case "title":
			fields.title = value
		case "description":
			fields.description = value
		case "topic":
			fields.topic = value
		case "date":
			fields.date = value
		case "draft":
			if value == "true" {
				fields.draft = true
			} else if value != "false" {
				return fields, fmt.tprintf("content %s draft metadata must be true or false", path)
			}
		case "layout":
		// Older posts carry a book-layout hint; blog rendering is linear, so
		// accept but deliberately do not interpret this legacy field.
		case:
			return fields, fmt.tprintf("content %s has unknown metadata field %s", path, key)
		}
	}
	return fields, ""
}

@(private = "file")
metadata_value :: proc(source: string) -> (value, error: string) {
	value = strings.trim_space(source)
	if len(value) == 0 do return "", "value is empty"
	if value[0] == '"' || value[0] == '\'' {
		if len(value) < 2 || value[len(value) - 1] != value[0] {
			return "", "quoted value is not closed"
		}
		// Authored front matter only needs plain scalars and surrounding quotes;
		// Markdown remains the rich-text format for multiline values.
		return value[1:len(value) - 1], ""
	}
	return value, ""
}

@(private)
valid_slug :: proc(slug: string) -> bool {
	if len(slug) == 0 || slug[0] == '-' || slug[len(slug) - 1] == '-' do return false
	previous_was_hyphen := false
	for character in slug {
		is_hyphen := character == '-'
		if is_hyphen && previous_was_hyphen do return false
		if !is_hyphen &&
		   !(character >= 'a' && character <= 'z') &&
		   !(character >= '0' && character <= '9') {
			return false
		}
		previous_was_hyphen = is_hyphen
	}
	return true
}
