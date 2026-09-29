# Stack notes: Gleam comparison, templating, I/O, and memory

Reference notes from a design discussion (September 2026). These are notes to
think about later, not decisions. The current stack is Odin + Tina + Datastar +
SQLite (CQS) + Tempo, and it's staying that way.

## 1. Gleam as an alternative stack

### Tina is already BEAM ideas written in Odin

Tina's README describes isolates, message passing, supervision trees, restart
budgets, and "let it crash". Those are Erlang/OTP's core ideas, rebuilt in a
systems language with preallocated, bounded memory and deterministic simulation
testing added on top. So moving to Gleam wouldn't mean a new architecture. It
would mean moving to the runtime Tina imitates, and giving up the systems-level
control Tina adds on top of it.

- **Odin + Tina:** BEAM-style ideas where you control every byte and can replay
  every run.
- **Gleam:** the BEAM itself, with a good type system, where the runtime
  controls the bytes.
- **Go:** somewhere in between; cheap concurrency, but no supervision model.

### How the stack would map

| Today | Gleam equivalent | Notes |
|---|---|---|
| Tina HTTP | Mist (optionally Wisp on top) | Mist has server-sent events built in, and each stream runs as its own actor. Wisp is more request/response, so long-lived Datastar streams mostly live at the Mist level. |
| Tina Datastar SDK | `datastar`, `datastar_wisp`, `datastar_lustre` (sporto/gleam-datastar) | Community-maintained builder API: `ds_sse.patch_elements() \|> ds_sse.patch_elements_selector("#x") \|> ds_sse.patch_elements_merge_mode(ds_sse.Inner)`. Its README mentions compatibility with 1.0.0-RC.8, so check which protocol version it actually targets. |
| Tempo (`.templ` → Odin) | Lustre `element` rendered to `String`/`string_tree`, or Matcha (`.matcha` templates compiled to Gleam) | Matcha is the closest thing to Tempo. Lustre elements are plain typed functions with no codegen step, and raw HTML has to go through an explicit `unsafe_raw_html`. |
| SQLite + CQS | sqlight, plus Marmot (SQL files → typed Gleam, for SQLite) or Parrot (built on sqlc) | Plain `.sql` files with generated typed functions and row decoders. |
| Embedded assets / single binary | `priv/` directory plus an Erlang release | See the trade-offs below. |

### Where it gets interesting

1. **Datastar's model fits the BEAM very well.** Long-lived SSE stream per
   tab, view as a function of state, commands write to the database, every open
   stream re-renders and pushes a full morph. On the BEAM each open stream is a
   cheap process subscribed to a topic (process groups or a registry). A command
   finishes, broadcasts "posts changed", and every subscribed stream re-queries
   and calls `patch_elements`. No connection table, no locking.
2. **CQS fits SQLite's single writer.** SQLite allows one writer at a time. On
   the BEAM the natural shape is one writer actor that owns the write
   connection and handles commands in sequence, plus a pool of read connections
   for queries. CQS is enforced by the process layout rather than by
   convention.
3. **Datastar vs. Lustre server components is a real choice.** Lustre server
   components keep stateful components on the server and send DOM patches to a
   ~10 KB client over WebSockets, SSE, or polling (the LiveView model). That
   competes with Datastar's stateless approach, where signals live in the
   browser. `datastar_lustre` allows Lustre as the HTML builder with Datastar as
   the transport, which is the combination I'd pick.
4. **Some Odin plumbing would go away.** No `Document_Stream`-style failed
   write tracking or egress-buffer chunking. Templates produce iolist-backed
   `string_tree` values that the VM writes to the socket without copying.

### What you'd gain

- Fault tolerance as the runtime, not a framework you vendor and patch.
- Clustering and distribution if ever needed.
- Exhaustive pattern matching, immutable data, `Result` everywhere, very good
  compiler errors and LSP support.
- The Hex ecosystem, including Erlang and Elixir libraries.
- An optional JavaScript target for shared code (less relevant with Datastar).

