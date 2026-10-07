# Authoring views with Tempo

Views are authored as `.templ` files in `src/views/`. This provides HTML-shaped,
composable server components with Odin expressions, loops, conditionals, and
typed parameters, like Templ or gsx. Odin's compiler cannot parse markup inside
ordinary `.odin` files, so Tempo generates `_gen.odin` files that the Odin
compiler type-checks. The generated files are ignored by Git and regenerated
by `just build`, `just check`, and both Nix builds. To inspect them, run
`just generate`.

```
post_page :: templ(post: content.Post, metadata: Metadata, assets: Asset_URLs) {
    @document(metadata, assets) {
        <article>
            <h1>{ post.title }</h1>
            <div class="article-body">{! string(post.html) }</div>
        </article>
    }
}
```

`{ value }` escapes text and attributes. `{! value }` deliberately writes raw
HTML; reserve it for `content.Markdown_HTML` produced by the cmark-gfm content
pipeline with raw HTML disabled.

Footnotes render twice: cmark's notes section at the end of the post, and a
sidenote copy right after each note's first reference
(`src/content/footnotes.odin`). CSS shows one of them. A container query on
`main` hangs the sidenotes in the margin when there's room and hides the
section; otherwise it hides the sidenotes. Sidenotes sit inside paragraphs,
so a footnote may only contain paragraphs; anything else fails startup. To leave
room for them, the navigation rail folds to its glyphs from 60rem to 84rem;
past that the full rail and sidenotes both fit. `@document(...) { ... }` composes the shared
shell via a slot. See `src/views/blog.templ` and `src/views/layout.templ` for
the authored pages.

