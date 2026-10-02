package app

import http "../../vendor/tina/src/extensions/http/server"
import "core:crypto"
import "core:fmt"
import "core:strconv"
import "core:strings"

// A visitor is a random id kept in a cookie: the only identity on the site.
// It names them in `who` (and later in `msg`) as an adjective-animal pair,
// so no account, name, or stored profile is ever needed.
Visitor :: distinct u64

@(private = "file")
VISITOR_COOKIE :: "wlls_visitor"

// visitor_from_request reads the visitor cookie, if the browser sent one.
visitor_from_request :: proc(request: ^http.Request) -> (visitor: Visitor, found: bool) {
	id, ok := strconv.parse_u64_of_base(cookie_value(request, VISITOR_COOKIE), 16)
	if !ok || id == 0 do return 0, false
	return Visitor(id), true
}

// cookie_value returns the named cookie's value, or "" if it wasn't sent.
cookie_value :: proc(request: ^http.Request, name: string) -> string {
	rest := string(http.header(request, "Cookie"))
	for pair in strings.split_iterator(&rest, ";") {
		key, _, value := strings.partition(strings.trim_space(pair), "=")
		if key == name do return value
	}
	return ""
}

visitor_new :: proc() -> Visitor {
	for {
		id: u64
		crypto.rand_bytes(([^]u8)(&id)[:size_of(id)])
		if id != 0 do return Visitor(id)
	}
}

// visitor_cookie is the Set-Cookie value that keeps a visitor's name for a
// year. JavaScript never needs it, and production only sends it over HTTPS.
visitor_cookie :: proc(visitor: Visitor, buffer: []u8) -> string {
	SECURE :: "" when WLLS_DEV else "; Secure"
	return fmt.bprintf(
		buffer,
		"%s=%016x; Path=/; Max-Age=31536000; SameSite=Lax; HttpOnly%s",
		VISITOR_COOKIE,
		u64(visitor),
		SECURE,
	)
}

// visitor_name splits the id into an adjective and an animal: 64 × 64 names,
// picked by its low bits. Both halves are static strings.
visitor_name :: proc(visitor: Visitor) -> (adjective, animal: string) {
	return ADJECTIVES[u64(visitor) % len(ADJECTIVES)], ANIMALS[(u64(visitor) >> 6) % len(ANIMALS)]
}

@(private = "file")
ADJECTIVES := [64]string {
	"quiet",
	"amber",
	"calm",
	"dusty",
	"early",
	"fern",
	"gentle",
	"hazy",
	"idle",
	"jade",
	"kind",
	"late",
	"mossy",
	"misty",
	"noble",
	"olive",
	"pale",
	"quick",
	"rusty",
	"sandy",
	"shy",
	"tidy",
	"umber",
	"velvet",
	"wild",
	"young",
	"brisk",
	"cedar",
	"dawn",
	"ember",
	"foggy",
	"glad",
	"honey",
	"inky",
	"jolly",
	"keen",
	"lucky",
	"mellow",
	"nimble",
	"oaken",
	"plucky",
	"rainy",
	"sleepy",
	"sunny",
	"tawny",
	"upland",
	"vivid",
	"windy",
	"bright",
	"clever",
	"dapper",
	"eager",
	"frosty",
	"golden",
	"humble",
	"ivory",
	"lofty",
	"merry",
	"nutmeg",
	"patient",
	"rosy",
	"silver",
	"tender",
	"wandering",
}

@(private = "file")
ANIMALS := [64]string {
	"heron",
	"finch",
	"otter",
	"wren",
	"badger",
	"moth",
	"vole",
	"lark",
	"newt",
	"hare",
	"owl",
	"plover",
	"robin",
	"stoat",
	"toad",
	"swift",
	"marten",
	"kestrel",
	"dormouse",
	"beetle",
	"linnet",
	"curlew",
	"pika",
	"shrew",
	"sparrow",
	"thrush",
	"egret",
	"gecko",
	"ibis",
	"jay",
	"kite",
	"lemur",
	"magpie",
	"nightjar",
	"oriole",
	"puffin",
	"quail",
	"raven",
	"snipe",
	"tern",
	"urchin",
	"vireo",
	"warbler",
	"yak",
	"bittern",
	"crane",
	"dunlin",
	"eider",
	"ferret",
	"grebe",
	"hedgehog",
	"koala",
	"loris",
	"mole",
	"nuthatch",
	"osprey",
	"pheasant",
	"redstart",
	"salamander",
	"tanager",
	"weasel",
	"wombat",
	"zebu",
	"fox",
}
