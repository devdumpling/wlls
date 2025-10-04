# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a monorepo containing two parallel blog/portfolio projects with a minimal, readable, coding-oriented design:

1. **apps/blog** - Production blog (Deno + Fresh, deployed to Deno Deploy)
2. **apps/wlls** - 6-month experimental project (Deno + Vite + custom framework)

Both projects prioritize readability and functionality, exploring different technical constraints and approaches.

### Philosophy

This project is fundamentally about exploration through constraints. By limiting myself to Deno + Vite and building a framework from scratch, I'm creating space to deeply experiment with emerging frontend paradigms. I'm particularly interested in resumability (picking up where SSR left off without re-executing), compiler-driven optimizations (shifting work from runtime to build time), and local-first architectures (while maintaining excellent first-load performance). The constraints aren't arbitrary limitations—they're guardrails that force creative problem-solving and deeper understanding. This is as much about the joy of building within boundaries as it is about discovering whether these new ideas can coexist: can we have resumability and simplicity? Can we be local-first without sacrificing performance? The six-month timeline and dual-blog approach let me explore these questions while maintaining a production site for documenting the journey.

## Development Commands

### Workspace (Root)
```bash
deno task dev          # Run development server for apps/blog
deno task dev:wlls     # Run development server for apps/wlls
deno task dev:docs     # Run development server for apps/docs
deno task test         # Run tests across all workspaces
deno task lint         # Lint all workspaces
deno task format       # Format all workspaces
```

### apps/blog (Legacy - Fresh)
```bash
cd apps/blog
deno task dev      # Start Fresh dev server
deno task build    # Build for production
deno task deploy   # Deploy to Deno Deploy
```

### apps/wlls (New - Custom Framework)
```bash
cd apps/wlls
deno task dev      # Start custom dev server
deno task build    # Build for production
deno task deploy   # Deploy (TBD)
```

### packages/core (Framework Development)
```bash
cd packages/core
deno task test     # Run framework tests
deno task build    # Build core packages
```

## Architecture

### Monorepo Structure

```
/
├── deno.json              # Workspace configuration
│
├── apps/                  # Application layer
│   ├── docs/              # Documentation site
│   ├── blog/              # Legacy blog (Fresh migration)
│   └── wlls/              # New custom framework blog
│
├── packages/              # Shared packages (TBD - created as needed)
│   └── ...                # plat, core, feat packages emerge organically
│
└── CLAUDE.md              # This file
```

**Package layer philosophy:**
- Start simple, extract packages only when patterns emerge
- Likely layers: plat (tools/scripts), core (framework), feat (UI/business logic)
- Let architecture evolve based on actual needs

### Technology Stack

#### current-blog (Production)
- **Framework**: Fresh (Preact-based)
- **Runtime**: Deno
- **Styling**: Minimal CSS (TBD - likely vanilla CSS or lightweight solution)
- **Content**: Markdown
- **Deployment**: Deno Deploy

#### custom-blog (Experimental)
- **Framework**: Custom (built from scratch)
- **Runtime**: Deno
- **Build Tool**: Vite
- **Styling**: TBD (minimal approach)
- **Content**: Markdown with progressive enhancement
- **Deployment**: TBD

### Design Philosophy

Both blogs share these principles:
- **Minimal**: Strip away unnecessary complexity
- **Readable**: Typography and layout optimized for reading code and prose
- **Coding-oriented**: Designed for technical writing with excellent code highlighting
- **Fast**: Performance as a feature
- **Accessible**: Keyboard navigation, semantic HTML

## 6-Month Project Roadmap

### Phase 1: Foundation (Weeks 1-4)
**Goal**: Set up monorepo and migrate current blog to Fresh

- [ ] Create Deno workspace structure
- [ ] Migrate existing Astro blog to minimal Fresh setup
- [ ] Strip down to essential features only
- [ ] Deploy current-blog to Deno Deploy
- [ ] Write migration retrospective blog post

**Blog posts**: "Migrating from Astro to Fresh", "Why Constraints Matter"

### Phase 2: Framework Foundations (Weeks 5-12)
**Goal**: Build core custom framework capabilities

- [ ] File-based routing system
- [ ] Markdown parsing and rendering
- [ ] Basic templating/component system
- [ ] Static site generation
- [ ] Development server with hot reload
- [ ] Vite integration for client-side code

**Blog posts**: "Building a Routing System from Scratch", "SSG Architecture Decisions", "Vite + Deno Integration"

### Phase 3: Progressive Enhancement (Weeks 13-16)
**Goal**: Add client-side interactivity without losing simplicity

- [ ] Island architecture / partial hydration
- [ ] Client-side routing (optional)
- [ ] Progressive enhancement patterns
- [ ] Build optimization

**Blog posts**: "Islands Architecture Explained", "Progressive Enhancement in Practice"

### Phase 4: Developer Experience (Weeks 17-20)
**Goal**: Make the framework pleasant to use

- [ ] TypeScript support and type safety
- [ ] Error handling and debugging
- [ ] Plugin system (if needed)
- [ ] Documentation
- [ ] Testing utilities

**Blog posts**: "DX Matters: Building Developer Tools", "Testing Custom Frameworks"

### Phase 5: Content Migration (Weeks 21-22)
**Goal**: Move content from current-blog to custom-blog

- [ ] Migrate all blog posts
- [ ] Ensure feature parity
- [ ] Performance comparison
- [ ] Deploy custom-blog

**Blog posts**: "6 Months of Custom Framework Development: Retrospective"

### Phase 6: Refinement (Weeks 23-26)
**Goal**: Polish and long-term maintenance planning

- [ ] Performance optimization
- [ ] Accessibility audit
- [ ] Code cleanup and documentation
- [ ] Decide on framework's future (OSS? Personal use only?)
- [ ] Sunset current-blog or keep both

**Blog posts**: "Lessons Learned Building a Framework", "The Value of Constraints"

## Important Notes

1. **Dual blogs**: current-blog is for production use while custom-blog is being built
2. **Blog the journey**: Write about the process in current-blog as you build custom-blog
3. **Constraints are features**: Deno + Vite only, no external frameworks
4. **Testing**: Both projects should have tests (Deno's built-in test runner)
5. **Minimal styling**: Focus on typography and readability, avoid heavy CSS frameworks
6. **Content format**: Markdown for both blogs (potential for MDX later in custom-blog)

When making changes:

- **Minimize dependencies**: Question every package addition
- **Write clean code**: Modular, well-tested, documented
- **Prioritize readability**: Code and prose should be easy to read
- **Progressive enhancement**: JavaScript as enhancement, not requirement
- **Document decisions**: Blog about architectural choices and tradeoffs
