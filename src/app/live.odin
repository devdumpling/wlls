package app

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"
import views "../views"
import "core:fmt"
import "core:strings"

// Live connections: every page holds one SSE stream (GET /live) for as long as
// it is visible. A hub isolate keeps the table of who is connected, and wakes
// the streams that care when something they show has changed. Tina messages
// carry 96 bytes, so content never travels in them; it is rendered once into
// a Frame and every stream copies the bytes out.
//
// Live is the memory isolates share: frames, presence, the chat, and nicks.
// That is safe because the app runs on one shard: every isolate runs on the
// same thread, one handler at a time, so nothing here is read while it is
// being written. Moving to more shards means giving each shard its own Live
// (or hub) first.
#assert(SHARD_COUNT == 1, "Live is shared memory between isolates; see live.odin")

// Topic is content a page shows live. Presence is not a topic: every stream
// counts as someone here.
Topic :: enum u8 {
	Guestbook,
	Doodle, // the shared board on /guestbook (doodle.odin)
	Chat, // for visitors in #lobby, on every page (chat.odin)
}
Topics :: bit_set[Topic;u8]

// One frame must fit one Datastar event, which must fit Tina's 16 KiB egress
// buffer along with the event's own framing.
FRAME_MAX :: 12 * 1024

Frame :: struct {
	version: u64,
	size:    int,
	bytes:   [FRAME_MAX]u8,
}

Live :: struct {
	hub:         tina.Isolate_Handle, // set by the hub when it starts
	frames:      [Topic]Frame,
	presence:    Presence, // written only by the hub
	places:      Places,
	chat:        Chat,
	nicks:       Nicks,
	// The #lobby prompt, sent to a new page whose visitor is in the room.
	chat_prompt: Frame,
}

// live_topics is what a stream shows: its page's topics, plus #lobby while
// its visitor is in the room.
live_topics :: proc(live: ^Live, visitor: Visitor, page: Topics) -> Topics {
	topics := page
	if chat_is_member(&live.chat, visitor) do topics += {.Chat}
	return topics
}

// Places are the pages a stream may report, so presence only ever shows real
// site paths, never request input.
Places :: struct {
	paths:   [dynamic]string,
	by_path: map[string]u16,
}

place_add :: proc(places: ^Places, path: string) {
	places.by_path[path] = u16(len(places.paths))
	append(&places.paths, path)
}

// place_topics is what a page shows live, beyond presence.
place_topics :: proc(path: string) -> Topics {
	if path == "/guestbook" do return {.Guestbook, .Doodle}
	return {}
}

// frame_store copies a finished render into a frame and bumps its version.
// A render that failed or outgrew the frame leaves the old frame in place.
frame_store :: proc(frame: ^Frame, buffer: ^httpx.Render_Buffer) -> bool {
	bytes := httpx.render_buffer_bytes(buffer)
	if httpx.render_buffer_failed(buffer) || len(bytes) > FRAME_MAX {
		fmt.eprintfln("wlls: frame render failed or exceeded %d bytes (%d)", FRAME_MAX, len(bytes))
		return false
	}
	copy(frame.bytes[:], bytes)
	frame.size = len(bytes)
	frame.version += 1
	return true
}

frame_bytes :: proc(frame: ^Frame) -> []u8 {
	return frame.bytes[:frame.size]
}

// publish tells the hub a topic's frame changed, so it wakes its streams.
publish :: proc(live: ^Live, topic: Topic) {
	message := Hub_Publish {
		topic = topic,
	}
	_ = tina.ctx_send(live.hub, TAG_HUB_PUBLISH, &message)
}

// ─── Presence ───────────────────────────────────────────────────────────────

// The hub refuses streams past this, leaving a quarter of CONNECTION_SLOTS for
// page loads: a parked stream holds its slot and is never evicted as idle.
PRESENCE_MAX :: CONNECTION_SLOTS * 3 / 4
// `who` lists this many visitors, then counts the rest.
@(private = "file")
WHO_ROWS_MAX :: 25

// Presence is one entry per open stream. Only the hub writes it; anyone
// reads it, which is how `who` is rendered on demand.
Presence :: struct {
	entries: [PRESENCE_MAX]Presence_Entry,
	count:   int,
	joins:   u64,
}

Presence_Entry :: struct {
	handle:  tina.Isolate_Handle,
	token:   http.Request_Token,
	visitor: Visitor,
	place:   u16,
	topics:  Topics,
	joined:  u64, // order of arrival; a visitor's newest stream is where they are
	seen:    u64, // monotonic ns of the last subscribe, renewed every heartbeat
}

