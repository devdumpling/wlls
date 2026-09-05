# wlls.dev implementation plan

Status: the immediate blog milestone described below is implemented in the
working tree; the first-demo platform work remains intentionally deferred. This
plan is based on
[`wlls-platform-architecture-spec.md`](./wlls-platform-architecture-spec.md).

## 1. Destination

Build a small server-rendered Go site with:

- Chi at the HTTP boundary.
- Templ documents and components.
- A locally vendored Datastar client and the Datastar Go SDK, introduced where
  an interaction actually needs them.
- Embedded Markdown posts and the about page.
- Plain embedded CSS with no CSS toolchain.
- Negotiated zstd response compression with Brotli fallback.
- Task for development and verification.
- NATS, JetStream, NATSrpc, SQLite CQRS, and compressed SSE when the first real
  interactive feature is added.

The immediate product is deliberately small:

```text
GET /                 Most recent post
GET /blog             Post list
GET /blog/{slug}      Post detail
GET /about            About page
GET /feed.xml         RSS feed
GET /rss.xml          Compatibility redirect/alias
GET /sitemap.xml      Sitemap
GET /robots.txt       Crawler policy
GET /static/*         Fingerprinted embedded assets
GET /healthz          Liveness
GET /readyz           Readiness
```

There is no demo catalog or sample potion/hello feature in this milestone. Demo
architecture should be introduced by the first real demo rather than by
placeholder packages or invented product behavior.

## 2. Starting repository assessment

At the start of this implementation, useful migration work already existed:

- A thin Go executable, basic application lifecycle, embedded assets, Templ,
  and a vendored Datastar client.
- Markdown posts and the about page are already under `content`.
- Task, Air, Nix, Terraform, Caddy, systemd, and SSH deployment scaffolding.
- Existing fonts, images, and favicon.

The main gaps are:

- `http.ServeMux` is still used instead of Chi.
- `internal/config` and `internal/httpx` are empty.
- The current home resource is a temporary hello interaction.
- Content is not actually embedded or loaded.
- There are no blog/about/feed/sitemap handlers.
- `site.css` is empty.
- Compression currently belongs to Caddy, so the Go origin is inconsistent.
- There are no current Go tests.
- Application cancellation and shutdown do not yet meet the specification.
- README/operations text still describes the former static deployment.

The previous blog implementation is reference material only. Do not port its
book layout, navigation JavaScript, templates, or design system.

## 3. Decisions

### 3.1 Datastar versions

The Datastar browser client and Go SDK are independently versioned. Do not force
matching version numbers. Pin each dependency independently, record where the
vendored browser file came from, and test the event protocol/features actually
used by the site.

The shared document may load the vendored client now, but do not create an
interaction merely to prove it is present.

### 3.2 Compression and caching

Go owns content encoding so direct-origin, Caddy, and production behavior begin
from the same implementation.

- Prefer zstd when the client advertises it.
- Use Brotli as the compatibility fallback.
- Use identity only when negotiation requires it or the response is not worth
  encoding, such as an already-compressed image/font or an empty response.
- Set `Vary: Accept-Encoding` correctly.
- Never apply more than one content-encoding layer.
- Remove Caddy's `encode` directive after origin compression tests pass.

Cache policy is separate from compression:

- Fingerprinted static assets: `public, max-age=31536000, immutable` plus ETag.
- HTML blog/about documents: public, short browser cache and longer shared-cache
  lifetime, with revalidation/stale directives.
- Feed, sitemap, and robots: public cache with an explicit shorter lifetime.
- Health/readiness: `no-store`.
- Future SSE: `no-cache, no-store, no-transform`; SSE is compressed and flushed,
  but never cached.

When SSE is introduced, construct it through a single `httpx` helper using the
Datastar SDK's compression support with zstd then Brotli. Test first-event and
incremental delivery through Go, Caddy, and Cloudflare before calling it done.

### 3.3 Markdown scope

Use Goldmark as a conventional Markdown renderer only. Support ordinary
headings, links, lists, blockquotes, code, images, and common Markdown used by
current posts.
Raw HTML remains disabled unless a concrete authored page demonstrates a need
and receives a narrowly tested policy.

