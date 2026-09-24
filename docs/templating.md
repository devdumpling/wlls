# Authoring views with Tempo

Views are authored as `.templ` files in `src/views/`. This provides HTML-shaped,
composable server components with Odin expressions, loops, conditionals, and
typed parameters, like Templ or gsx. Odin's compiler cannot parse markup inside
ordinary `.odin` files, so Tempo generates `_gen.odin` files that the Odin
compiler type-checks. The generated files are ignored by Git and regenerated
by `just build`, `just check`, and both Nix builds. To inspect them, run
`just generate`.

```
article_element :: templ(article: Article) {
    <article id="article-preview">
        <h1>{ article.title }</h1>
        <div>{! string(article.body) }</div>
    </article>
}
```

`{ value }` escapes text and attributes. `{! value }` deliberately writes raw
HTML; reserve it for `Trusted_HTML` produced by the Markdown content pipeline
with raw HTML disabled. `@document(...) { ... }` composes the shared shell via
a slot; `@article_element(...)` can render into a full document or a fragment.
See `src/views/article.templ` and `src/views/layout.templ` for live examples.

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

Generated components write to `^strings.Builder`. Small fragments can use a
fixed builder when their maximum size is known. Full documents use
`httpx.Document_Stream`: a heap-backed growable render builder followed by
bounded writes through Tina's evented HTTP response API. The builder is
independent of Tina's small request allocator and stays alive across send-ready
callbacks. This keeps the whole page out of Tina's 4 KiB egress buffer while
preserving a simple component signature.
Tina's `write_bytes` reports how much it accepted; the handler flushes and
continues on `Send_Ready`, then releases the render buffer once all bytes have
been copied into Tina's egress buffer. Event handlers can read immutable
startup data through `Route_Context.application_context`; its owner keeps the
data alive for the server lifetime.

The same `article_element` component is used for the initial article page,
the HTML fragment response, and SSE patches at `/template-preview/events`.
That handler uses Tina's Datastar extension: `datastar.start_sse`,
`datastar.patch_elements`, `http.flush()`, `datastar.resume`, and
`http.flush(final = true)`. Keep-alive clients receive a loading element and
then the rendered article in separate flushes. Tina completes all non-final
flushes before honoring `Connection: close` at the end of the response. The
preview document loads a version-pinned Datastar browser bundle; the server
remains the source of truth for its rendered element.
