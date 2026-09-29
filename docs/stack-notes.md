# Stack notes: Gleam comparison, templating, I/O, and memory

Reference notes from a design discussion (September 2026). These are notes to
think about later, not decisions. The current stack is Odin + Tina + Datastar +
SQLite (CQS) + Tempo, and it's staying that way.

## Tempo ignores write results

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

**Caveat for Tina:** an `io.Writer` does _not_ let a template write straight to
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

- [Datastar resources](https://github.com/alvarolm/datastar-resources)
- Odin core in the pinned toolchain: `core/io/io.odin`,
  `core/strings/builder.odin`, `core/nbio/doc.odin`