### What you'd give up

- **Deterministic simulation testing.** Tina's "same seed, same execution"
  replay has no real BEAM equivalent.
- **Bounded, preallocated memory.** BEAM mailboxes are unbounded by default. A
  slow SSE client grows memory instead of shedding load; backpressure would be
  your job.
- **The single static binary.** An Erlang release bundles the runtime (ERTS):
  larger, slower to start, tens of MB of memory rather than a few. Assets live
  in `priv/` rather than inside the binary.
- **Control over bytes and latency.** No allocators, no zero-allocation hot
  paths, no fixed egress buffers.
- **No metaprogramming.** No derive, macros, or typeclasses. JSON decoders for
  signals are handwritten with `gleam/dynamic/decode` or generated.
- **Ecosystem maturity.** Wisp and Mist are solid but young; the Datastar SDK
  is a small community project (as is Tina's).

### Bottom line

- **Interactive, multi-user, long-lived-connection apps** (collaboration, live
  dashboards, heavy SSE fan-out): Gleam is the more natural home.
- **Predictable performance, tight resource bounds, replayable testing:** Odin
  + Tina, since Gleam can't provide what Tina adds beyond the BEAM.

If I ever want to test it: port one interactive route (Mist SSE handler, a
Lustre-rendered fragment, a Marmot query, a writer actor with a broadcast
topic) and compare code size and moving parts against the Tina version.

**Decision for now:** stay on Odin. It's shared with game development, most of
its cost is one-time infrastructure, and it gives more control while still
feeling high level.

## 2. Tempo ignores write results

Tempo generates code like this (`src/views/blog_gen.odin`):

```odin
post_link :: proc(w: ^strings.Builder, post: content.Post) {
	strings.write_string(w, "<li><article class=\"post-entry\"><h2><a href=\"")
	templ.write_escaped(w, post.url)
	strings.write_string(w, "\">")
	...
}
```

In the pinned Odin core, `strings.write_string` is:

```odin
write_string :: proc(b: ^Builder, s: string, loc := #caller_location) -> (n: int)
```

It appends to the builder's buffer and returns how many bytes landed. If the
allocator can't grow the buffer, the append fails quietly and `n` is smaller
than `len(s)`. That short count is the only failure signal. The generated code
discards it on every line, and component procs return nothing, so a failed
write can't reach the handler.

- **Fixed-capacity builder:** long pages get cut off at capacity and would go
  out as a 200 with broken HTML.
- **Growable heap builder:** allocation rarely fails, but when it does, the
  same silent truncation happens.

**The current workaround** (`src/httpx/documents.odin`): `tracked_heap` wraps
the builder's allocator so any failed allocation sets `stream.render_failed`.
`document_send` checks that flag before sending headers and returns a 500
instead of a partial page. The allocator does the reporting because the
generated code can't.

The gap is partly `strings.Builder`'s own API (a byte count, not an error). A
better templating library would:

1. **Write to an `io.Writer` instead of `^strings.Builder`**, so every write
   returns `(n: int, err: io.Error)`.
2. **Pass errors up.** Each generated component returns an `io.Error` and stops
   at the first failure, e.g. `post_link(w, post) or_return`.

With both, the allocator trick is unnecessary: the handler gets an error back
from the render call.

## 3. `^strings.Builder` vs `io.Writer` / `io.Stream`

**`strings.Builder`** is a concrete type: a growable byte buffer
(`[dynamic]byte`). Taking `^strings.Builder` means output can only go to
memory, and its write procs return counts rather than errors.

**`io.Stream`** is Odin's type-erased I/O interface (`core/io/io.odin`):

```odin
Stream :: struct {
	procedure: Stream_Proc, // proc(data, mode, p, offset, whence) -> (n: i64, err: Error)
	data:      rawptr,
}
```

A function pointer plus a context pointer. The `mode` argument (`.Read`,
`.Write`, `.Flush`, `.Close`, …) selects the operation. **`io.Writer` is just
`io.Writer :: Stream`**, an alias that documents write-only intent. It's Go's
`io.Writer` without methods or interfaces.

A component taking an `io.Writer` doesn't care where bytes go: a builder (via
`strings.to_writer(&b)`), a file, a `bufio` writer, a `Multi_Writer`, or a
custom writer over a fixed buffer. Every write returns `(n, err)`. The cost is
one indirect call per write, which doesn't matter for HTML.