The build pins [Tempo](https://github.com/kalsprite/tempo) revision `9ed296f`
in `flake.lock`. `patches/tempo-core-os.patch` adapts its CLI to the `core:os`
API of the pinned Odin compiler. The generated views import Tempo's runtime
through the `tempo` Odin collection; Nix and the development shell supply the
same pinned source. The upstream example application still uses an obsolete
filesystem call, but its generated templates compile with this toolchain.

[ohtml](https://github.com/ankitpatial/odin-html) compiles with this Odin
revision but does not currently have a license in its repository, so we are
not building on it. gsx is useful as an authoring reference, but generates Go,
not Odin.

## Rendering with Tina and Datastar

There are three kinds of response, each with one home:

| Response | Rendered | Code |
|---|---|---|
| Pages, feed, sitemap, robots | once, at startup | `src/app/site.odin` (`prerender`) |
| Embedded assets | never (borrowed bytes) | `src/app/route_static.odin` |
| Request-dependent (404, Datastar patches) | per request | `httpx.begin_render`, `httpx.begin_patches` |

**Startup.** `app.load` builds everything the server borrows (assets, content,
and every page) in one growing virtual arena, released with a single call at
shutdown. Every page depends only on that data, so it is rendered once into
immutable bytes with a content-hash ETag. A page that fails to render stops
startup, and so the deploy, instead of becoming a 500 later.

**Per request.** Tempo's generated components write to `^strings.Builder` and
discard write results. `httpx.Render_Buffer` makes that safe: its builder lives
in a static virtual arena capped at `RENDER_BUFFER_MAX`, growing in place with
no copies, and its allocator records any failure so the response becomes a 500
instead of truncated markup. The arena is freed in one call when the response
is done. Inside a handler, Tina points `context.temp_allocator` at a
small fixed scratch arena (about 6 KiB) that fails quietly when full, so
handlers that build text install their own growing one with
`httpx.scratch_allocator`.

**Sending.** Tina never blocks a handler and never buffers without bound: each
connection has a fixed egress buffer (`HTTP_EGRESS_BUFFER_SIZE`, 16 KiB here,
set in the justfile and flake). A body larger than that goes out in pieces:
write what fits, return `flush()`, continue on `Send_Ready`. Go hides the same
loop behind a blocking `Write` on a 4 KiB `bufio.Writer`; Node hides it by
buffering in memory without limit. Here the place in the loop lives in route
state:

- `httpx.Body_Stream` + `httpx.drive` for pages, assets, and 404s. A byte body
  can be cut anywhere, so any size streams through any buffer.
- `httpx.Patch_Stream` + `httpx.drive_patches` for Datastar. The SDK writes
  each SSE event in one piece (zero allocation, never half an event), so **one
  event can be at most the egress buffer**. Queue a response's events on
  `Request_Start`; `send_patches` drains them, resuming after backpressure.

Every route handler has the same shape: on `Request_Start`, pick a response and
begin it; on any later event, return `httpx.drive(...)` (or `drive_patches`).
Security headers are set by `httpx` on every response.

**Batching.** Datastar favors a few coarse patches over many small ones; more
elements per event means bigger events, which is why the buffer is 16 KiB
rather than Tina's default 4 KiB. For live experiments (games, presence), batch
over time instead: coalesce state changes and send one patch per tick, and when
a client is backpressured, skip the frame and send the latest state next tick
rather than queueing. That keeps memory bounded per connection, matching
Tina's model.

The blog's initial document responses work without JavaScript. The bundled
Datastar + Rocket module (`datastar-rocket.js`) is served from a fingerprinted
local asset URL. Components in the same directory import it relatively
(`import { rocket } from "./datastar-rocket.js"`), which resolves to the URL
the page already loaded, so there is one module instance and no import map.

**Content-Security-Policy.** `httpx.CONTENT_SECURITY_POLICY` is static, so
pages can be rendered once and cached: same-origin resources only, and no
inline scripts or styles. It allows `'unsafe-eval'` because Datastar compiles
`data-*` expressions with `Function()`; Datastar's nonce mode avoids that, but
a nonce must change per response, which pre-rendered, edge-cached pages cannot
do. Two consequences for new code: never send Datastar execute-script events
(they arrive as inline scripts; patch in an element with a `data-init`
expression instead, as `views.terminal_navigate` does), and give a Rocket
component's `css` a hash in the policy.

Interactive resources follow the Tao of Datastar: the server renders HTML with
the same Tempo components the page uses and patches it in over SSE (Caddy
compresses the stream with zstd). Signals are kept for client feedback only.
The terminal is the model: `POST /terminal` receives the command as a
form, and `src/app/route_terminal.odin` queues patches that append the result
and replace the prompt. Every page renders it inside a `<dialog>` sheet
(`views.terminal_sheet`) opened by a trigger at the end of the breadcrumb row,
or by `/` anywhere; on small screens the sheet takes the whole screen. The
`<wlls-terminal>` Rocket component in `src/assets/static/js/terminal.js` adds
only browser concerns: focus, the `/` shortcut, history (kept in
`localStorage`), and scroll-follow. The sheet follows a component-local `$$.open`
signal, so `exit` closes it in the browser without a request.

## Live connections

Every page opens one long-lived stream with
`data-init="@get('/live?path=…')"` (`views.live_mount`); Datastar closes it
while the tab is hidden. (A 404 reports one place, `/404`, so request paths
never become places.) That stream is the read side for everything live; writes
stay short POSTs (`/terminal`, `/guestbook`). Content never travels in Tina
messages (96 bytes): a feature renders a **frame** once per change (Tempo
HTML whose elements carry ids), a hub isolate wakes the streams subscribed to
that topic, and each copies the newest frame into its egress buffer, so a
slow client simply skips to the latest version. `Live` (frames, presence,
#lobby, nicks), the guestbook, and sudo sessions are the only state isolates
share, which is safe because the app runs one shard (`src/app/live.odin`).
The hub is the only writer of presence; `who` reads it when asked.

## CSS

Two stylesheets, layered with `@layer reset, tokens, base, layout, prose,
components, garden`:

- `src/assets/static/css/site.css` is **structure**: the shell grid, rhythm,
  and each component's anatomy, in neutral defaults.
- `src/assets/static/css/garden.css` is the **theme** ("Field Notes"):
  tokens, type, texture, ornament, and motion, all in the last layer. It
  could be swapped wholesale without touching markup, CSS Zen Garden style.

A rule belongs in `site.css` if the page would break without it, and in
`garden.css` if it only changes how the page looks.

**Print** follows the same split. `site.css` hides the shell (rail, breadcrumb
row, terminal) and gives `main` the page; `garden.css` swaps in ink on white
paper. Backgrounds don't print by default, so printed rules are borders. The
resume prints on a named page (`.resume { page: resume }` with
`@page resume`), so its US-letter size and tighter margins apply to it
alone; `@page` rules sit outside the layers, which can't contain them.

**Plates.** An image alone in its paragraph becomes a figure, and a run of
them a set (`src/content/plates.odin`). The title carries the caption and,
after a `|`, options:

```markdown
![alt text](/images/posts/x.webp "A caption | wide color")
```

Sizes are `wide` (out into the margin) and `full` (all of `main`'s width);
`color` skips the warm tone, `raw` the mat and tone, and `pixel` scales
pixel art crisply. Images must be embedded, and each is sized at startup.
