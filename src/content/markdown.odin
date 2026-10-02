package content

import "base:runtime"
import "core:c"
import "core:strings"

foreign import cmark_gfm "system:cmark-gfm"
foreign import cmark_gfm_extensions "system:cmark-gfm-extensions"
foreign import libc "system:c"

@(default_calling_convention = "c")
foreign cmark_gfm {
	cmark_parser_new :: proc(options: c.int) -> ^Cmark_Parser ---
	cmark_parser_free :: proc(parser: ^Cmark_Parser) ---
	cmark_parser_feed :: proc(parser: ^Cmark_Parser, source: cstring, size: c.size_t) ---
	cmark_parser_finish :: proc(parser: ^Cmark_Parser) -> ^Cmark_Node ---
	cmark_parser_attach_syntax_extension :: proc(parser: ^Cmark_Parser, extension: ^Cmark_Extension) -> c.int ---
	cmark_parser_get_syntax_extensions :: proc(parser: ^Cmark_Parser) -> ^Cmark_Extension_List ---
	cmark_find_syntax_extension :: proc(name: cstring) -> ^Cmark_Extension ---
	cmark_render_html :: proc(root: ^Cmark_Node, options: c.int, extensions: ^Cmark_Extension_List) -> cstring ---
	cmark_node_free :: proc(root: ^Cmark_Node) ---
}

@(default_calling_convention = "c")
foreign cmark_gfm_extensions {
	cmark_gfm_core_extensions_ensure_registered :: proc() ---
}

@(default_calling_convention = "c")
foreign libc {
	free :: proc(pointer: rawptr) ---
}

// Cmark owns these objects. Odin only needs opaque pointer types at this
// boundary, keeping the parser's internal node structures in the C library.
Cmark_Parser :: struct {}
Cmark_Node :: struct {}
Cmark_Extension :: struct {}
Cmark_Extension_List :: struct {}

Markdown_HTML :: distinct string

Markdown_Error :: enum {
	None,
	Parser_Allocation,
	Output_Allocation,
	Missing_Extension,
	Missing_Image,
	Invalid_Image_Option,
	Extension_Attachment,
	Parse_Failed,
	Render_Failed,
	Unsupported_Footnote,
}

// Cmark's extension registry is process-wide. Register it during Odin package
// initialization, before Tina starts dispatching requests or tests run in
// parallel; parser instances are then independent per render operation.
@(init)
register_gfm_extensions :: proc "contextless" () {
	cmark_gfm_core_extensions_ensure_registered()
}

// render_markdown uses the upstream CommonMark/GFM parser so authored content
// is handled consistently without growing a project-specific Markdown parser.
// Cmark's safe default replaces raw HTML and unsafe URL schemes in its output.
// On an image error, detail names the offending URL or option.
@(require_results)
render_markdown :: proc(
	source: string,
	images := Image_Sizes{},
) -> (
	html: Markdown_HTML,
	error: Markdown_Error,
	detail: string,
) {
	parser := cmark_parser_new(c.int(CMARK_OPTIONS))
	if parser == nil do return html, .Parser_Allocation, ""
	defer cmark_parser_free(parser)

	for name in GFM_EXTENSIONS {
		extension := cmark_find_syntax_extension(strings.unsafe_string_to_cstring(name))
		if extension == nil do return html, .Missing_Extension, ""
		if cmark_parser_attach_syntax_extension(parser, extension) == 0 {
			return html, .Extension_Attachment, ""
		}
	}

	// Cmark accepts a pointer plus an explicit byte count, so UTF-8 Markdown does
	// not need a temporary NUL-terminated copy at the FFI boundary.
	cmark_parser_feed(parser, strings.unsafe_string_to_cstring(source), c.size_t(len(source)))
	root := cmark_parser_finish(parser)
	if root == nil do return html, .Parse_Failed, ""
	defer cmark_node_free(root)

	rendered := cmark_render_html(root, 0, cmark_parser_get_syntax_extensions(parser))
	if rendered == nil do return html, .Render_Failed, ""
	defer free(rawptr(rendered))

	// Cmark owns its NUL-terminated return buffer. Copy it out through the
	// post-render passes before the deferred free so the repository can retain it.
	plated, plate_error, plate_detail := transform_plates(string(rendered), images)
	switch plate_error {
	case .None:
	case .Allocation:
		return html, .Output_Allocation, ""
	// The detail borrows cmark's buffer, which is freed on return.
	case .Missing_Image:
		return html, .Missing_Image, strings.clone(plate_detail, context.temp_allocator)
	case .Unknown_Option:
		return html, .Invalid_Image_Option, strings.clone(plate_detail, context.temp_allocator)
	}
	defer delete(plated)
	anchored, anchor_error := transform_headings(plated)
	if anchor_error != nil do return html, .Output_Allocation, ""
	defer delete(anchored)
	alerted, alert_error := transform_alerts(anchored)
	if alert_error != nil do return html, .Output_Allocation, ""
	defer delete(alerted)
	owned_html, footnote_error, footnote_detail := transform_footnotes(alerted)
	switch footnote_error {
	case .None:
	case .Allocation:
		return html, .Output_Allocation, ""
	// The detail borrows the alerted buffer, which is freed on return.
	case .Block_Content:
		return html, .Unsupported_Footnote, strings.clone(footnote_detail, context.temp_allocator)
	}
	return Markdown_HTML(owned_html), .None, ""
}

