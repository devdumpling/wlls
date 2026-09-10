<img src="internal/assets/static/images/avatars/dev.webp" alt="pixelated avatar" width="64" align="left" />

# wlls.dev

Server-rendered personal site and blog built with Go, Chi, Templ,
embedded Markdown, and plain CSS.

**[about](https://wlls.dev/about)** · **[linkedin](https://www.linkedin.com/in/devon-a-wells/)** · **[bluesky](https://bsky.app/profile/wlls.dev)**

## Development

Enter the pinned Nix development environment:

```bash
direnv allow
```

Without direnv, use `nix develop` explicitly.

Start Templ's live-reload proxy and Air:

```bash
go tool task
```

The application listens on <http://127.0.0.1:8080>; the Templ proxy opens on
<http://127.0.0.1:7331>. Go, Templ, CSS, JavaScript, Markdown, and embedded asset
changes are rebuilt automatically.

Run all local checks with:

```bash
go tool task check
```

Useful commands:

```text
go tool task dev       Live development
go tool task generate  Generate Templ Go source
go tool task build     Build ./bin/wlls
go tool task run       Build and run
go tool task debug     Run with Delve
go tool task test      Race-enabled tests
go tool task check     Generate, vet, test, and build
go tool task fmt       Format Templ and Go
go tool task tidy      Synchronize modules
go tool task deploy    Check and deploy
```

## Runtime

The Go process embeds authored Markdown, CSS, fonts, images, and the Datastar
browser module. At startup it validates and renders content into an immutable
post index. The newest post is served at `/`, the archive at `/blog`, individual
posts at `/blog/{slug}`, and the about page at `/about`.

Eligible text responses negotiate zstd compression with Brotli fallback.
Fingerprinted assets are cached immutably; HTML is cached for a short browser
lifetime and a longer shared-cache lifetime. Health endpoints are never cached.

For local reverse-proxy testing, run the application and Caddy separately:

```bash
go run ./cmd/wlls
caddy run --config deploy/Caddyfile
```

Then open <http://localhost:3000>.

SQLite, NATS, NATSrpc, and Datastar SSE will be introduced with the first real
interactive feature rather than as unused platform placeholders. See
[`docs/architecture.md`](docs/architecture.md),
