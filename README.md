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

The filename becomes the URL at `/blog/my-post`. Dates must use `YYYY-MM-DD`. Set `archive: true` only for writing that belongs in the older archive.

Posts support GitHub-flavored Markdown, fenced code, footnotes, alerts, tables, and sanitized inline HTML. Pages that need richer interaction should be explicit Fresh routes or narrowly scoped islands rather than a custom Markdown component format.
