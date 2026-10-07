# wlls.dev

Personal site and blog moving to Odin, Tina, and Datastar.

Odin service renders pages from Tempo with some custom markdown parsing.

## Development

Enter the Nix shell with `direnv allow` (or `nix develop`). `flake.lock` pins
the development toolchain to a revision compatible with the vendored Tina.
Then:

```sh
just run             # build and listen on 127.0.0.1:8080
just check           # generate views, vet Odin, run every package's tests
just build           # write bin/wlls
just generate        # compile authored src/views/*.templ to Odin
just format          # format authored Odin files with odinfmt on PATH
just resume-pdf      # print /resume to content/pages/resume.pdf with Chrome
```

Local and release builds listen on 8080.

The local build enables Tina's internal assertions. Bounds checks stay enabled
in both development and production. Nix pins the cmark-gfm Markdown parser
alongside the Odin/Tempo toolchain. Author HTML components in
`src/views/*.templ` and posts in `content/posts/*.md`.

The resume is `content/pages/resume.md`, ordinary Markdown with a light
structure (see `src/content/resume.odin`). After editing it, run
`just resume-pdf` to print the committed PDF again; `just check` fails until
you do. Chrome comes from `$CHROME`, or the macOS app by default.

`just` and Nix regenerate the components before compilation and embed the content and assets into the binary.

> See [`docs/templating.md`](docs/templating.md) for the authoring model and the
> Tina/Datastar rendering boundary.

To use the local reverse proxy, run `just run` and, in another terminal:

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

The application binds to loopback only; Caddy provides compression and the
public HTTPS endpoint. `/` is a dedicated homepage;
`/blog` lists all posts, `/blog/{slug}` serves each post,
`/about` serves about, and `/resume` serves the resume (also as
`/resume.md` and `/resume.pdf`). `POST /terminal` answers the
terminal with Datastar SSE patches. `/feed.xml`, `/sitemap.xml`, and
`/robots.txt` provide discovery; `/rss.xml` redirects to the feed. CSS,
browser code, fonts, and images are embedded, including legacy `/images/*`,
`/fonts/*`, and `/favicon.svg` paths. `/healthz` and `/readyz` return
uncacheable health responses.
