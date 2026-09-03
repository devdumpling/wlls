<img src="static/images/avatars/dev.webp" alt="pixelated avatar" width="64" align="left" />

# wlls.dev

Personal site and blog. Writing about software, games, craft, and whatever else stays interesting.

**[about](https://wlls.dev/about)** · **[linkedin](https://www.linkedin.com/in/devon-a-wells/)** · **[bluesky](https://bsky.app/profile/wlls.dev)**

## Nix development environment

```bash
direnv allow
```

The checked-in `.envrc` will then enter the flake automatically. Without direnv,
enter it explicitly with `nix develop`.

This provides Go, Caddy, SQLite, Terraform, direnv, and the supporting
development and deployment tools. Go application dependencies remain managed by
Go modules. Use `nix fmt flake.nix` to format the flake and `nix flake check` to
validate it.

### Go hello world

```bash
go tool templ generate
go test ./...
go run ./cmd/wlls
```

Then open <http://localhost:8080>. To exercise the local Caddy proxy, run
`caddy run --config deploy/Caddyfile` in another terminal and open
<http://localhost:3000>. The button demonstrates a Datastar SSE response, and
`/healthz` is available for process and deployment checks. `cmd/wlls` is the
thin executable entrypoint, `internal/app` composes the server and routes, and
`internal/hello` keeps the example handler and Templ views together.

The production build is written to `build/`. It contains complete HTML for every page, one fingerprinted stylesheet, and one small fingerprinted JavaScript module. Cloudflare serves the directory directly; there is no request-time application runtime.
