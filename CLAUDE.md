# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Philosophy

A minimal, elegant writing-focused blog that prioritizes the reading experience above all else. The site should feel like reading your own journal - warm, inviting, and personal. The design should be beautiful in its simplicity, making the author want to write and readers want to read.

## Core Principles

1. **Content First**: Every design decision should enhance the reading and writing experience
2. **Minimal but Elegant**: Simple doesn't mean boring - thoughtful typography and subtle design touches
3. **Warm and Inviting**: Like reading a personal journal, not a corporate blog
4. **Clean Code**: No file over 150 lines (excluding content), components and helpers for everything
5. **Future-Ready**: Built to support footnotes, asides, highlights, tooltips, comments, and a guestbook

## Development Commands

```bash
bun run dev      # Start development server on http://localhost:4321
bun run build    # Build for production (outputs to ./dist)
bun run preview  # Preview production build locally
bun run deploy   # Deploy to Cloudflare Workers
bun run test     # Run tests with Vitest
bun run test:ui  # Run tests with UI
bun run test:coverage # Run tests with coverage report
```

## Architecture

### Technology Stack

- **Framework**: Astro v5 (SSG/SSR)
- **Styling**: Tailwind CSS v4 - utility-first, minimal custom CSS
- **Content**: MDX for rich blog posts with components
- **Typography**: Focus on readability and visual hierarchy
- **Deployment**: Cloudflare Workers via Wrangler

### Project Structure

- `/src/pages/` - Routes (Astro's file-based routing)
  - `index.astro` - Homepage: name, bio, hero post, post directory
  - `posts/*.mdx` - Blog posts in MDX format
  - `about.astro` - About page (personal backstory)
- `/src/components/` - Small, focused components (< 150 lines)
- `/src/layouts/` - Minimal page layouts
- `/src/utils/` - Helper functions and utilities
- `/src/lib/` - Core logic and functionality
- `/src/styles/global.css` - Tailwind imports only, minimal custom CSS

### Design System

- **Colors**: Warm, inviting palette - think journal/notebook aesthetic
- **Typography**: Clean, readable fonts with excellent hierarchy
- **Spacing**: Consistent, breathable layouts
- **Interactions**: Subtle, delightful micro-interactions
- **Dark mode**: Optional, but should maintain warmth

### Key Features

- **Keyboard navigation**: Quick shortcuts for power users
- **Recent post hero**: Highlight the latest writing prominently
- **Post directory**: Clean, scannable list of all posts
- **Future enhancements**: Footnotes, asides, highlights, tooltips, comments, guestbook

## Development Guidelines

1. **Keep it simple**: Start with foundations, add visual interest thoughtfully
2. **No repetition**: Extract components, helpers, and utilities aggressively
3. **Modularity**: Small files, single responsibilities
4. **Performance**: Fast load times, minimal JavaScript
5. **Accessibility**: Keyboard navigation, screen reader friendly
6. **Fun**: This should be enjoyable to build and use

## Content Management

- Blog posts are MDX files in `/src/pages/posts/`
- Support for rich content: code blocks, images, embeds
- Future: footnotes, asides, highlights, tooltips

## Future Features

- **Sync engine**: LiveStore, Zero, or TanStack DB for:
  - Comments system
  - Guestbook
  - Real-time features
- **Enhanced reading**: Footnotes, asides, highlights
- **Writing tools**: Better MDX components, preview modes
