# wlls.dev Platform Architecture Specification

Status: Proposed implementation specification  
Audience: Implementation agents and maintainers  
Primary runtime: Go  
Primary web stack: `net/http`, Chi, Templ, Datastar  
Messaging: NATS with JetStream  
Operations: Nix, Terraform, systemd, Caddy, Cloudflare  

## 1. Purpose

Rebuild `wlls.dev` as a handmade, server-driven personal web platform rather than a conventional static-site generator or JavaScript application.

The platform must support three related goals:

1. Serve a durable, fast, Markdown-backed personal blog.
2. Host interactive Datastar demonstrations that can use NATS, JetStream, CQRS, and long-lived server-sent event streams.
3. Provide a comprehensible reference implementation for a future Handmade Hero-style course about modern web development with Go and Datastar.

The system should demonstrate modern, idiomatic Go without concealing the important mechanics behind a large framework. Architecture must remain explicit enough to teach from while being sound enough to operate on a public VPS.

This is a destination-state specification. Do not create knowingly temporary package layouts or intermediate abstractions merely to minimize the first change. Implementation may be incremental, but each increment must move directly toward the structure and boundaries described here.

## 2. Design principles

The implementation must follow these principles:

- Prefer standard-library behavior and small, intentional dependencies.
- Organize product behavior by feature rather than by technical layer.
- Keep process composition, feature behavior, and infrastructure adapters distinct.
- Use server-rendered HTML as the primary representation of application state.
- Treat Datastar morphs as representations of resources, not imperative UI instructions.
- Use CQRS where separating commands from queries clarifies a dynamic feature; do not impose it on static blog reads.
- Use NATS deliberately for messaging and real-time demonstrations; do not route ordinary blog reads through NATS.
- Preserve the compression advantages of repeated HTML-over-SSE. Datastar streams must support tuned streaming compression, with zstd preferred where negotiated.
- Make cancellation, reconnection, failure, and degraded dependencies normal design cases.
- Avoid dependency-injection frameworks, global service locators, generic `utils` packages, and speculative vendor-neutral abstractions.
- Make production behavior observable and reproducible through checked-in configuration.

## 3. Scope

### 3.1 In scope

- Go application entry point and lifecycle.
- Validated environment configuration.
- Chi route composition and middleware.
- Embedded static assets and handwritten CSS.
- Shared Templ document shell and components.
- Markdown content embedding, parsing, validation, indexing, and rendering.
- Blog index and post resources.
- Feed and discovery resources appropriate for a blog.
- First-class interactive demo catalog.
- Datastar SSE endpoints, including persistent subscriptions.
- NATS client lifecycle and JetStream access.
- Feature-owned command, query, event, and subject definitions.
- Liveness and readiness reporting.
- Local development with Task, Templ, and Air.
- VPS operation with systemd, Caddy, and an external NATS server.
- Nix-produced deployment runtime and Terraform-managed infrastructure.
- Tests for domain behavior, HTTP resources, content loading, and messaging integration.

### 3.2 Out of scope for the initial implementation

- A CMS or browser-based authoring interface.
- User accounts or authentication.
- A general-purpose application framework built on top of Datastar.
- A generic message-bus abstraction intended to replace NATS.
- A database for blog content.
- A multi-node NATS cluster.
- Implementing Axum or Odin services immediately.
- Final visual design or final blog copy.

The repository must nevertheless leave a clear boundary for future independent services written in other languages.

## 4. Target repository structure

