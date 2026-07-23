# wlls.dev

Personal blog built with Deno, Fresh, Markdown, and raw CSS. It is deployed to Deno Deploy.

## Commands

```bash
deno task dev      # Fresh development server
deno task check    # Format, lint, and type checks
deno task test     # Deno tests with narrow env permissions
deno task build    # Production Fresh build
deno task start    # Serve the production build
```

## Architecture

- `posts/` contains ordinary Markdown posts. A filename is the `/blog/:slug` route.
- `lib/content.ts` is the single content pipeline for validation, rendering, sorting, and reading time.
- `routes/` contains Fresh file routes. Keep normal pages server-rendered.
- `islands/` is only for behavior that cannot be expressed with HTML and CSS.
- `assets/styles.css` is the complete visual system. Do not introduce CSS tooling or frameworks.
- `static/` contains URL-addressed images, icons, and crawler files.

## Principles

- Ask before adding any dependency.
- Prefer Deno and web platform APIs over packages.
- Keep authored content in Markdown. Use a dedicated TSX route only when a page truly needs enhanced behavior.
- Keep article pages functional without client JavaScript.
- Prefer semantic HTML, progressive enhancement, and native browser controls.
- Optimize for reading: stable layout, restrained motion, clear links, accessible typography, and useful print output.
- Avoid abstractions until repeated requirements make them necessary.

## Content Metadata

Posts require `title`, `description`, and an ISO `date` in `YYYY-MM-DD` format. `topic` and `archive` are optional. The content loader fails fast on invalid metadata.

## Dependencies

The approved dependency surface is Fresh/Preact/Vite, `@std/front-matter`, and `@deno/gfm`. Do not expand it without explicit approval.
