package content

import embedded "../../content"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:time"

// Odin embeds the authored files into the executable at compile time. The
// repository parses and renders them once during startup, then handlers only
// borrow immutable, in-memory values.
EMBEDDED_ABOUT :: embedded.About
EMBEDDED_RESUME :: embedded.Resume
EMBEDDED_RESUME_PDF :: embedded.Resume_PDF
EMBEDDED_RESUME_PDF_SOURCE :: embedded.Resume_PDF_Source

Post :: struct {
	slug:        string,
	url:         string,
	canonical:   string,
	title:       string,
	description: string,
	topic:       string,
	date:        string, // as authored, YYYY-MM-DD
	published:   time.Time, // date at midnight UTC
	html:        Markdown_HTML,
}

Page :: struct {
	title:       string,
	description: string,
	canonical:   string,
	html:        Markdown_HTML,
}

Repository :: struct {
	posts:   [dynamic]Post,
	by_slug: map[string]int,
	about:   Page,
	resume:  Resume,
}

// published_posts borrows the sorted immutable slice for one render pass.
published_posts :: proc(repository: ^Repository) -> []Post {
	return repository.posts[:]
}

find_post :: proc(repository: ^Repository, slug: string) -> (^Post, bool) {
	index, found := repository.by_slug[slug]
	if !found do return nil, false
	return &repository.posts[index], true
}

about_page :: proc(repository: ^Repository) -> ^Page {
	return &repository.about
}

resume_page :: proc(repository: ^Repository) -> ^Resume {
	return &repository.resume
}

// load validates every published post before startup succeeds. A bad filename,
// date, required field, or duplicate slug becomes an immediate startup error
// rather than an intermittent request-time failure. Everything it allocates
// comes from context.allocator: callers pass a startup arena and free it once.
@(require_results)
load :: proc(
	base_url: string,
	images := Image_Sizes{},
) -> (
	repository: Repository,
	error: string,
) {
	embedded_posts := embedded.load_posts()
	if len(embedded_posts) == 0 do return repository, "no Markdown posts were embedded"

	for source in embedded_posts {
		post, is_draft, parse_error := parse_post(
			source.name,
			string(source.data),
			base_url,
			images,
		)
		if parse_error != "" do return repository, parse_error
		if !is_draft do append(&repository.posts, post)
	}
	if len(repository.posts) == 0 do return repository, "no published Markdown posts were found"

	slice.sort_by(repository.posts[:], is_newer)
	for post, index in repository.posts {
		if _, exists := repository.by_slug[post.slug]; exists {
			return repository, fmt.tprintf("duplicate post slug: %s", post.slug)
		}
		repository.by_slug[post.slug] = index
	}

	repository.about, error = parse_page(
		"pages/about.md",
		string(EMBEDDED_ABOUT),
		base_url,
		images,
	)
	if error != "" do return repository, error

	repository.resume, error = parse_resume(
		"pages/resume.md",
		string(EMBEDDED_RESUME),
		base_url,
		&repository,
		images,
	)
	return repository, error
}

@(private)
parse_post :: proc(
	path, source, base_url: string,
	images := Image_Sizes{},
) -> (
	post: Post,
	draft: bool,
	error: string,
) {
	metadata, body, split_error := split_front_matter(path, source)
	if split_error != "" do return post, false, split_error
	fields, parse_error := parse_metadata(path, metadata)
	if parse_error != "" do return post, false, parse_error

	filename := path
	if slash := strings.last_index(filename, "/"); slash >= 0 {
		filename = filename[slash + 1:]
	}
	if !strings.has_suffix(filename, ".md") {
		return post, false, fmt.tprintf("post %s must have a .md extension", path)
	}
	slug := filename[:len(filename) - 3]
	if !valid_slug(slug) {
		return post, false, fmt.tprintf("post %s must use a lowercase kebab-case filename", path)
	}
	if fields.title == "" || fields.description == "" || fields.date == "" {
		return post, false, fmt.tprintf("post %s requires title, description, and date", path)
	}
	if len(fields.date) != 10 {
		return post, false, fmt.tprintf("post %s has invalid date %s", path, fields.date)
	}
	date_buffer: [20]u8
	copy(date_buffer[:10], transmute([]u8)fields.date)
	copy(date_buffer[10:], "T00:00:00Z")
	date_text := string(date_buffer[:20])
	published, consumed := time.iso8601_to_time_utc(date_text)
	if consumed != len(date_text) {
		return post, false, fmt.tprintf("post %s has invalid date %s", path, fields.date)
	}
	if fields.draft {
		return Post{slug = slug}, true, ""
	}

	html, markdown_error, detail := render_markdown(body, images)
	if markdown_error != .None {
		return post, false, markdown_error_message(path, markdown_error, detail)
	}
	return Post {
			slug = slug,
			url = fmt.aprintf("/blog/%s", slug),
			canonical = fmt.aprintf("%s/blog/%s", base_url, slug),
			title = fields.title,
			description = fields.description,
			topic = fields.topic,
			date = fields.date,
			published = published,
			html = html,
		},
		false,
		""
}

@(private = "file")
parse_page :: proc(
	path, source, base_url: string,
	images: Image_Sizes,
) -> (
	page: Page,
	error: string,
) {
	metadata, body, split_error := split_front_matter(path, source)
	if split_error != "" do return page, split_error
	fields, parse_error := parse_metadata(path, metadata)
	if parse_error != "" do return page, parse_error
	if fields.title == "" || fields.description == "" {
		return page, fmt.tprintf("page %s requires title and description", path)
	}
	html, markdown_error, detail := render_markdown(body, images)
	if markdown_error != .None do return page, markdown_error_message(path, markdown_error, detail)
	return Page {
			title = fields.title,
			description = fields.description,
			canonical = fmt.aprintf("%s/about", base_url),
			html = html,
		},
		""
}

@(private)
markdown_error_message :: proc(path: string, error: Markdown_Error, detail: string) -> string {
	#partial switch error {
	case .Missing_Image:
		return fmt.tprintf("%s references an image that is not embedded: %s", path, detail)
	case .Invalid_Image_Option:
		return fmt.tprintf("%s uses an unknown image option: %s", path, detail)
	case .Unsupported_Footnote:
		return fmt.tprintf(
			"%s: footnote [^%s] has lists, code, or quotes; a sidenote takes paragraphs only",
			path,
			detail,
		)
	}
	return fmt.tprintf("%s could not be rendered as Markdown", path)
}

// is_newer orders posts newest first; the slug breaks ties so the order never
// depends on how the embedded directory happens to be enumerated.
@(private = "file")
is_newer :: proc(candidate, existing: Post) -> bool {
	if candidate.date != existing.date do return candidate.date > existing.date
	return candidate.slug < existing.slug
}
