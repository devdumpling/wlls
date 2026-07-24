# wlls.dev

Handcrafted personal blog built with Deno, semantic HTML, raw CSS, and a small browser JavaScript module. Deno generates the complete static site, which Cloudflare Workers Static Assets serves without request-time Worker code.

## Commands

```bash
deno task dev        # Build, watch, serve, and live reload
deno task check      # Format, lint, and type checks
deno task test:unit  # Content, XML, and security tests
deno task build      # Generate the static site in build/
deno task test:e2e   # Playwright tests through Wrangler
deno task test       # Unit tests, build, and browser tests
deno task preview    # Serve build/ with the local Deno server
deno task deploy     # Deploy static assets with Wrangler
```

## Architecture

- `posts/` contains ordinary Markdown posts. A filename is the `/blog/:slug` route.
- `content/about.md` contains standalone non-post Markdown.
- `src/frontmatter.ts`, `src/markdown.ts`, and `src/content.ts` validate and render authored content at build time.
- `src/templates.ts` contains explicit HTML document and page templates. Keep templates semantic and specific to this site; do not grow a general component system.
- `src/build.ts` enumerates routes, fingerprints CSS and JavaScript, copies static files, and writes `build/`.
- `src/client/site.js` progressively enhances navigation through the Navigation API, intent prefetching, View Transitions, and book overflow measurement. Unsupported browsers use normal document navigation.
- `src/styles/` is the complete visual system. The build concatenates it into one fingerprinted CSS asset. Do not introduce CSS tooling or frameworks.
- `scripts/server.ts` is the development and preview file server. Development mode watches source files and provides SSE live reload.
- `static/` contains URL-addressed images, fonts, crawler files, and Cloudflare headers.
- `wrangler.jsonc` deploys `build/` as assets only. Do not add a Worker entrypoint without an explicit dynamic requirement.

## Principles

- Ask before adding any dependency.
- Prefer web platform and Deno APIs over packages where they fit cleanly.
- Keep authored content in Markdown and pages functional without client JavaScript.
- Browser enhancements must preserve normal links, direct requests, history, focus, scrolling, and no-JavaScript behavior.
- Build abstractions for this site's concrete needs. A thin router or lifecycle is acceptable when its behavior remains explicit, tested, and platform-oriented.
- Do not introduce a UI framework, virtual DOM, bundler, or generalized component model by default.
- Prefer semantic HTML, progressive enhancement, native browser controls, and useful print output.
- Optimize for reading: stable layout, restrained motion, clear links, accessible typography, and minimal payloads.
- Preserve a static deployment. Build-time work is preferred over request-time infrastructure.

## Content Metadata

Posts require `title`, `description`, and an ISO `date` in `YYYY-MM-DD` format. `topic` and `layout` are optional. Use `layout: book` only with explicitly composed spread, page, and plate markers. The build fails on invalid metadata or marker sequences.

## Dependencies

The application dependencies are `@std/front-matter` and `@deno/gfm`. Playwright is approved for browser regression tests and Wrangler for static deployment. Do not expand this surface without explicit approval.
