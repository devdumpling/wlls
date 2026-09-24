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

Generated components write to `^strings.Builder`. For these small preview
pages, HTTP handlers use a fixed, caller-owned buffer and check the result
before `http.respond_bytes`; real articles need an evented, chunked response
path instead of forcing them into Tina's default 4 KiB egress buffer. Rendering
into a fixed builder does not allocate, but it can silently reject writes that
exceed its 16 KiB capacity. The preview guards against a missing document or
article end marker; a production streaming adapter must propagate overflow
explicitly rather than silently serving truncated markup.

The same `article_element` component is used for the initial article page,
the HTML fragment response, and SSE patches at `/template-preview/events`.
That handler uses Tina's Datastar extension: `datastar.start_sse`,
`datastar.patch_elements`, `http.flush()`, `datastar.resume`, and
`http.flush(final = true)`. Keep-alive clients receive a loading element and
then the rendered article in separate flushes. Tina currently ends streams
marked `Connection: close` after the first flush, so those clients receive
the rendered article in one final event. The preview document loads a
version-pinned Datastar browser bundle; the server remains the source of
truth for its rendered element.
