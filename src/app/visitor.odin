package app

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"
import "core:crypto"
import "core:fmt"
import "core:strconv"
import "core:strings"

// A visitor is a random id kept in a cookie: the only identity on the site.
// It names them in `who`, #lobby, and terminal signing as an adjective-animal
// pair (or a nick), so no account or stored profile is ever needed.
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

// Caller is who sent a command: their visitor id, their network address as
// Caddy reports it (empty without Caddy, as in development), and when.
Caller :: struct {
	visitor: Visitor,
	client:  string,
	now:     u64, // monotonic ns
	admin:   bool, // signed in with sudo (the terminal checks)
	session: int, // the sudo session, when admin
}

caller_of :: proc(request: ^http.Request) -> Caller {
	visitor, _ := visitor_from_request(request)
	return Caller {
		visitor = visitor,
		client = string(http.header(request, "X-Client-IP")),
		now = u64(tina.ctx_monotonic_time_ns()),
	}
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

// ─── Names ──────────────────────────────────────────────────────────────────
//
// A visitor shows as their nick if they set one with `nick`, else as their
// adjective-animal handle. Nicks live in memory and reset on deploy. Name is
// a small fixed buffer, so names can be kept in shared tables and rendered
// without allocating.

NAME_MAX :: 24 // bytes; nicks are at most NICK_MAX ASCII characters
NICK_MIN :: 2
NICK_MAX :: 20
@(private = "file")
NICKS_MAX :: 256

Name :: struct {
	bytes: [NAME_MAX]u8,
	size:  u8,
}

name_string :: proc(name: ^Name) -> string {
	return string(name.bytes[:name.size])
}

name_of :: proc(text: string) -> (name: Name) {
	name.size = u8(copy(name.bytes[:], text))
	return
}

Nicks :: struct {
	entries: [NICKS_MAX]Nick,
	count:   int,
	next:    int, // when full, the oldest nick is replaced
}

@(private = "file")
Nick :: struct {
	visitor: Visitor,
	name:    Name,
}

// display_name is how a visitor appears in `who`, chat, and terminal signing.
display_name :: proc(nicks: ^Nicks, visitor: Visitor) -> Name {
	for &nick in nicks.entries[:nicks.count] {
		if nick.visitor == visitor do return nick.name
	}
	adjective, animal := visitor_name(visitor)
	name: Name
	name.size = u8(len(fmt.bprintf(name.bytes[:], "%s-%s", adjective, animal)))
	return name
}

Nick_Result :: enum {
	Set,
	Invalid, // not 2–20 of a–z, 0–9, and -
	Taken, // someone else's nick, a handle, or reserved
}

// nick_set gives a visitor a nick. Reserved names (dev, root, admin) are only
// for root, and handle-shaped names are refused so no one can pose as
// another visitor's handle.
nick_set :: proc(nicks: ^Nicks, visitor: Visitor, text: string, root: bool) -> Nick_Result {
	if len(text) < NICK_MIN || len(text) > NICK_MAX do return .Invalid
	for character in transmute([]u8)text {
		is_lower := character >= 'a' && character <= 'z'
		is_digit := character >= '0' && character <= '9'
		if !is_lower && !is_digit && character != '-' do return .Invalid
	}
	switch text {
	case "dev", "root", "admin":
		if !root do return .Taken
	}
	if is_handle(text) do return .Taken
	for &nick in nicks.entries[:nicks.count] {
		if name_string(&nick.name) == text && nick.visitor != visitor do return .Taken
	}

	for &nick in nicks.entries[:nicks.count] {
		if nick.visitor == visitor {
			nick.name = name_of(text)
			return .Set
		}
	}
	entry := Nick {
		visitor = visitor,
		name    = name_of(text),
	}
	if nicks.count < len(nicks.entries) {
		nicks.entries[nicks.count] = entry
		nicks.count += 1
	} else {
		nicks.entries[nicks.next] = entry
		nicks.next = (nicks.next + 1) % len(nicks.entries)
	}
	return .Set
}

// is_handle reports whether text looks like a generated adjective-animal name.
@(private = "file")
is_handle :: proc(text: string) -> bool {
	adjective, _, animal := strings.partition(text, "-")
	adjective_found, animal_found := false, false
	for word in ADJECTIVES do adjective_found ||= word == adjective
	for word in ANIMALS do animal_found ||= word == animal
	return adjective_found && animal_found
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
