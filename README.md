<img src="static/images/avatars/dev.webp" alt="pixelated avatar" width="64" align="left" />

# wlls.dev

Personal site and blog. Writing about software, games, craft, and whatever else stays interesting.

**[about](https://wlls.dev/about)** · **[linkedin](https://www.linkedin.com/in/devon-a-wells/)** · **[bluesky](https://bsky.app/profile/wlls.dev)**

## Stack

|            |                                  |
| ---------- | -------------------------------- |
| Tooling    | Deno                             |
| Rendering  | Handcrafted static HTML          |
| Client     | Web platform JavaScript          |
| Deployment | Cloudflare Workers Static Assets |
| Content    | Markdown and `@deno/gfm`         |
| Styling    | Raw CSS with OKLCH colors        |

## Development

```bash
deno install --allow-scripts=npm:workerd
deno run -A @playwright/test install chromium
deno task dev
```

Development mode rebuilds on changes and reloads connected browsers over a local SSE endpoint.

Before shipping:

```bash
deno task check
deno task test
```

The production build is written to `build/`. It contains complete HTML for every page, one fingerprinted stylesheet, and one small fingerprinted JavaScript module. Cloudflare serves the directory directly; there is no request-time application runtime.

## Navigation

Every route is an ordinary HTML document and every link works without JavaScript. Supporting browsers progressively enhance same-origin navigation with the Navigation API:

- Documents are fetched when intent is expressed through hover, focus, or touch.
- Page content, metadata, and navigation state are replaced without discarding the document.
- Browser history, default scrolling, focus reset, and View Transitions use platform APIs.
- Browsers without the Navigation API use speculation rules or link prefetching before normal navigation.

## Writing

Create `posts/my-post.md` with this frontmatter:

```markdown
---
title: "My post"
description: "A short summary."
date: "2026-07-22"
topic: "Engineering"
---

Start writing here.
```

The filename becomes the URL at `/blog/my-post`. Dates must use `YYYY-MM-DD`. Every post appears on the homepage in reverse chronological order.

Posts support GitHub-flavored Markdown, fenced code, footnotes, alerts, tables, and sanitized inline HTML. The content pipeline fails the build when metadata or composed layouts are invalid.

### Book layout

Long-form posts can opt into explicitly composed page spreads with `layout: book`. Book posts use invisible comments to preserve ordinary Markdown source:

```markdown
<!-- spread -->

Left page content.

<!-- page -->

Right page content.

<!-- plate -->

Full-width code, image, or table content.
```

Every book post must begin with `<!-- spread -->`. A spread may contain one `<!-- page -->`; plates continue until the next spread or plate marker. On narrow, short, zoomed, or overflowing layouts, pages return to normal vertical flow.

## Deployment

```bash
deno task build
deno task deploy
```

`wrangler.jsonc` intentionally has no Worker entrypoint or bindings. Preview deployments should be validated before assigning the production custom domain.