```text
.
├── cmd/
│   └── wlls/
│       └── main.go
│
├── content/
│   ├── embed.go
│   ├── posts/
│   │   └── *.md
│   └── pages/
│       └── *.md
│
├── internal/
│   ├── app/
│   │   ├── app.go
│   │   └── routes.go
│   │
│   ├── config/
│   │   └── config.go
│   │
│   ├── assets/
│   │   ├── assets.go
│   │   └── static/
│   │       ├── css/
│   │       │   └── site.css
│   │       ├── js/
│   │       │   └── datastar.js
│   │       ├── fonts/
│   │       ├── icons/
│   │       └── images/
│   │
│   ├── httpx/
│   │   ├── errors.go
│   │   ├── middleware.go
│   │   ├── render.go
│   │   ├── responses.go
│   │   └── sse.go
│   │
│   ├── site/
│   │   ├── metadata.go
│   │   ├── document.templ
│   │   ├── head.templ
│   │   ├── header.templ
│   │   ├── footer.templ
│   │   └── components.templ
│   │
│   ├── home/
│   │   ├── handler.go
│   │   └── page.templ
│   │
│   ├── blog/
│   │   ├── post.go
│   │   ├── repository.go
│   │   ├── markdown.go
│   │   ├── handler.go
│   │   ├── routes.go
│   │   ├── feed.go
│   │   ├── index.templ
│   │   ├── post.templ
│   │   └── components.templ
│   │
│   ├── demos/
│   │   ├── catalog.go
│   │   ├── handler.go
│   │   ├── routes.go
│   │   ├── index.templ
│   │   └── hello/
│   │       ├── demo.go
│   │       ├── handler.go
│   │       ├── routes.go
│   │       └── page.templ
│   │
│   ├── natsx/
│   │   ├── client.go
│   │   ├── jetstream.go
│   │   ├── subjects.go
│   │   └── subscription.go
│   │
│   ├── health/
│   │   ├── handler.go
│   │   └── checks.go
│   │
│   └── testkit/
│       ├── nats.go
│       └── requests.go
│
├── deploy/
│   ├── deploy.sh
│   ├── Caddyfile
│   ├── nats.conf
│   └── systemd/
│       ├── wlls.service
│       ├── nats-server.service
│       └── caddy.service
│
├── infra/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── cloud-init.yaml.tftpl
│
├── docs/
│   ├── architecture.md
│   ├── operations.md
│   └── decisions/
│       ├── 0001-external-nats.md
│       └── 0002-embedded-content.md
│
├── .air.toml
├── Taskfile.yml
├── flake.nix
├── go.mod
└── go.sum
```

Generated `*_templ.go` files remain next to their source templates but are omitted above for readability.

Do not create empty placeholder packages solely to reproduce this tree. Create each listed package when implementing its defined responsibility, and place it at its final path when introduced.

## 5. Package boundaries and dependency rules

### 5.1 `cmd/wlls`

The executable entry point must remain small. It owns:

- Establishing the root signal-aware context.
- Configuring the process logger.
- Loading and validating configuration.
- Constructing the application.
- Mapping a terminal application error to process exit status.

It must not define routes, parse content, connect directly to feature stores, or contain feature behavior.

### 5.2 `internal/app`

`app` is the composition root and owner of live process resources. It may import any internal feature or infrastructure package. No other package may import `app`.

The application constructor must:

1. Receive a context, validated configuration, and logger.
2. Load and validate embedded blog content.
3. Establish the NATS connection and JetStream context.
4. Construct feature handlers and the demo catalog.
5. Compose the Chi router.
6. Construct the HTTP server.
7. Return a concrete application value that owns all resources requiring shutdown.

The application lifecycle must:

- Derive HTTP request contexts from the application context using `http.Server.BaseContext`.
- Start the HTTP listener and report unexpected listener failure.
- Cancel active request contexts, including persistent SSE handlers, during shutdown.
- Gracefully shut down HTTP within a configured deadline.
- Unsubscribe and drain NATS after HTTP handlers have stopped producing work.
- Normalize `http.ErrServerClosed` as a successful shutdown.
- Join independently occurring shutdown errors rather than silently discarding them.

Do not configure a global HTTP `WriteTimeout`; it is incompatible with intentionally long-lived SSE responses. Narrow deadlines may be applied to ordinary endpoints where appropriate.

### 5.3 `internal/config`

All environment access must be centralized here. Downstream packages must receive configuration values rather than repeatedly calling `os.Getenv`.

The target configuration shape is:

```go
type Config struct {
    Environment Environment
    HTTP        HTTP
    Site        Site
    NATS        NATS
}

type HTTP struct {
    Address         string
    ShutdownTimeout time.Duration
}

type Site struct {
    BaseURL string
}

type NATS struct {
    URL           string
    SubjectPrefix string
}
```

Expected environment variables:

```text
WLLS_ENV
WLLS_ADDR
WLLS_BASE_URL
WLLS_NATS_URL
WLLS_NATS_SUBJECT_PREFIX
```

`config.Load()` must apply documented defaults, parse typed values, validate URLs and addresses, and return errors for invalid configuration before listeners start.

### 5.4 `internal/assets`

This package owns embedded browser assets and their HTTP handler.

Requirements:

