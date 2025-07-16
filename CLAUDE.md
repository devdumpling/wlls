# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal website/portfolio built with Astro, featuring a unique organic/garden theme. The site uses MDX for content, Tailwind CSS v4 for styling, and is deployed to Cloudflare Workers.

## Development Commands

```bash
pnpm dev      # Start development server on http://localhost:4321
pnpm build    # Build for production (outputs to ./dist)
pnpm preview  # Preview production build locally
pnpm deploy   # Deploy to Cloudflare Workers
```

## Architecture

### Technology Stack

- **Framework**: Astro v5 (SSG/SSR)
- **Styling**: Tailwind CSS v4 with custom design system
- **Content**: MDX for blog posts
- **Animations**: Anime.js for animations
- **Deployment**: Cloudflare Workers via Wrangler

### Project Structure

- `/src/pages/` - Routes (Astro's file-based routing)
  - `index.astro` - Homepage with interactive story timeline
  - `fruits.astro` - Blog listing page
  - `fruits/*.mdx` - Blog posts
  - `seeds.astro` - Short posts section
  - `roots.astro` - About/backstory page
- `/src/components/` - Reusable Astro components
- `/src/layouts/` - Page layouts (Layout.astro, ArticleLayout.astro)
- `/src/styles/global.css` - Tailwind imports and custom CSS
- `/src/utils/` - Utility functions (e.g., scrollAnimations.ts)
- `/src/data/` - Data files (story.ts contains timeline data)

### Design System

The site uses a custom design system defined in global.css:

- **Colors**: OKLCH color space with organic theme (sage, bark, flower palettes)
- **Spacing**: Golden ratio based (`phi-*` classes: phi-1 through phi-9)
- **Typography**: Perfect fifth scale, Atkinson font family
- **Dark mode**: Supported via CSS custom properties

### Key Features

- Scroll-based animations on homepage timeline
- Keyboard navigation shortcuts (0-3 for quick nav)
- Progress indicator showing scroll position
- Responsive design with custom breakpoints
- MDX support for rich blog content

## Important Notes

1. **No test suite** - The project currently has no testing framework configured
2. **Biome for linting/formatting** - Uses biome for linting/formatting
3. **Minimal CI/CD** - No CI currently. CD happens by git triggers connected to cloudflare
4. **Content Management** - Blog posts are MDX files in `/src/pages/fruits/`
5. **Styling Approach** - Uses Tailwind CSS v4 with extensive custom utility classes defined in global.css

When making changes:

- Maintain the organic/garden theme in naming and design
- Write clean, modular code (subcomponents, lib folders, utilities, helpers, constants)
- Use anime.js and/or tailwind for animations
- Follow the existing golden ratio spacing system
- Use OKLCH colors from the defined palettes
- Ensure keyboard navigation remains functional
