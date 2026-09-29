package assets

import "base:runtime"
import "core:crypto/sha2"
import "core:fmt"
import "core:slice"
import "core:strings"

// Odin embeds all browser resources in the binary. A change to any file
// changes the URL prefix, making immutable caching safe without a manifest
// generator or a separate frontend build.
Embedded_Asset :: struct {
	path:         string,
	bytes:        []byte,
	content_type: string,
	etag:         string,
}

Bundle :: struct {
	files:   [dynamic]Embedded_Asset,
	by_path: map[string]int,
	finger:  [16]byte,
}

// Odin's #load_directory reads one directory level. Each group below keeps
// newly authored files discoverable without maintaining a per-file manifest.
load_static_files :: proc() -> []runtime.Load_Directory_File {
	return #load_directory("static")
}

load_css :: proc() -> []runtime.Load_Directory_File {return #load_directory("static/css")}
load_fonts :: proc() -> []runtime.Load_Directory_File {return #load_directory("static/fonts")}
load_js :: proc() -> []runtime.Load_Directory_File {return #load_directory("static/js")}
load_avatars :: proc() -> []runtime.Load_Directory_File {return #load_directory(
		"static/images/avatars",
	)}

Asset_Group :: struct {
	prefix: string,
	files:  []runtime.Load_Directory_File,
}

// load indexes and fingerprints every embedded file. Asset bytes are borrowed
// from the executable; paths, ETags, and the index come from context.allocator,
// which callers point at a startup arena and free once.
@(require_results)
load :: proc() -> (bundle: Bundle, error: string) {
	groups := [?]Asset_Group {
		{prefix = "", files = load_static_files()},
		{prefix = "css/", files = load_css()},
		{prefix = "fonts/", files = load_fonts()},
		{prefix = "js/", files = load_js()},
		{prefix = "images/avatars/", files = load_avatars()},
	}
	for group in groups {
		for file in group.files {
			path := fmt.aprintf("%s%s", group.prefix, file.name)
			append(
				&bundle.files,
				Embedded_Asset{path = path, bytes = file.data, content_type = media_type(path)},
			)
		}
	}
	if len(bundle.files) == 0 do return bundle, "no usable static assets were embedded"

	// Stable ordering makes the digest independent of filesystem enumeration.
	slice.sort_by(bundle.files[:], proc(a, b: Embedded_Asset) -> bool {return a.path < b.path})
	for asset, index in bundle.files {
		if _, duplicate := bundle.by_path[asset.path]; duplicate {
			return bundle, fmt.tprintf("duplicate embedded asset path: %s", asset.path)
		}
		bundle.by_path[asset.path] = index
	}

	// The path separator prevents ambiguous concatenations of neighboring files.
	hash: sha2.Context_256
	sha2.init_256(&hash)
	separator := [1]byte{0}
	for asset in bundle.files {
		sha2.update(&hash, transmute([]byte)asset.path)
		sha2.update(&hash, separator[:])
		sha2.update(&hash, asset.bytes)
	}
	digest: [sha2.DIGEST_SIZE_256]byte
	sha2.final(&hash, digest[:])
	digits := HEX_DIGITS
	for value, index in digest[:8] {
		bundle.finger[index * 2 + 0] = digits[int(value >> 4)]
		bundle.finger[index * 2 + 1] = digits[int(value & 0x0f)]
	}
	for &asset in bundle.files {
		asset.etag = fmt.aprintf(`"%s-%s"`, version(&bundle), asset.path)
	}
	return bundle, ""
}

version :: proc(bundle: ^Bundle) -> string {
	return transmute(string)bundle.finger[:]
}

// url is the fingerprinted, immutable-cacheable URL for an embedded path,
// for example /static/<version>/css/site.css.
url :: proc(bundle: ^Bundle, path: string) -> string {
	return fmt.aprintf("/static/%s/%s", version(bundle), path)
}

find :: proc(bundle: ^Bundle, path: string) -> (^Embedded_Asset, bool) {
	index, found := bundle.by_path[path]
	if !found do return nil, false
	return &bundle.files[index], true
}

@(private = "file")
HEX_DIGITS :: "0123456789abcdef"

@(private = "file")
media_type :: proc(path: string) -> string {
	switch {
	case strings.has_suffix(path, ".css"):
		return "text/css; charset=utf-8"
	case strings.has_suffix(path, ".js"):
		return "text/javascript; charset=utf-8"
	case strings.has_suffix(path, ".svg"):
		return "image/svg+xml"
	case strings.has_suffix(path, ".woff2"):
		return "font/woff2"
	case strings.has_suffix(path, ".webp"):
		return "image/webp"
	case strings.has_suffix(path, ".gif"):
		return "image/gif"
	case strings.has_suffix(path, ".txt"), strings.has_suffix(path, ".md"):
		return "text/plain; charset=utf-8"
	}
	return "application/octet-stream"
}
