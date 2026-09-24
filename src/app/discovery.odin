package app

import content "../content"
import httpx "../httpx"
import http "../../vendor/tina/src/extensions/http/server"
import "core:fmt"
import "core:strings"
import "core:time"

Discovery_Renderer :: #type proc(writer: ^strings.Builder, ctx: ^Application_Context)

// discovery_event streams generated XML/text through the same bounded response
// path as HTML, so a feed that grows with the archive also handles backpressure.
discovery_event :: proc(
	event: http.Route_Event,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
	content_type: string,
	render: Discovery_Renderer,
) -> http.Route_Step {
	stream := cast(^Page_Stream_State)state
	switch _ in event {
	case http.Request_Start:
		ctx := cast(^Application_Context)route_context.application_context
		if ctx == nil do return http.close()
		httpx.document_begin(&stream.document, http.HTTP_STATUS_OK, content_type)
		render(&stream.document.body, ctx)
		set_security_headers(response)
		_ = http.header_set(response, "Cache-Control", "public, max-age=3600")
		return httpx.document_send(response, &stream.document)
	case http.Send_Ready:
		return httpx.document_send(response, &stream.document)
	case http.Peer_Closed, http.Server_Drain:
		httpx.document_destroy(&stream.document)
		return http.close()
	case http.Body_Chunk, http.Application_Reply, http.Application_Notification:
		return http.close()
	}
	return http.close()
}

feed :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	_ = request
	return discovery_event(event, response, route_context, state, "application/rss+xml; charset=utf-8", render_feed)
}

sitemap :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	_ = request
	return discovery_event(event, response, route_context, state, "application/xml; charset=utf-8", render_sitemap)
}

robots :: proc(
	event: http.Route_Event,
	request: ^http.Request,
	response: ^http.Response,
	route_context: http.Route_Context,
	state: rawptr,
) -> http.Route_Step {
	_ = request
	return discovery_event(event, response, route_context, state, "text/plain; charset=utf-8", render_robots)
}

rss_compatibility :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = request
	set_security_headers(response)
	_ = http.header_set(response, "Cache-Control", "public, max-age=3600")
	_ = http.header_set(response, "Location", "/feed.xml")
	return http.respond_text(response, http.HTTP_STATUS_MOVED_PERMANENTLY, "")
}

health :: proc(request: ^http.Request, response: ^http.Response) -> http.Route_Step {
	_ = request
	set_security_headers(response)
	_ = http.header_set(response, "Cache-Control", "no-store")
	return http.respond_text(response, http.HTTP_STATUS_OK, "ok\n")
}

@(private = "file")
render_feed :: proc(writer: ^strings.Builder, ctx: ^Application_Context) {
	strings.write_string(writer, `<?xml version="1.0" encoding="UTF-8"?>`)
	strings.write_string(writer, `<rss version="2.0"><channel><title>wlls.dev</title><description>Devon Wells</description><link>`)
	write_absolute_url(writer, "/")
	strings.write_string(writer, `</link><atom:link xmlns:atom="http://www.w3.org/2005/Atom" href="`)
	write_absolute_url(writer, "/feed.xml")
	strings.write_string(writer, `" rel="self" type="application/rss+xml"/>`)

	for post in content.published_posts(&ctx.content) {
		strings.write_string(writer, `<item><title>`)
		write_xml_text(writer, post.title)
		strings.write_string(writer, `</title><description>`)
		write_xml_text(writer, post.description)
		strings.write_string(writer, `</description><link>`)
		write_xml_text(writer, post.canonical)
		strings.write_string(writer, `</link><guid isPermaLink="true">`)
		write_xml_text(writer, post.canonical)
		strings.write_string(writer, `</guid><pubDate>`)
		write_rss_date(writer, post.date)
		strings.write_string(writer, `</pubDate></item>`)
	}
	strings.write_string(writer, `</channel></rss>`)
}

@(private = "file")
render_sitemap :: proc(writer: ^strings.Builder, ctx: ^Application_Context) {
	strings.write_string(writer, `<?xml version="1.0" encoding="UTF-8"?>`)
	strings.write_string(writer, `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`)
	static_paths := [?]string{ "/", "/blog", "/about" }
	for path in static_paths {
		write_sitemap_url(writer, path, "")
	}
	for post in content.published_posts(&ctx.content) {
		write_sitemap_url(writer, post.canonical, post.date, absolute = true)
	}
	strings.write_string(writer, `</urlset>`)
}

@(private = "file")
render_robots :: proc(writer: ^strings.Builder, ctx: ^Application_Context) {
	_ = ctx
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

@(private = "file")
write_rss_date :: proc(writer: ^strings.Builder, date: string) {
	buffer: [20]byte
	copy(buffer[:10], transmute([]byte)date)
	copy(buffer[10:], "T00:00:00Z")
	published, _ := time.iso8601_to_time_utc(string(buffer[:]))
	datetime, _ := time.time_to_datetime(published)
	weekday := [?]string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
	month := [?]string{"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
	fmt.sbprintf(
		writer,
		"%s, %02d %s %04d 00:00:00 GMT",
		weekday[int(time.weekday(published))],
		int(datetime.day),
		month[int(datetime.month)-1],
		int(datetime.year),
	)
}
