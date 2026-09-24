# wlls.dev

Personal site and blog in the process of moving to Odin, Tina, and Datastar.
This branch currently renders a small homepage and a template preview with
Odin, Tina HTTP, and Tempo; the Markdown blog and lab will be restored in
subsequent steps.

## Development

Enter the Nix shell with `direnv allow` (or `nix develop`). `flake.lock` pins
the development toolchain to a revision compatible with the vendored Tina.
Then:

```sh
just run             # build and listen on 127.0.0.1:8080
just check           # generate views, check Odin and test components
just build           # write bin/wlls
just generate        # compile authored src/views/*.templ to Odin
```

Local and release builds listen on 8080. If the port is already occupied,
`just run` reports the process using it before starting Tina.

The local build enables Tina's internal assertions. Bounds checks stay enabled
in both development and production. Author HTML components in
`src/views/*.templ`; `just` and Nix regenerate them before compilation.
See [`docs/templating.md`](docs/templating.md) for the authoring model and the
Tina/Datastar rendering boundary.

To exercise the local reverse proxy, run `just run` and, in another terminal:

```sh
caddy run --config deploy/Caddyfile
curl --fail http://localhost:3000/healthz
```

## Release builds

```sh
nix build .#wlls --no-link
nix build .#runtime-linux-amd64 --no-link
```

The runtime contains the Odin application and Caddy. Nix builds the Linux AMD64
object using the pinned native Odin compiler, then links it with the Nix Linux
cross-toolchain; Odin cannot directly cross-link macOS to Linux. The resulting
release runs behind Caddy on the DigitalOcean Droplet. See
[`deploy/README.md`](deploy/README.md) for deployment details.

The application binds to loopback only. `/healthz` and `/readyz` return
uncacheable health responses. `/` is the temporary homepage;
`/template-preview` shows the article layout; its button patches the same
article component through Tina's Datastar SSE SDK.