Do not implement book/spread/page markers, custom layout parsing, client-side
navigation, or the previous blog's presentation. Existing layout comments are
ignored and the affected post renders as a normal linear article.

### 3.4 SQLite and WAL

Do not open SQLite or create persistence packages until a real dynamic feature
needs state.

WAL is primarily a concurrency choice, not a blanket read-speed optimization.
It allows readers to continue while a writer commits and usually improves a
read-heavy interactive workload with SSE subscribers. It also creates WAL/SHM
files and affects backup/checkpoint operations. For the first SQLite feature:

1. Start with one database file and explicit command/query APIs.
2. Exercise representative concurrent command and query tests/benchmarks.
3. Enable WAL if readers and the writer would otherwise block each other, which
   is likely for a live CQRS feature.
4. Document checkpoint and backup behavior when WAL is enabled.

Use separate read and write handles/pools only when that feature exists. CQRS
means separate behavior and APIs over one database, not speculative empty
infrastructure.

### 3.5 NATS and NATSrpc

Do not connect to NATS, create JetStream streams, or generate NATSrpc services
until a real demo defines commands, queries, and events. Without a feature,
those resources would be unused architecture placeholders.

When the first demo is added:

- Add the external loopback-only NATS service and `internal/natsx` lifecycle.
- Keep feature command/query/event/subject definitions in that feature.
- Use generated NATSrpc only for a real service boundary and pin its generator.
- Use JetStream only where acknowledgement/replay/retention is meaningful.
- Add a transactional SQLite outbox if a committed write must reliably publish
  an event.
- Have persistent subscribers query current state and fat-morph one complete
  stable resource fragment; never publish HTML through NATS.
- Subscribe before taking the initial snapshot, serialize SSE writes, heartbeat,
  reconstruct after reconnect, and unsubscribe on request cancellation.

This preserves the requested destination without manufacturing a tutorial demo
that the site does not need.

## 4. Immediate implementation

### Phase 1 — Process, config, Chi, and shared HTTP behavior

**Files:** `cmd/wlls`, `internal/config`, `internal/app`, `internal/httpx`,
`internal/health`

1. Centralize environment loading and validation in `config`.
2. Pass a configured `slog.Logger` and validated config into
   `app.New(ctx, cfg, logger)`.
3. Compose routes with Chi.
4. Use `http.Server.BaseContext`, no global write timeout, and cancellation-safe
   graceful shutdown.
5. Add request logging, panic recovery, buffered Templ rendering, cache helpers,
   consistent errors, and negotiated zstd/Brotli middleware.
6. Add liveness and readiness. At this stage readiness means startup content and
   HTTP composition succeeded; later features add dependency checks.

**Exit:** invalid config fails before listening, request contexts cancel during
shutdown, and route/middleware tests pass.

### Phase 2 — Embedded assets, minimal shared shell, and CSS

**Files:** `internal/assets`, `internal/site`

1. Construct an asset manifest from `embed.FS` at startup.
2. Generate a content fingerprint and serve assets below the fingerprinted URL.
3. Apply immutable caching only to fingerprinted paths and retain short-lived
   compatibility paths for existing images/fonts/favicon URLs.
4. Create a small semantic Templ document with metadata, canonical URL,
   navigation, footer, CSS, and local Datastar module references.
5. Write a new minimal `site.css`; do not restore the old stylesheets or add a
   CSS build step.

**Exit:** all documents share the shell, assets have correct media/cache headers,
and the site remains usable without JavaScript.

### Phase 3 — Minimal blog and about page

**Files:** `content`, `internal/blog`, `internal/about`, `internal/app`

1. Embed `posts/*.md` and `pages/*.md` from the root `content` package.
2. Parse required post metadata (`title`, `description`, `date`) and optional
   topic/draft metadata. Derive and validate slugs from filenames.
3. Render straightforward Markdown at startup and build an immutable newest-first
   post index. Duplicate slugs or invalid published metadata fail startup.
