<img src="static/images/avatars/dev.webp" alt="pixelated avatar" width="64" align="left" />

# wlls.dev

Personal site and blog. Writing about software, games, craft, and whatever else stays interesting.

**[about](https://wlls.dev/about)** · **[linkedin](https://www.linkedin.com/in/devon-a-wells/)** · **[bluesky](https://bsky.app/profile/wlls.dev)**

## Stack

|                     |                           |
| ------------------- | ------------------------- |
| Runtime and tooling | Deno                      |
| Framework           | Fresh                     |
| Deployment          | Deno Deploy               |
| Content             | Markdown and `@deno/gfm`  |
| Styling             | Raw CSS with OKLCH colors |

## Development

```bash
deno install --allow-scripts
deno task dev
```

Before shipping:

```bash
deno task check
deno task test
deno task build
deno task start
```

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

Posts support GitHub-flavored Markdown, fenced code, footnotes, alerts, tables, and sanitized inline HTML. Pages that need richer interaction should be explicit Fresh routes or narrowly scoped islands rather than a custom Markdown component format.

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