// render_who writes the `who` list: one row per visitor, the first
// WHO_ROWS_MAX of them by name, then a total. A visitor with several streams
// (tabs, or a page they just left whose stream has not noticed yet) is shown
// where their newest stream is. It runs only when someone types `who`.
render_who :: proc(output: ^strings.Builder, live: ^Live) {
	presence := &live.presence
	rows: [WHO_ROWS_MAX]views.Who_Row
	names: [WHO_ROWS_MAX]Name
	row_count, total := 0, 0
	for entry in presence.entries[:presence.count] {
		newer := false
		for other in presence.entries[:presence.count] {
			newer ||= other.visitor == entry.visitor && other.joined > entry.joined
		}
		if newer do continue
		total += 1
		if row_count == len(rows) do continue
		names[row_count] = display_name(&live.nicks, entry.visitor)
		rows[row_count] = {
			name  = name_string(&names[row_count]),
			place = live.places.paths[entry.place],
		}
		row_count += 1
	}

	more := ""
	if total > row_count do more = fmt.tprintf("and %d more", total - row_count)
	views.terminal_who(output, rows[:row_count], more, fmt.tprintf("%d here now", total))
}

// ─── Hub isolate ────────────────────────────────────────────────────────────

@(private = "file")
HUB_MAILBOX_CAPACITY :: 512
// Streams re-subscribe every heartbeat (25 s). A stream that closes without
// saying so (a crash, a connection Tina tears down itself) stops renewing,
// and the sweep drops it once it has been silent this long.
@(private = "file")
PRESENCE_TIMEOUT_NS :: 60 * 1_000_000_000
@(private = "file")
HUB_SWEEP_NS :: 30 * 1_000_000_000

TAG_HUB_SUBSCRIBE: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 1
TAG_HUB_UNSUBSCRIBE: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 2
TAG_HUB_PUBLISH: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 3
TAG_LIVE_NOTIFY: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 4
@(private = "file")
TAG_HUB_SWEEP: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 5

// A stream subscribes when it starts and again on every heartbeat, so a
// restarted hub relearns everyone within one heartbeat. It is an upsert.
Hub_Subscribe :: struct {
	token:   http.Request_Token,
	place:   u16,
	topics:  Topics,
	visitor: Visitor,
}

Hub_Publish :: struct {
	topic: Topic,
}

// Live_Notify wakes a stream: something it shows changed, or (refused) the
// hub is full and the stream should end.
Live_Notify :: struct {
	token:   http.Request_Token,
	refused: bool,
}

@(private = "file")
Hub :: struct {
	live: ^Live,
}

@(private = "file")
hub_init :: proc(self_raw: rawptr, args: []u8) -> tina.Isolate_Transition {
	self := tina.self_as(Hub, self_raw)
	self.live = tina.payload_as(^Live, args)^
	// A restarted hub starts from an empty table; streams re-subscribe.
	self.live.presence = {}
	self.live.hub = tina.ctx_self_handle()
	tina.ctx_register_timer(HUB_SWEEP_NS, TAG_HUB_SWEEP)
	return tina.ISOLATE_TRANSITION_WAIT_MESSAGE
}

@(private = "file")
hub_handler :: proc(self_raw: rawptr, message: ^tina.Message) -> tina.Isolate_Transition {
	live := tina.self_as(Hub, self_raw).live
	presence := &live.presence
	source := message.user.source

	switch message.tag {
	case tina.TAG_SHUTDOWN:
		// The shard drains only once every isolate is done, so the hub must
		// finish too or the watchdog force-kills the process at its deadline.
		return tina.ISOLATE_TRANSITION_DONE

	case TAG_HUB_SUBSCRIBE:
		subscribe := tina.payload_as(Hub_Subscribe, message.user.payload[:])
		entry := Presence_Entry {
			handle  = source,
			token   = subscribe.token,
			visitor = subscribe.visitor,
			place   = subscribe.place,
			topics  = subscribe.topics,
			seen    = u64(tina.ctx_monotonic_time_ns()),
		}
		if index, found := find_entry(presence, source); found {
			entry.joined = presence.entries[index].joined
			presence.entries[index] = entry
		} else if presence.count < len(presence.entries) {
			presence.joins += 1
			entry.joined = presence.joins
			presence.entries[presence.count] = entry
			presence.count += 1
		} else {
			refused := Live_Notify {
				token   = subscribe.token,
				refused = true,
			}
			_ = tina.ctx_send(source, TAG_LIVE_NOTIFY, &refused)
		}

	case TAG_HUB_UNSUBSCRIBE:
		if index, found := find_entry(presence, source); found {
			remove_entry(presence, index)
			settle(live)
		}

	case TAG_HUB_PUBLISH:
		notify(live, tina.payload_as(Hub_Publish, message.user.payload[:]).topic)

	case TAG_HUB_SWEEP:
		now := u64(tina.ctx_monotonic_time_ns())
		swept := false
		for index := 0; index < presence.count; {
			if now - presence.entries[index].seen < PRESENCE_TIMEOUT_NS {
				index += 1
				continue
			}
			remove_entry(presence, index)
			swept = true
		}
		if swept do settle(live)
		tina.ctx_register_timer(HUB_SWEEP_NS, TAG_HUB_SWEEP)
	}
	return tina.ISOLATE_TRANSITION_WAIT_MESSAGE
}