4. Render the newest post at `/`, the post list at `/blog`, and detail documents
   at `/blog/{slug}`.
5. Render `content/pages/about.md` at `/about`.
6. Generate RSS, sitemap, and robots resources from the immutable repository.
7. Keep `/rss.xml` and legacy static media URLs compatible. Do not recreate
   `/resume` unless new resume content is intentionally added.
8. Use the same article component for `/` and post details; keep the initial
   design readable and intentionally sparse.

**Exit:** all authored content loads at startup, routes and XML are tested,
missing slugs return a shared 404, and no blog request depends on Datastar,
SQLite, or NATS.

### Phase 4 — Task, development, and deployment cleanup

**Files:** `Taskfile.yml`, `.air.toml`, `go.mod`, `flake.nix`, `deploy`, `README.md`,
`docs/operations.md`

1. Keep the required Task commands and use `go tool task` for nested calls.
2. Ensure Go, Templ, CSS, JavaScript, and Markdown changes rebuild without a
   generated-file loop.
3. Keep generation, vet, race tests, and build in `check`.
4. Package the new Go application with Caddy in Nix.
5. Remove Caddy response encoding once Go compression is verified.
6. Validate staged Caddy configuration before promotion, use reload rather than
   restart, and roll runtime/config back together on failure.
7. Update README and operations docs to describe the actual Go-rendered site,
   caching, compression, and commands. Do not document deferred NATS/SQLite
   resources as implemented.

**Exit:** `go tool task check` passes from a clean checkout and local Caddy serves
cached, compressed documents/assets correctly.

## 5. Deferred first-demo implementation

When a real demo is designed, add one cohesive feature package directly at its
final location. That change should introduce, together:

1. SQLite schema/migrations and separate command/query stores over one file.
2. The WAL decision backed by concurrent workload evidence.
3. External NATS lifecycle, JetStream configuration, and readiness reporting.
4. Feature-owned protobuf/NATSrpc command and query services.
5. Feature events and, if reliability is required, a transactional outbox.
6. A normal HTML initial document and compressed, non-cacheable Datastar SSE.
7. Fat outer morphing of a stable complete feature fragment.
8. Embedded-NATS integration tests, SQLite tests, reconnect reconstruction,
   heartbeat/cancellation tests, and zstd/Brotli incremental compression tests.
9. Production NATS systemd/Nix/deployment configuration.

No generic demo framework is required before then. A small catalog may be added
when there are enough real demos to catalog.

## 6. Immediate test map

| Area | Proof |
| --- | --- |
| Config | defaults and invalid address/base URL/duration |
| App | route matrix, methods, request cancellation, graceful shutdown behavior |
| HTTP | buffered render failures, recovery, cache headers, content types |
| Compression | zstd preference, Brotli fallback, identity, one encoding, decoded integrity |
| Assets | stable fingerprint, ETag, immutable fingerprinted cache, legacy media paths |
| Content | `fstest.MapFS`, metadata errors, duplicate/invalid slugs, ordering, drafts |
| Markdown | ordinary semantic output and disabled raw HTML |
| Blog | latest post at `/`, list, detail, shared 404, semantic article markup |
| Discovery | escaped feed, sitemap URLs/dates, robots, `/rss.xml` compatibility |

## 7. Completion criteria for this milestone

- `cmd/wlls` owns only process entry-point concerns.
- Config is loaded and validated once.
- `app` is the composition root and cancels HTTP/SSE-capable request contexts on
  shutdown.
- Chi owns route composition.
- All documents use shared Templ components and new plain CSS.
- Static assets are embedded, fingerprinted, cached, and served locally.
- HTML documents have an explicit public cache policy.
- Health/readiness and future SSE responses are not cacheable.
- Eligible origin responses prefer zstd and fall back to Brotli.
- The latest post is `/`; `/blog`, `/blog/{slug}`, and `/about` are complete.
- Markdown is simple and has no book-layout behavior.
- No fake demos or unused SQLite/NATS/NATSrpc packages exist.
- README and operations documentation describe only implemented behavior.
- `go tool task check` passes.
