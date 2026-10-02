package app

import tina "../../vendor/tina/src"
import http "../../vendor/tina/src/extensions/http/server"
import httpx "../httpx"
import views "../views"
import "core:fmt"

// Live connections: every page holds one SSE stream (GET /live) for as long as
// it is visible. A hub isolate tracks who is connected, and wakes the streams
// that care when something they show has changed. Tina messages carry 96
// bytes, so content never travels in them; it is rendered once into a Frame
// and every stream copies the bytes out.
//
// Frames are the one piece of memory isolates share. That is safe because the
// app runs on one shard: every isolate runs on the same thread, one handler
// at a time, so a frame is never read while it is being written. Moving to
// more shards means giving each shard its own frames (or hub) first.
#assert(SHARD_COUNT == 1, "live frames are shared memory between isolates; see live.odin")

// Topic is content a page shows live. Presence is not a topic: every stream
// counts as someone here.
Topic :: enum u8 {
	Guestbook,
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
	hub:    tina.Isolate_Handle, // set by the hub when it starts
	frames: [Topic]Frame,
	who:    Frame, // the presence list `who` prints
	places: Places,
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
	if path == "/guestbook" do return {.Guestbook}
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

// ─── Hub isolate ────────────────────────────────────────────────────────────

// The hub refuses streams past this, leaving a quarter of CONNECTION_SLOTS for
// page loads: a parked stream holds its slot and is never evicted as idle.
HUB_SUBSCRIBERS_MAX :: CONNECTION_SLOTS * 3 / 4
@(private = "file")
HUB_MAILBOX_CAPACITY :: 512
// `who` lists this many visitors, then counts the rest.
@(private = "file")
WHO_ROWS_MAX :: 25

TAG_HUB_SUBSCRIBE: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 1
TAG_HUB_UNSUBSCRIBE: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 2
TAG_HUB_PUBLISH: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 3
TAG_LIVE_NOTIFY: tina.Message_Tag : tina.USER_MESSAGE_TAG_BASE + 4

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
Subscriber :: struct {
	handle:  tina.Isolate_Handle,
	token:   http.Request_Token,
	visitor: Visitor,
	place:   u16,
	topics:  Topics,
	joined:  u64, // order of arrival; a visitor's newest stream is where they are
}

@(private = "file")
Hub :: struct {
	live:        ^Live,
	subscribers: [HUB_SUBSCRIBERS_MAX]Subscriber,
	count:       int,
	joins:       u64,
}

@(private = "file")
hub_init :: proc(self_raw: rawptr, args: []u8) -> tina.Isolate_Transition {
	self := tina.self_as(Hub, self_raw)
	self^ = {
		live = tina.payload_as(^Live, args)^,
	}
	self.live.hub = tina.ctx_self_handle()
	render_who(self)
	return tina.ISOLATE_TRANSITION_WAIT_MESSAGE
}

@(private = "file")
hub_handler :: proc(self_raw: rawptr, message: ^tina.Message) -> tina.Isolate_Transition {
	self := tina.self_as(Hub, self_raw)
	source := message.user.source

	switch message.tag {
	case TAG_HUB_SUBSCRIBE:
		subscribe := tina.payload_as(Hub_Subscribe, message.user.payload[:])
		entry := Subscriber {
			handle  = source,
			token   = subscribe.token,
			visitor = subscribe.visitor,
			place   = subscribe.place,
			topics  = subscribe.topics,
		}
		if index, found := find_subscriber(self, source); found {
			moved := self.subscribers[index].place != entry.place
			entry.joined = self.subscribers[index].joined
			self.subscribers[index] = entry
			if moved do render_who(self)
		} else if self.count < len(self.subscribers) {
			self.joins += 1
			entry.joined = self.joins
			self.subscribers[self.count] = entry
			self.count += 1
			render_who(self)
		} else {
			refused := Live_Notify {
				token   = subscribe.token,
				refused = true,
			}
			_ = tina.ctx_send(source, TAG_LIVE_NOTIFY, &refused)
		}

	case TAG_HUB_UNSUBSCRIBE:
		if index, found := find_subscriber(self, source); found {
			remove_subscriber(self, index)
			render_who(self)
		}

	case TAG_HUB_PUBLISH:
		topic := tina.payload_as(Hub_Publish, message.user.payload[:]).topic
		dropped := false
		for index := 0; index < self.count; {
			subscriber := self.subscribers[index]
			if topic not_in subscriber.topics {
				index += 1
				continue
			}
			notify := Live_Notify {
				token = subscriber.token,
			}
			// A full mailbox keeps the subscriber: the stream already has a
			// wake-up pending and will send the latest frame anyway.
			if tina.ctx_send(subscriber.handle, TAG_LIVE_NOTIFY, &notify) == .stale_handle {
				remove_subscriber(self, index)
				dropped = true
				continue
			}
			index += 1
		}
		if dropped do render_who(self)
	}
	return tina.ISOLATE_TRANSITION_WAIT_MESSAGE
}

@(private = "file")
find_subscriber :: proc(self: ^Hub, handle: tina.Isolate_Handle) -> (int, bool) {
	for index in 0 ..< self.count {
		if self.subscribers[index].handle == handle do return index, true
	}
	return -1, false
}

// remove_subscriber swaps the last subscriber into the gap; order is free.
@(private = "file")
remove_subscriber :: proc(self: ^Hub, index: int) {
	self.count -= 1
	self.subscribers[index] = self.subscribers[self.count]
}

// render_who renders the presence list: one row per visitor, the first
// WHO_ROWS_MAX of them by name, then a total. A visitor with several streams
// (tabs, or a page they just left whose stream has not noticed yet) is shown
// where their newest stream is.
@(private = "file")
render_who :: proc(self: ^Hub) {
	rows: [WHO_ROWS_MAX]views.Who_Row
	row_count, total := 0, 0
	for index in 0 ..< self.count {
		subscriber := self.subscribers[index]
		newer := false
		for other in self.subscribers[:self.count] {
			if other.visitor == subscriber.visitor && other.joined > subscriber.joined {
				newer = true
				break
			}
		}
		if newer do continue
		total += 1
		if row_count == len(rows) do continue
		adjective, animal := visitor_name(subscriber.visitor)
		rows[row_count] = {
			adjective = adjective,
			animal    = animal,
			place     = self.live.places.paths[subscriber.place],
		}
		row_count += 1
	}

	summary_buffer, more_buffer: [32]u8
	summary := fmt.bprintf(summary_buffer[:], "%d here now", total)
	more := ""
	if total > row_count do more = fmt.bprintf(more_buffer[:], "and %d more", total - row_count)

	buffer: httpx.Render_Buffer
	writer := httpx.render_buffer_init(&buffer)
	defer httpx.render_buffer_destroy(&buffer)
	views.terminal_who(writer, rows[:row_count], more, summary)
	frame_store(&self.live.who, &buffer)
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