- Continue using `embed.FS`.
- Preserve handwritten CSS with no CSS build system.
- Vendor the Datastar client locally rather than depending on a public CDN at runtime.
- Serve correct content types.
- Apply explicit cache policies.
- Use versioned or content-addressed asset URLs before applying long-lived immutable caching.
- Keep asset mechanics out of feature packages.

### 5.5 `internal/httpx`

This package owns shared HTTP mechanics, not product behavior.

It should provide:

- Buffered Templ rendering so a render failure does not commit a partial document with a successful status.
- Consistent error-to-response translation.
- Request logging and recovery middleware construction.
- Cache-control helpers for static, document, dynamic, and streaming responses.
- SSE heartbeat and flush helpers where the Datastar SDK does not already provide the needed primitive.
- Origin or CSRF checks when authenticated or cookie-backed mutations are added.

It must not contain feature-specific response types or become a miscellaneous utility package.

### 5.6 `internal/site`

`site` is the shared server-rendered view system: the handmade design system for the site.

It owns:

- The HTML document shell.
- Shared metadata types and canonical URL rendering.
- Global navigation and footer.
- Shared semantic and visual components.
- Stylesheet and Datastar client references.

Feature packages may import `site`. `site` must never import `home`, `blog`, `demos`, or other product features.

Feature packages own page-specific composition and Datastar fragments.

### 5.7 `internal/home`

The home package owns the root resource and its view. It may query the blog repository for recent posts if that dependency is injected explicitly by `app`.

The package must not become an alternate site-wide composition root.

### 5.8 `internal/blog`

The blog package owns the full blog capability:

- Post metadata and domain validation.
- Embedded Markdown loading.
- Front-matter parsing.
- Markdown rendering.
- Immutable published-post indexing.
- Post lookup by slug.
- Draft filtering.
- Blog HTTP handlers and routes.
- Blog pages and components.
- RSS or Atom feed generation.
- Data needed by sitemap and discovery resources.

The repository must be constructed once during application startup. Invalid published content, duplicate slugs, malformed dates, or other invariants must fail startup rather than become request-time surprises.

The repository should have an API resembling:

```go
type Repository struct {
    // private immutable indexes
}

func Load(fsys fs.FS, renderer MarkdownRenderer) (*Repository, error)
func (r *Repository) Published() []Post
func (r *Repository) Find(slug string) (Post, error)
```

Do not add a repository interface merely for abstraction. Consumers may define narrow interfaces if testing or dependency boundaries benefit from them.

Blog reads must not depend on NATS. Blog content remains available if NATS is reconnecting or unavailable.

### 5.9 `internal/demos`

The parent demo package owns the demo catalog and mount contract. Each demo must be a cohesive feature package.

The catalog contract should resemble:

```go
type Demo struct {
    Slug        string
    Title       string
    Description string
    Handler     http.Handler
}
```

The parent router receives registered demo definitions, renders the catalog, and mounts each handler beneath its slug. The parent package must not import concrete child demos if doing so would create a package cycle; `app` performs concrete registration.

The existing hello interaction becomes `internal/demos/hello` and is mounted at `/demos/hello`. It is the first proof that the demo contract supports a full page plus Datastar mutation endpoints.

A substantial CQRS demo should remain one cohesive package with files such as:

```text
internal/demos/potions/
├── demo.go
├── model.go
├── commands.go
├── queries.go
├── events.go
├── subjects.go
├── store.go
├── handler.go
├── routes.go
├── page.templ
└── fragments.templ
```

These files are conceptual separations inside one package, not artificial deployable layers.

### 5.10 `internal/natsx`

NATS is an intentional platform dependency. Do not hide it behind a speculative vendor-neutral message-bus interface.

`natsx` owns cross-cutting NATS mechanics:

- Client creation and connection options.
- Disconnect, reconnect, discovered-server, and error callbacks.
- Initial-connect retry behavior.
- Connection draining.
- JetStream context construction.
- Shared JSON encoding and decoding mechanics.
- Subscription cleanup helpers.
- Subject-prefix validation and composition.
- Connection health reporting.

It must not own feature events or feature subject names. `PotionBrewed` and its subject belong to the potion demo.

Subject structure should follow this pattern:

```text
<application>.<environment>.<feature>.<kind>.<name>
```

For example:

```text
wlls.production.demos.potions.events.potion_brewed
```

Feature packages define the suffix; `natsx` safely applies the configured application/environment prefix.

### 5.11 `internal/health`

