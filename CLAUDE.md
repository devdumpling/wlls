# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Deno-based monorepo for building applications with SvelteKit. Currently focused on migrating an existing Astro blog to SvelteKit + Deno with a minimal, readable, coding-oriented design.

### Philosophy

Build great apps with modern tools while maintaining simplicity. SvelteKit provides an excellent foundation for fast, interactive applications. Deno provides a clean runtime with built-in tooling. The monorepo structure allows building multiple apps and experiments while keeping shared tooling and libraries organized.

Stay minimal—question dependencies, write clean code, and let the architecture emerge organically from actual needs.

## Development Commands

### Workspace (Root)

```bash
deno task dev:blog     # Run development server (proxies to main blog app)
deno task test         # Run tests across all workspaces
deno task lint         # Lint all workspaces
deno task format       # Format all workspaces
```

### Individual Apps

```bash
cd apps/<app-name>
deno task dev      # Start dev server for specific app
deno task build    # Build for production
deno task deploy   # Deploy to Deno Deploy (or other platform)
```

### Platform & Libraries

```bash
cd platform/<tool-name>  # Build tools, scripts, configs
cd libs/<lib-name>       # Shared libraries and packages
```

## Architecture

### Monorepo Structure

```
/
├── deno.json              # Workspace configuration
├── CLAUDE.md              # This file
│
├── apps/                  # Applications (created as needed)
│   └── astro-temp/        # Existing Astro blog (temporary)
│
├── platform/              # Tooling, configs, scripts (created as needed)
│   └── ...                # Build tools, deployment scripts, etc.
│
└── libs/                  # Shared libraries (created as needed)
    └── ...                # Reusable packages, utilities, etc.
```

**Architecture Philosophy:**

- **Start minimal**: Create directories and packages only when actually needed
- **Don't overindex**: Avoid premature abstraction or over-organization
- **Organic growth**: Let patterns emerge naturally from actual requirements
- **Clear boundaries**: apps/ for runnable applications, platform/ for tooling, libs/ for shared code

### Technology Stack

**Core:**

- **Runtime**: Deno 2.5+
- **Framework**: SvelteKit
- **Deployment**: Deno Deploy (primary), Cloudflare (mabybe future option)
- **Testing**: Deno built-in test runner
- **Formatting/Linting**: Deno built-in tools
- **Content**: Markdown-based
- **Styling**: Minimal CSS (vanilla or lightweight approach)

### Design Philosophy

- **Minimal**: Strip away unnecessary complexity, question every dependency
- **Readable**: Typography and layout optimized for reading code and prose
- **Coding-oriented**: Designed for technical writing with excellent code highlighting
- **Fast**: Performance as a feature, leverage SvelteKit's SSR and routing
- **Accessible**: Keyboard navigation, semantic HTML
- **Modern**: Use SvelteKit's best practices and Svelte 5 features

## Migration Plan

### Phase 1: Monorepo Setup

**Goal**: Get basic Deno workspace configured

- [x] Create workspace deno.json with apps/, platform/, libs/ structure
- [x] Set up root-level tasks (dev, test, lint, format)
- [x] Move existing Astro app to tmp
- [x] Verify existing app still runs from new location

### Phase 2: SvelteKit Bootstrap

**Goal**: Create new SvelteKit app with Deno

- [x] Initialize new SvelteKit app in apps/blog/
- [x] Configure SvelteKit to work with Deno
- [x] Set up basic routing structure
- [ ] Add Deno Deploy configuration
- [ ] Get hello world deployed to Deno Deploy

### Phase 3: Content Migration

**Goal**: Move content and features from Astro to SvelteKit

- [ ] Set up markdown processing in SvelteKit
- [ ] Migrate blog posts and content
- [ ] Implement minimal styling (typography-focused)
- [ ] Add code syntax highlighting
- [ ] Migrate any other essential features

### Phase 4: Polish & Launch

**Goal**: Make it production-ready

- [ ] Performance optimization
- [ ] Accessibility checks
- [ ] SEO metadata
- [ ] Deploy to production
- [ ] Archive or remove apps/astro-temp/

## Important Notes

1. **Migration approach**: Keep Astro app temporarily in apps/astro-temp/ while building SvelteKit version
2. **Minimal dependencies**: Question every package addition, lean on Deno and SvelteKit built-ins
3. **Testing**: Use Deno's built-in test runner for all tests
4. **Minimal styling**: Focus on typography and readability, avoid heavy CSS frameworks
5. **Content format**: Markdown-based content with good code highlighting
6. **Monorepo hygiene**: Only create platform/ and libs/ directories when actually needed

When making changes:

- **Write clean code**: Modular, well-tested, documented
- **Prioritize readability**: Code and prose should be easy to read
- **Progressive enhancement**: JavaScript as enhancement, not requirement
- **Question abstractions**: Don't create shared packages until patterns emerge
- **Use modern features**: Leverage Svelte 5 runes and SvelteKit best practices

## References

- Deno: https://docs.deno.com/runtime/
- SvelteKit: https://kit.svelte.dev/docs
- Svelte: https://svelte.dev/docs
- Deno Deploy: https://docs.deno.com/deploy/manual/