// notify wakes every stream that shows topic. A dead stream found on the way
// is dropped, and the hub settles once the round is done.
@(private = "file")
notify :: proc(live: ^Live, topic: Topic) {
	presence := &live.presence
	dropped := false
	for index := 0; index < presence.count; {
		entry := presence.entries[index]
		if topic not_in live_topics(live, entry.visitor, entry.topics) {
			index += 1
			continue
		}
		message := Live_Notify {
			token = entry.token,
		}
		// A full mailbox keeps the entry: the stream already has a wake-up
		// pending and will send the latest frame anyway.
		if tina.ctx_send(entry.handle, TAG_LIVE_NOTIFY, &message) == .stale_handle {
			remove_entry(presence, index)
			dropped = true
			continue
		}
		index += 1
	}
	if dropped do settle(live)
}

// settle runs after streams go away: anyone in #lobby whose last page has
// closed leaves it.
@(private = "file")
settle :: proc(live: ^Live) {
	presence := &live.presence
	left := false
	for index := 0; index < live.chat.member_count; {
		visitor := live.chat.members[index].visitor
		here := false
		for entry in presence.entries[:presence.count] {
			here ||= entry.visitor == visitor
		}
		if !here && chat_leave(live, visitor) {
			left = true
			continue // the last member moved into this index
		}
		index += 1
	}
	if left && chat_render(live) do notify(live, .Chat)
}

@(private = "file")
find_entry :: proc(presence: ^Presence, handle: tina.Isolate_Handle) -> (int, bool) {
	for entry, index in presence.entries[:presence.count] {
		if entry.handle == handle do return index, true
	}
	return -1, false
}

// remove_entry swaps the last entry into the gap; order is free.
@(private = "file")
remove_entry :: proc(presence: ^Presence, index: int) {
	presence.count -= 1
	presence.entries[index] = presence.entries[presence.count]
}

// install_hub adds the hub to the boot spec that http.install built, ahead of
// the HTTP isolates so it is running before the first stream subscribes.
install_hub :: proc(spec: ^tina.SystemSpec, live: ^Live) {
	type_id := tina.Isolate_Type_Id(len(spec.types))
	types := make([]tina.IsolateTypeDescriptor, len(spec.types) + 1)
	copy(types, spec.types)
	types[type_id] = tina.IsolateTypeDescriptor {
		id                = type_id,
		slot_count        = 1,
		stride            = size_of(Hub),
		soa_metadata_size = size_of(tina.Isolate_Metadata),
		mailbox_capacity  = HUB_MAILBOX_CAPACITY,
		budget_weight     = 1,
		init_handler      = hub_init,
		handler_fn        = hub_handler,
	}
	spec.types = types

	// http.install sized the message pool for its own isolates; make room for
	// the hub's mailbox too, keeping the pool a power of two.
	needed := spec.pool_slot_count + 2 * HUB_MAILBOX_CAPACITY
	for spec.pool_slot_count < needed do spec.pool_slot_count *= 2

	live_pointer := live
	child := tina.Static_Child_Spec {
		type_id      = type_id,
		restart_type = .permanent,
	}
	child.args_payload, child.args_size = tina.init_args_of(&live_pointer)
	root := &spec.shard_specs[0].root_group
	children := make([]tina.Child_Spec, len(root.children) + 1)
	children[0] = child
	copy(children[1:], root.children)
	root.children = children
}