Expose two operational resources:

```text
GET /healthz
GET /readyz
```

`/healthz` is a minimal liveness check for the process and HTTP loop.

`/readyz` reports the state of meaningful components, including content loading and NATS connectivity. NATS failure may produce a degraded status without making static blog resources unavailable. Demo endpoints that require NATS must return a purposeful unavailable representation rather than panic or hang.

### 5.12 `internal/testkit`

Tests should normally remain beside the code they test. `testkit` is reserved for expensive fixtures reused by multiple packages, including:

- Starting and stopping an embedded NATS server for integration tests.
- Creating isolated JetStream storage directories.
- Shared HTTP request helpers where ordinary `httptest` is insufficient.

The production application must use an external NATS process. Embedded NATS is primarily a test facility.

## 6. HTTP resource model and route tree

The target route surface is:

```text
GET  /                         Home document
GET  /blog                     Published post index
GET  /blog/{slug}              Published post document
GET  /feed.xml                 Blog feed
GET  /robots.txt               Crawler policy
GET  /sitemap.xml              Site discovery

GET  /demos                    Demo catalog
GET  /demos/hello              Hello demo document
POST /demos/hello/greet        Hello Datastar action

GET  /static/*                 Embedded static assets
GET  /healthz                  Liveness
GET  /readyz                   Readiness and dependency state
```

Future demo routes remain subordinate to `/demos/{slug}`. A demo may define ordinary documents, command endpoints, and persistent event endpoints beneath its mount point.

Chi usage must remain at the HTTP boundary. Domain and event types must not depend on Chi route contexts.

## 7. Datastar and SSE requirements

### 7.1 Representation model

- Initial navigation returns normal HTML documents.
- Datastar actions return `text/event-stream` responses containing HTML or signal patches.
- A server patch should generally render the complete resource fragment at a stable DOM identity and allow Datastar to morph it.
- Event messages should cause the server to query current state and render current truth. Do not publish rendered HTML through NATS.

### 7.2 Persistent streams

Persistent handlers must:

- Subscribe before taking the initial state snapshot, or otherwise use revisions to avoid a snapshot/subscription race.
- Send the initial current representation after the subscription is established.
- Process NATS events and SSE writes from one serialized event loop; do not write concurrently to an `http.ResponseWriter`.
- Observe `r.Context().Done()` and unsubscribe immediately.
- Emit a lightweight heartbeat at an interval safely below intermediary idle/read limits when the stream may otherwise be silent.
- Reconstruct current state on reconnection rather than assuming the client observed every Core NATS event.
- Treat disconnect and reconnect as normal, tested behavior.

### 7.3 Streaming compression

Datastar event streams must be compressed when the client and active proxy path support it. zstd is preferred, with gzip as a compatibility fallback where necessary.

Compression requirements:

- Use exactly one effective content-encoding layer.
- Preserve incremental flushing; events must not wait for a large compression window or connection close before reaching the client.
- Do not globally disable compression for `text/event-stream`.
- Decide explicitly whether the Datastar Go SDK or Caddy owns stream compression.
- Ensure the other layer recognizes an existing `Content-Encoding` and does not recompress.
- Verify behavior through Caddy and Cloudflare, not only against the Go origin.
- Benchmark representative repeated Templ fragments rather than synthetic random data.

Acceptance tests must inspect negotiated `Content-Encoding`, time to first event, incremental event arrival, compression ratio, client cancellation, and behavior across a quiet heartbeat interval.

## 8. CQRS and NATS conventions

CQRS is a feature-level separation of write behavior from read behavior; it is not synonymous with NATS.

The preferred dynamic-feature flow is:

```text
HTTP command
    -> validate command
    -> update authoritative state
    -> publish feature event

SSE subscriber
    -> receive feature event
    -> query current projection
    -> render Templ fragment
    -> send Datastar morph
```

Rules:

- Commands use imperative names such as `BrewPotion`.
- Events use completed-fact names such as `PotionBrewed`.
- Queries do not mutate state.
- Core NATS may carry ephemeral invalidation or live-update events.
- JetStream is used where replay, acknowledgement, retention, or durable background processing is meaningful.
- Normal pub/sub subscriptions are used for fan-out to application instances or connected clients.
- Do not use a queue group when every subscriber must observe the update; queue groups are for competing consumers.
- If a durable database write and guaranteed event publication must become atomic, introduce a transactional outbox at that point rather than pretending a dual write is atomic.

