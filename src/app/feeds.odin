package app

import content "../content"
import "core:fmt"
import "core:strings"
import "core:time"

// Discovery documents (RSS, sitemap, robots.txt) are written by hand rather
// than with Tempo: they are small, fixed XML/text shapes. prerender renders
// them once at startup alongside the HTML pages.

@(private)
write_feed :: proc(writer: ^strings.Builder, posts: []content.Post) {
	strings.write_string(writer, `<?xml version="1.0" encoding="UTF-8"?>`)
	strings.write_string(
		writer,
		`<rss version="2.0"><channel><title>wlls.dev</title><description>Devon Wells</description><link>`,
	)
	write_absolute_url(writer, "/")
	strings.write_string(
		writer,
		`</link><atom:link xmlns:atom="http://www.w3.org/2005/Atom" href="`,
	)
	write_absolute_url(writer, "/feed.xml")
	strings.write_string(writer, `" rel="self" type="application/rss+xml"/>`)

	for post in posts {
		strings.write_string(writer, `<item><title>`)
		write_xml_text(writer, post.title)
		strings.write_string(writer, `</title><description>`)
		write_xml_text(writer, post.description)
		strings.write_string(writer, `</description><link>`)
		write_xml_text(writer, post.canonical)
		strings.write_string(writer, `</link><guid isPermaLink="true">`)
		write_xml_text(writer, post.canonical)
		strings.write_string(writer, `</guid><pubDate>`)
		write_rss_date(writer, post.published)
		strings.write_string(writer, `</pubDate></item>`)
	}
	strings.write_string(writer, `</channel></rss>`)
}

@(private)
write_sitemap :: proc(writer: ^strings.Builder, posts: []content.Post) {
	strings.write_string(writer, `<?xml version="1.0" encoding="UTF-8"?>`)
	strings.write_string(writer, `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`)
	static_paths := [?]string{"/", "/blog", "/about"}
	for path in static_paths {
		write_sitemap_url(writer, path, "")
	}
	for post in posts {
		write_sitemap_url(writer, post.canonical, post.date, absolute = true)
	}
	strings.write_string(writer, `</urlset>`)
}

@(private)
write_robots :: proc(writer: ^strings.Builder) {
	strings.write_string(writer, "User-agent: *\nAllow: /\nSitemap: ")
	write_absolute_url(writer, "/sitemap.xml")
	strings.write_byte(writer, '\n')
}

@(private = "file")
write_sitemap_url :: proc(writer: ^strings.Builder, path, date: string, absolute := false) {
	strings.write_string(writer, `<url><loc>`)
	if absolute {
		write_xml_text(writer, path)
	} else {
		write_absolute_url(writer, path)
	}
	strings.write_string(writer, `</loc>`)
	if date != "" {
		strings.write_string(writer, `<lastmod>`)
		strings.write_string(writer, date)
		strings.write_string(writer, `</lastmod>`)
	}
	strings.write_string(writer, `</url>`)
}

@(private = "file")
write_absolute_url :: proc(writer: ^strings.Builder, path: string) {
	write_xml_text(writer, BASE_URL)
	write_xml_text(writer, path)
}

@(private = "file")
write_xml_text :: proc(writer: ^strings.Builder, value: string) {
	for character in value {
		switch character {
		case '&':
			strings.write_string(writer, "&amp;")
		case '<':
			strings.write_string(writer, "&lt;")
		case '>':
			strings.write_string(writer, "&gt;")
		case '"':
			strings.write_string(writer, "&quot;")
		case '\'':
			strings.write_string(writer, "&apos;")
		case:
			strings.write_rune(writer, character)
		}
	}
}

// write_rss_date formats RFC 822 dates, as RSS 2.0 requires.
@(private = "file")
write_rss_date :: proc(writer: ^strings.Builder, published: time.Time) {
	weekdays := [?]string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
	months := [?]string {
		"Jan",
		"Feb",
		"Mar",
		"Apr",
		"May",
		"Jun",
		"Jul",
		"Aug",
		"Sep",
		"Oct",
		"Nov",
		"Dec",
	}
	year, month, day := time.date(published)
	fmt.sbprintf(
		writer,
		"%s, %02d %s %04d 00:00:00 GMT",
		weekdays[int(time.weekday(published))],
		day,
		months[int(month) - 1],
		year,
	)
}
