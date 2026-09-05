# Architecture

## Runtime

`cmd/wlls` creates the process context and logger, loads validated environment
configuration, constructs `internal/app`, and maps the terminal error to an exit
code.

`internal/app` is the composition root. Startup constructs the asset manifest,
renders and validates embedded Markdown, builds feature handlers, composes Chi,
and creates the HTTP server. HTTP request contexts derive from the process
context and are canceled before graceful shutdown.

```text
Client -> Cloudflare -> Caddy -> Chi -> feature handler -> Templ document
```

Caddy terminates origin TLS and proxies to Go on loopback. Go owns response
compression and cache policy.

## Content flow

The root `content` package embeds `posts/*.md` and `pages/*.md`. At startup:

1. `internal/blog` parses and validates post front matter.
2. `internal/markdown` renders conventional Markdown with raw HTML disabled.
3. `internal/blog.Repository` indexes published posts immutably by date/slug.
4. `internal/about` loads the separate about page.

Requests query these in-memory values. Blog availability has no database,
messaging, filesystem, or JavaScript dependency.

The newest post is `/`, the archive is `/blog`, and canonical post documents are
under `/blog/{slug}`. Feed and sitemap resources derive from the same repository.

## Views and assets

`internal/site` owns the shared Templ document, metadata, navigation, footer, and
error page. Features own their page composition.

`internal/assets` embeds plain CSS, the vendored Datastar browser module, fonts,
and media. It hashes the complete embedded asset set at startup and produces
URLs below `/static/{fingerprint}/`. Those URLs are immutable. Legacy
`/images/*`, `/fonts/*`, and `/favicon.svg` paths remain short-lived compatibility
resources.

The Datastar browser client and Go SDK are independently versioned. The browser
module is available to the shared document; the Go SDK will be added when a real
interaction requires an SSE response.

## HTTP policy

`internal/httpx` contains shared transport mechanics only:

- buffered Templ rendering;
- request logging and panic recovery;
- consistent server errors;
- cache policy constants;
- zstd-first, Brotli-fallback content negotiation.

Documents use a short browser and longer shared-cache lifetime. Fingerprinted
assets are immutable. Discovery resources have an explicit cache lifetime.
Health/readiness are `no-store`. Future SSE responses must also be non-cacheable
while retaining negotiated streaming compression and flush behavior.

## Deferred dynamic platform

SQLite, NATS, JetStream, NATSrpc, and persistent Datastar SSE are intentionally
not constructed without a real dynamic feature. The first such feature will own
its command, query, event, subject, schema, and fragment definitions. Shared
SQLite/NATS mechanics should be added only at that point; see
[`implementation-plan.md`](implementation-plan.md).