## 9. Local development and build workflow

The checked-in Taskfile is the public developer interface.

Required commands:

```text
go tool task             Start development
go tool task dev         Start Templ proxy and Air
go tool task generate    Generate Templ Go source
go tool task build       Build ./bin/wlls
go tool task run         Build and run
go tool task debug       Run through Delve
go tool task test        Run race-enabled tests
go tool task check       Generate, vet, test, and build
go tool task fmt         Format Templ and Go source
go tool task tidy        Synchronize module metadata
go tool task deploy      Check and deploy
```

Templ, Air, Delve, and Task should be declared as Go tools and invoked through `go tool`.

Development requirements:

- Templ provides its live-reload proxy.
- Air rebuilds and restarts the Go process.
- Changes to Go, Templ, CSS, JavaScript, Markdown, and embedded assets become visible without manual build orchestration.
- Generated Templ output must not cause a rebuild loop.
- Local NATS runs as a separate process for production parity, started by the development task or the Nix development environment.
- The NATS client tolerates the web process racing NATS startup by using bounded initial-connect retry behavior.

## 10. Production topology

The initial production topology is one DigitalOcean VPS:

```text
Internet
    -> Cloudflare proxy and DNS
    -> Caddy :443/:80
    -> wlls 127.0.0.1:8080
    -> NATS 127.0.0.1:4222

NATS monitoring: 127.0.0.1:8222, if enabled
JetStream state: /var/lib/nats/jetstream
```

Requirements:

- Only Caddy accepts public HTTP traffic.
- The Go application and NATS bind to loopback.
- NATS monitoring is never exposed publicly.
- Caddy handles TLS and reverse proxying.
- Cloudflare remains the authoritative DNS provider and proxy for web records; email records remain independent DNS records.
- Cloudflare SSL mode uses end-to-end certificate validation.
- Persistent streams send heartbeats and are reconnection-safe.
- Caddy configuration and version must support verified streaming compression.

## 11. systemd ownership

Run three independent services:

- `wlls.service`
- `nats-server.service`
- `caddy.service`

The NATS server must not be embedded in the production web process.

`wlls.service` may declare `Wants=nats-server.service` and order itself after NATS, but ordinary blog availability must not rely on permanently healthy NATS connectivity. Runtime disconnects must be represented as degraded demo capability.

NATS must run as an unprivileged user with a systemd-managed state directory. JetStream storage must live outside the deployed Nix store path.

Application deployment should not restart NATS unless its binary or configuration changed. Caddy should be validated before promotion and reloaded rather than restarted where possible so deployments do not unnecessarily sever active streams.

## 12. Deployment requirements

Retain the current Nix-closure-over-SSH deployment model, with the following improvements:

- Build a Linux AMD64 runtime reproducibly.
- Copy the closure to the VPS using the configured deploy identity.
- Stage uploaded service configuration in a unique temporary directory.
- Validate the staged Caddyfile before replacing the active file.
- Validate NATS configuration before replacing the active file.
- Promote runtime and configuration only after validation.
- Health-check the new web process locally through its loopback address.
- Verify public-path behavior separately when appropriate.
- Roll back the application runtime and promoted configuration as one release unit when activation fails.
- Reload Caddy instead of restarting it when supported.
- Avoid restarting unchanged infrastructure services.
- Keep temporary-directory deletion narrowly scoped to the validated deployment staging path.

## 13. Future independent services

Go demos compiled into the main `wlls` binary belong beneath `internal/demos`.

When a demo becomes a separate deployable process, especially in another language, introduce:

```text
services/
├── <axum-service>/
└── <odin-service>/
```

Each service owns its language-specific build and source layout. Caddy routes it by path or subdomain, and it may connect to the loopback NATS server.

When NATS messages cross language or process ownership boundaries, introduce explicit language-neutral contracts:

```text
contracts/
└── nats/
    ├── subjects.md
    └── schemas/
        └── <event>.schema.json
```

Do not create `services` or `contracts` as empty architecture placeholders. Add them when the first independent process or cross-language contract exists.

## 14. Testing requirements

### 14.1 Content

- Load representative posts from `fstest.MapFS`.
- Reject duplicate slugs and invalid published metadata.
- Verify chronological ordering and draft filtering.
- Verify Markdown rendering and intentional raw-HTML policy.
- Verify missing slugs map to `404 Not Found`.

