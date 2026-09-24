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
pipeline with raw HTML disabled. `@document(...) { ... }` composes the shared
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

Generated components write to `^strings.Builder`. Full documents use
`httpx.Document_Stream`: a heap-backed growable builder followed by bounded,
fixed-length writes through Tina's evented HTTP response API. Its allocator
records failed writes even though Tempo ignores their return values, allowing
the response to become a 500 rather than silently serving truncated markup.
Tina's `write_bytes` reports how much it accepted; the handler flushes and
continues on `Send_Ready`, then frees the builder after all bytes have been
copied into Tina's 4 KiB egress buffer. Embedded static assets borrow their
bytes instead of allocating a second copy for each request. Event handlers
access immutable startup data through `Route_Context.application_context`,
owned for the lifetime of the server.

The blog's initial document responses work without JavaScript. The bundled
Datastar browser module is served from a fingerprinted local asset URL; the
lab will use Tina's Datastar SSE SDK for interactive resources.
