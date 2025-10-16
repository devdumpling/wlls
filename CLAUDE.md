# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Bun-based monorepo for building applications with SvelteKit. Currently focused on migrating an existing Astro blog to SvelteKit + Bun with a minimal, readable, coding-oriented design.

### Philosophy

Build great apps with modern tools while maintaining simplicity. SvelteKit provides an excellent foundation for fast, interactive applications. Bun provides a fast runtime with excellent tooling and workspace support. The monorepo structure allows building multiple apps and experiments while keeping shared tooling and libraries organized.

Stay minimal—question dependencies, write clean code, and let the architecture emerge organically from actual needs.

## Development Commands

### Workspace (Root)

```bash
bun dev:blog        # Run development server (proxies to main blog app)
bun test            # Run tests across all workspaces
bun lint            # Lint all workspaces with Biome
bun format          # Format all workspaces with Biome
bun check           # Run both lint and format checks with Biome
```

### Individual Apps

```bash
cd apps/<app-name>
bun dev             # Start dev server for specific app
bun build           # Build for production
bun deploy          # Deploy to Cloudflare Workers
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
├── package.json           # Workspace configuration
├── bun.lockb              # Bun lockfile
├── CLAUDE.md              # This file
│
├── apps/                  # Applications (created as needed)
│   ├── blog/              # SvelteKit blog
│   └── wlls/              # Additional apps (created as needed)
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

- **Runtime**: Bun 1.3+
- **Framework**: SvelteKit
- **Deployment**: Cloudflare Workers
- **Testing**: Bun test runner
- **Formatting/Linting**: Biome
- **Content**: Markdown-based (mdsvex)
- **Styling**: Minimal CSS with oklch colors for perceptual uniformity

### Design Philosophy

- **Minimal**: Strip away unnecessary complexity, question every dependency
- **Readable**: Typography and layout optimized for reading code and prose
- **Coding-oriented**: Designed for technical writing with excellent code highlighting
- **Fast**: Performance as a feature, leverage SvelteKit's SSR and routing
- **Accessible**: Keyboard navigation, semantic HTML
- **Modern**: Use SvelteKit's best practices and Svelte 5 features

## Migration Plan

### Phase 1: Monorepo Setup

**Goal**: Get basic Bun workspace configured

- [x] Create workspace package.json with apps/, platform/, libs/ structure
- [x] Set up root-level scripts (dev, test, lint, format)
- [x] Set up Biome for formatting and linting
- [x] Install dependencies with Bun

### Phase 2: SvelteKit Bootstrap

**Goal**: Create new SvelteKit app with Bun

- [x] Initialize new SvelteKit app in apps/blog/
- [x] Configure SvelteKit with Cloudflare adapter
- [x] Set up basic routing structure
- [x] Add Cloudflare Workers configuration (wrangler.toml)
- [ ] Get hello world deployed to Cloudflare Workers

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

1. **Migration approach**: Building SvelteKit version from scratch with Bun + Cloudflare Workers
2. **Minimal dependencies**: Question every package addition, lean on Bun and SvelteKit built-ins
3. **Testing**: Use Bun's built-in test runner for all tests
4. **Minimal styling**: Focus on typography and readability, avoid heavy CSS frameworks
5. **Content format**: Markdown-based content with mdsvex and good code highlighting
6. **Monorepo hygiene**: Only create platform/ and libs/ directories when actually needed
7. **Tooling**: Biome for formatting and linting - fast and unified
8. **Colors**: Use oklch color space throughout for perceptual uniformity and better contrast

When making changes:

- **Write clean code**: Modular, well-tested, documented
- **Prioritize readability**: Code and prose should be easy to read
- **Progressive enhancement**: JavaScript as enhancement, not requirement
- **Question abstractions**: Don't create shared packages until patterns emerge
- **Use modern features**: Leverage Svelte 5 runes and SvelteKit best practices

## References

- Bun: https://bun.com/docs
- SvelteKit: https://kit.svelte.dev/docs
- Svelte: https://svelte.dev/docs
- Cloudflare Workers: https://developers.cloudflare.com/workers/
- Biome: https://biomejs.dev/
