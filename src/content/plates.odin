package content

import "core:strings"

// Image_Sizes lets the application report each local image's intrinsic size
// without the content package depending on how assets are stored. A nil
// lookup skips sizing and existence checks (useful for isolated tests).
Image_Sizes :: struct {
	data:   rawptr,
	lookup: proc(data: rawptr, url: string) -> (width, height: int, found: bool),
}

@(private)
Plate_Error :: enum {
	None,
	Allocation,
	Missing_Image,
	Unknown_Option,
}

// Plate options are authored after a bar in the image title:
// ![alt](/images/x.webp "Caption | wide raw")
@(private = "file")
Plate :: struct {
	src, alt, caption: string,
	size:              string, // "", "wide", or "full"
	treatment:         string, // "", "color", or "raw"
	pixel:             bool,
}

// transform_plates turns paragraphs that contain only images into figures:
// one image becomes a framed plate with an optional caption, and several
// become a gallery of plates. Inline images inside prose are left alone.
// cmark escapes attribute values, so they are copied through verbatim.
@(private)
transform_plates :: proc(
	source: string,
	images: Image_Sizes,
	allocator := context.allocator,
) -> (
	output: string,
	error: Plate_Error,
	detail: string,
) {
	OPEN :: "<p><img "

	builder, allocation_error := strings.builder_make(0, len(source) + 256, allocator)
	if allocation_error != nil do return "", .Allocation, ""
	defer if error != .None do strings.builder_destroy(&builder)

	rest := source
	for {
		start := strings.index(rest, OPEN)
		if start < 0 do break
		strings.write_string(&builder, rest[:start])
		paragraph := rest[start + len("<p>"):]
		end := strings.index(paragraph, "</p>")
		if end < 0 {
			strings.write_string(&builder, "<p>")
			rest = paragraph
			continue
		}
		plates, is_plate_run, option := parse_image_run(paragraph[:end])
		if option != "" do return "", .Unknown_Option, option
		if !is_plate_run {
			strings.write_string(&builder, "<p>")
			rest = paragraph
			continue
		}

		if len(plates) > 1 do strings.write_string(&builder, `<div class="plates">`)
		for plate in plates {
			width, height := 0, 0
			if images.lookup != nil && is_local_url(plate.src) {
				found: bool
				width, height, found = images.lookup(images.data, plate.src)
				if !found do return "", .Missing_Image, plate.src
			}
			write_plate(&builder, plate, width, height)
		}
		if len(plates) > 1 do strings.write_string(&builder, "</div>")
		rest = paragraph[end + len("</p>"):]
	}
	strings.write_string(&builder, rest)
	return strings.to_string(builder), .None, ""
}

// parse_image_run accepts a paragraph body made only of <img /> tags joined by
// whitespace or soft breaks. It reports the first unknown option, if any.
@(private = "file")
parse_image_run :: proc(
	body: string,
) -> (
	plates: [dynamic]Plate,
	ok: bool,
	unknown_option: string,
) {
	plates = make([dynamic]Plate, context.temp_allocator)
	rest := body
	for {
		rest = strings.trim_left(rest, " \n")
		if rest == "" do break
		if !strings.has_prefix(rest, "<img ") do return plates, false, ""
		close := strings.index(rest, " />")
		if close < 0 do return plates, false, ""
		tag := rest[:close]
		rest = rest[close + len(" />"):]

		plate := Plate {
			src     = attribute(tag, "src"),
			alt     = attribute(tag, "alt"),
			caption = attribute(tag, "title"),
		}
		if bar := strings.last_index_byte(plate.caption, '|'); bar >= 0 {
			options := plate.caption[bar + 1:]
			plate.caption = strings.trim_space(plate.caption[:bar])
			for option in strings.fields_iterator(&options) {
				switch option {
				case "wide", "full":
					plate.size = option
				case "color", "raw":
					plate.treatment = option
				case "pixel":
					plate.pixel = true
				case:
					return plates, false, option
				}
			}
		}
		append(&plates, plate)
	}
	return plates, len(plates) > 0, ""
}

@(private = "file")
write_plate :: proc(builder: ^strings.Builder, plate: Plate, width, height: int) {
	strings.write_string(builder, `<figure class="plate"`)
	if plate.size != "" {
		strings.write_string(builder, ` data-size="`)
		strings.write_string(builder, plate.size)
		strings.write_byte(builder, '"')
	}
	if plate.treatment != "" {
		strings.write_string(builder, ` data-treatment="`)
		strings.write_string(builder, plate.treatment)
		strings.write_byte(builder, '"')
	}
	if plate.pixel do strings.write_string(builder, ` data-pixel`)
	strings.write_string(builder, `><img src="`)
	strings.write_string(builder, plate.src)
	strings.write_string(builder, `" alt="`)
	strings.write_string(builder, plate.alt)
	strings.write_string(builder, `" loading="lazy" decoding="async"`)
	if width > 0 && height > 0 {
		strings.write_string(builder, ` width="`)
		strings.write_int(builder, width)
		strings.write_string(builder, `" height="`)
		strings.write_int(builder, height)
		strings.write_byte(builder, '"')
	}
	strings.write_string(builder, " />")
	if plate.caption != "" {
		strings.write_string(builder, "<figcaption>")
		strings.write_string(builder, plate.caption)
		strings.write_string(builder, "</figcaption>")
	}
	strings.write_string(builder, "</figure>\n")
}

// attribute reads a double-quoted attribute from a cmark-rendered tag.
@(private = "file")
attribute :: proc(tag, name: string) -> string {
	key := strings.concatenate({" ", name, `="`}, context.temp_allocator)
	start := strings.index(tag, key)
	if start < 0 do return ""
	value := tag[start + len(key):]
	end := strings.index_byte(value, '"')
	if end < 0 do return ""
	return value[:end]
}

@(private = "file")
is_local_url :: proc(url: string) -> bool {
	return strings.has_prefix(url, "/") && !strings.has_prefix(url, "//")
}
