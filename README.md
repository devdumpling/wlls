# wlls.dev

Personal site and blog in the process of moving to Odin, Tina, and Datastar.
This branch currently serves a small, self-contained HTML page with Tina HTTP;
the Markdown blog and lab will be restored in subsequent steps.

## Development

Enter the Nix shell with `direnv allow` (or `nix develop`). `flake.lock` pins
the development toolchain to a revision compatible with the vendored Tina.
Then:

```sh
just run             # build and listen on 127.0.0.1:8080
just check           # check and vet application code
just build           # write bin/wlls
```

Local and release builds listen on 8080. If the port is already occupied,
`just run` reports the process using it before starting Tina.

The local build enables Tina's internal assertions. Bounds checks stay enabled
in both development and production. The HTML file is embedded at compile time,
so run the binary from any working directory; rebuild after editing
`src/static/index.html`.

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
uncacheable health responses; `/` serves the embedded placeholder document.