// transform_alerts rewrites GitHub-style alerts (`> [!NOTE]`) into callout
// asides. cmark-gfm has no alert extension, so it renders them as blockquotes
// whose first paragraph starts with the literal marker. Raw HTML is escaped
// upstream, so every literal <blockquote> tag here came from cmark itself.
@(private)
transform_alerts :: proc(
	source: string,
	allocator := context.allocator,
) -> (
	output: string,
	error: runtime.Allocator_Error,
) {
	OPEN :: "<blockquote>"
	CLOSE :: "</blockquote>"
	MARKER :: "\n<p>[!"

	builder := strings.builder_make(0, len(source) + 128, allocator) or_return
	// Each open blockquote records whether it became an aside, so nested
	// quotes close with the matching tag.
	is_alert := make([dynamic]bool, 0, 8, context.temp_allocator)

	rest := source
	for {
		open := strings.index(rest, OPEN)
		close := strings.index(rest, CLOSE)
		if open < 0 && close < 0 do break
		if close < 0 || (open >= 0 && open < close) {
			strings.write_string(&builder, rest[:open])
			rest = rest[open + len(OPEN):]
			kind, label, marker_length := alert_marker(rest, MARKER)
			if marker_length == 0 {
				strings.write_string(&builder, OPEN)
				append(&is_alert, false)
				continue
			}
			strings.write_string(&builder, `<aside class="callout" data-kind="`)
			strings.write_string(&builder, kind)
			strings.write_string(&builder, `"><p class="callout-label">`)
			strings.write_string(&builder, label)
			strings.write_string(&builder, "</p>\n<p>")
			rest = rest[marker_length:]
			// The marker usually ends its own line; drop the soft break, or the
			// whole paragraph when the marker stood alone.
			if strings.has_prefix(rest, "\n") {
				rest = rest[1:]
			} else if strings.has_prefix(rest, "</p>\n") {
				strings.pop_byte(&builder)
				strings.pop_byte(&builder)
				strings.pop_byte(&builder)
				rest = rest[len("</p>\n"):]
			}
			append(&is_alert, true)
			continue
		}
		strings.write_string(&builder, rest[:close])
		rest = rest[close + len(CLOSE):]
		was_alert := len(is_alert) > 0 && pop(&is_alert)
		strings.write_string(&builder, was_alert ? "</aside>" : CLOSE)
	}
	strings.write_string(&builder, rest)
	return strings.to_string(builder), nil
}

// alert_marker recognizes `\n<p>[!KIND]` at the start of a blockquote body and
// returns the callout kind, its display label, and the marker's byte length.
@(private = "file")
alert_marker :: proc(body, prefix: string) -> (kind, label: string, length: int) {
	if !strings.has_prefix(body, prefix) do return
	after := body[len(prefix):]
	end := strings.index_byte(after, ']')
	if end <= 0 do return
	switch after[:end] {
	case "NOTE":
		kind, label = "note", "Note"
	case "TIP":
		kind, label = "tip", "Tip"
	case "IMPORTANT":
		kind, label = "important", "Important"
	case "WARNING":
		kind, label = "warning", "Warning"
	case "CAUTION":
		kind, label = "caution", "Caution"
	case:
		return "", "", 0
	}
	return kind, label, len(prefix) + end + 1
}

@(private = "file")
CMARK_OPTIONS :: 1 << 13 // CMARK_OPT_FOOTNOTES

@(private = "file")
GFM_EXTENSIONS :: []string{"table", "strikethrough", "autolink", "tagfilter", "tasklist"}