**Caveat for Tina:** an `io.Writer` does *not* let a template write straight to
the socket. Tina is evented: a write can't block mid-render waiting for
`Send_Ready`, and a template proc can't pause partway through a loop. Render
fully, then copy chunks, as `Document_Stream` does. The benefit of `io.Writer`
is errors and choice of destination, not streaming.

## 4. `nbio`

`core:nbio` is part of Odin's core library (included in the pinned toolchain).
It's a non-blocking I/O event loop with per-platform backends: io_uring on
Linux, kqueue on macOS/BSD, IOCP on Windows. Each thread has at most one event
loop. You submit operations (accept, recv, send, timeout, …) with callbacks,
then drive the loop with `tick`/`run`/`run_until`. It grew out of the
odin-http work.

Why people praise it: one small, portable, allocation-conscious API over three
very different kernel interfaces, with a callback model simple enough to reason
about. io_uring performance without writing io_uring code.

**Tina doesn't use it.** Tina has its own backends
(`vendor/tina/src/io_backend_linux.odin` imports `core:sys/linux/uring`
directly, plus BSD kqueue and Windows backends). nbio is a library you drive;
Tina is a runtime that owns all I/O, which it needs so the I/O layer can be
swapped out for deterministic simulation. nbio is what you'd build on for a
custom server without Tina.

## 5. Heap vs preallocation

The heap isn't wrong, but `Document_Stream`'s heap builder is the one place the
app steps outside Tina's philosophy. Tina sizes memory at startup and sheds
load when it runs out. The heap makes per-request memory unbounded, adds malloc
latency and fragmentation, and makes out-of-memory behavior unpredictable.

Options, by response type:

1. **Static pages: render once at startup.** Content is loaded and validated
   before the server accepts requests. If nothing in a page depends on the
   request, render every page into immutable bytes during startup and serve
   them through the existing `bytes_begin` path used for static assets. No
   per-request allocation, and render errors become startup errors that block
   a deploy. `tracked_heap` could be deleted. **To check first:** whether any
   view uses request data.
2. **Dynamic responses** (lab pages, Datastar fragments): use a bounded buffer
   rather than the general heap.
   - A fixed-size buffer per request from Tina's boot config, behind an
     `io.Writer` that returns an error when full. Overflow becomes a clean 500
     or load-shed response, never a truncated page. This fits Tina best, and
     it's where an `io.Writer`-based template library would help most.
   - A `core:mem/virtual` arena with a hard reserve limit. It reserves address
     space up front and commits pages as used, so small responses stay cheap
     and large ones hit a known ceiling. Free everything at once when the
     response is done.

## Sources

- [sporto/gleam-datastar](https://github.com/sporto/gleam-datastar)
- [datastar (Gleam) on HexDocs](https://datastar.hexdocs.pm/index.html)
- [datastar_lustre on Hex](https://hex.pm/packages/datastar_lustre)
- [Lustre](https://github.com/lustre-labs/lustre) and
  [lustre/server_component](https://hexdocs.pm/lustre/lustre/server_component.html)
- [Marmot](https://marmot.hexdocs.pm/),
  [Parrot](https://github.com/daniellionel01/parrot),
  [Squirrel](https://github.com/giacomocavalieri/squirrel)
- [Matcha](https://github.com/michaeljones/matcha)
- [Datastar resources](https://github.com/alvarolm/datastar-resources)
- Odin core in the pinned toolchain: `core/io/io.odin`,
  `core/strings/builder.odin`, `core/nbio/doc.odin`