### 14.2 HTTP

- Exercise routes using `httptest`.
- Verify status, content type, cache policy, and important semantic markup.
- Verify rendering errors do not leave a committed successful response.
- Verify unsupported methods receive appropriate responses.

### 14.3 NATS and CQRS

- Start an isolated embedded NATS server through `testkit`.
- Use an isolated temporary JetStream store.
- Verify publish/subscribe behavior and cleanup.
- Verify reconnect-safe reconstruction of current state.
- Verify that fan-out subscriptions do not accidentally use queue groups.
- Run relevant tests with the race detector.

### 14.4 SSE and compression

- Verify one-shot Datastar patches.
- Verify persistent stream cancellation.
- Verify heartbeat delivery.
- Verify event writes are serialized.
- Verify negotiated zstd or fallback encoding.
- Verify multiple events arrive incrementally before the response closes.
- Include an end-to-end smoke test through Caddy; production verification should also exercise the Cloudflare path.

## 15. Documentation requirements

The repository should explain itself without requiring this specification to remain in an agent prompt.

Maintain:

- `README.md`: setup, core commands, and high-level purpose.
- `docs/architecture.md`: current components, dependencies, and request/event flows.
- `docs/operations.md`: deployment, service inspection, rollback, NATS inspection, and recovery.
- `docs/decisions/*`: short decision records for choices with meaningful alternatives.

Documentation must describe actual implemented behavior. Do not document aspirational components as if they already exist.

## 16. Implementation sequence

Implementation may be divided into reviewable changes, but each change must use final package locations and contracts.

Recommended order:

1. Establish configuration, logging, application composition, Chi routing, and cancellation-safe HTTP lifecycle.
2. Establish `site`, `httpx`, home, embedded assets, and the shared document shell.
3. Implement the embedded Markdown blog repository, blog resources, feed, and discovery endpoints.
4. Establish the demo catalog and move the hello interaction into `demos/hello`.
5. Add the external NATS service, `natsx` client lifecycle, readiness reporting, and integration-test fixture.
6. Implement one real CQRS demonstration end to end.
7. Add persistent NATS-to-Datastar streaming with heartbeat, reconnection behavior, and serialized writes.
8. Enable and tune streaming zstd compression through the full Caddy and Cloudflare path.
9. Harden deployment promotion, validation, reload, rollback, service isolation, and operational documentation.

## 17. Acceptance criteria

The architecture is successfully established when all of the following are true:

- `cmd/wlls` contains only process entry-point responsibilities.
- Configuration is parsed and validated once before application startup.
- `app` is the only composition root and owns shutdown of HTTP and NATS resources.
- All HTTP request contexts, including persistent SSE handlers, are canceled during graceful shutdown.
- The site renders through shared Templ document components and handwritten embedded CSS.
- Blog posts are embedded, validated at startup, indexed immutably, and served without NATS.
- The demo catalog mounts self-contained feature packages beneath `/demos`.
- The hello Datastar interaction exists as a demo rather than masquerading as the home feature.
- NATS runs as an external loopback-only systemd service in production.
- `natsx` owns infrastructure mechanics while features own their events and subjects.
- At least one demonstration has visibly separate commands, queries, events, and rendered projections.
- Persistent SSE streams reconstruct state on connection, handle cancellation, send heartbeats, and serialize writes.
- Datastar SSE is compressed with negotiated streaming zstd where supported and has verified incremental delivery through Caddy and Cloudflare.
- Health endpoints distinguish liveness from dependency degradation.
- `go tool task check` generates, vets, race-tests, and builds successfully.
- Deployment validates configuration before promotion and can restore the previous working release on failure.
- The repository documentation accurately explains development, architecture, messaging, and operations.

## 18. Agent implementation constraints

An implementation agent working from this specification must:

- Inspect the existing repository before editing and preserve unrelated user changes.
- Prefer moving and adapting working code over rewriting it without reason.
- Work in reviewable increments and run the relevant checks after each increment.
- Avoid adding dependencies unless they directly implement a stated requirement.
- Avoid generic abstractions introduced solely for possible future replacement.
- Keep domain and event names explicit even when this produces a small amount of repetition.
- Preserve SSE compression as a first-class performance requirement.
- Not expose NATS or its monitoring endpoint publicly.
- Not silently change existing public blog URLs without providing redirects.
- Not claim completion while acceptance criteria relevant to the implemented phase are unverified.

