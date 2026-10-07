package embedded_content

import "base:runtime"

// Keep Markdown adjacent to its compile-time embedding declaration so adding
// a post is a content-only change, not an Odin manifest edit. The builtin
// returns a runtime slice, so expose it through a small loading procedure.
load_posts :: proc() -> []runtime.Load_Directory_File {
	return #load_directory("posts")
}

About :: #load("pages/about.md")
Resume :: #load("pages/resume.md")

// `just resume-pdf` prints the resume page to a PDF and records the SHA-256
// of the resume.md it printed, so a test can tell when the PDF is stale.
Resume_PDF :: #load("pages/resume.pdf")
Resume_PDF_Source :: #load("pages/resume.pdf.sha256", string)
