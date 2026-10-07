---
title: Devon Wells | Resume
description: Devon Wells, principal software engineer. Fast, accessible interfaces for complex domains, and platforms that help teams build them.
date: 2026-10-06
---

# Devon Wells

Principal Software Engineer

[dev@wlls.dev](mailto:dev@wlls.dev) · [github.com/devdumpling](https://github.com/devdumpling) · [linkedin.com/in/devon-a-wells](https://www.linkedin.com/in/devon-a-wells/)

## Experience

### Judi Health (Capital Rx) / Amino Health

_Feb 2025 – Present_

#### Principal Software Engineer

- Modernized frontends across all Judi Care consumer products (50M+ plan members)
- Built AI chat experience integrating Judi in-house AI into Consumer apps
- Architected accessible, tokenized, multi-tenant Design System (tailwind, shadcn, Base-UI)
- Rebuilt Amino legacy Flask/React 16 to Next.js 15, React 19, Tailwind, and shadcn
- Drove metrics-driven development, analytics and observability integrations (OTEL, Grafana, Posthog/Pendo)
- Reduced JS payload improving slow page loads on marginal devices
- Established full test coverage across user journeys with Vitest, Playwright, Turborepo, and pnpm, cutting CI feedback from hours to minutes
- Architected BFF layer enabling a thin client while keeping backend services decoupled

> **The story**
>
> Joined Amino Health, a healthtech startup focused on care navigation, to lead a complete frontend rebuild and redesign. The legacy stack was a Flask/Django backend serving client-side React 16, so every page load meant downloading megabytes of JavaScript before anything rendered.
>
> Capital Rx acquired Amino (and shortly after raised a $400M Series F at a $3.25B valuation). Scope expanded from rebuilding one app to unifying the frontend across all consumer-facing products under the new Judi Health brand, serving 50M+ plan members.

### GoodRx

_Jan 2022 – Feb 2025_

#### Principal Software Engineer

_2024 – 2025_

- Modernized legacy monolithic frontend as standardized Next.js 13, React 18, and GraphQL
- Architected Tailwind and shadcn-based design system
- Migrated 1M+ lines of coupled legacy components into a modern monorepo
- Created custom CLI for orchestrating common frontend tasks
- Built a documentation platform that transformed the company's knowledge culture
- Led core pricing funnel rebuild, aligning three siloed teams and solving multi-year blockers
- Led and organized the Frontend Guild, community of practice

#### Engineering Manager

_2023, nine months_

- Managed Application Platform Frontend team while continuing architecture contributions
- Returned to IC, choosing hands-on craft over the management track

#### Lead (Staff) Software Engineer

_2022 – 2023_

- Removed 2M+ lines of dead code, cutting build times by more than ten minutes
- Rearchitected CI/CD from Lerna to Turborepo and pnpm, reducing the pipeline from 2+ hours to 15 minutes
- Restructured the monorepo for decoupled contributions
- Transformed the team's reputation from "gatekeepers" to the highest-performing engineering team in 18 months
- Hosted an internal engineering podcast, fostering community and knowledge sharing

> **The story**
>
> Joined to own a small CMS and lead a Design System team. Scope expanded quickly as I started fixing long-standing pain points: dead code slowing builds, CI pipelines that took hours, a tangled monolith that made teams step on each other. The Design System team had a reputation as gatekeepers. I focused on changing that through open communication (an internal podcast, open Slack huddles, the Frontend Guild, workshops) and genuine partnership on other teams' problems.
>
> The trust I built across teams led naturally to a management role. After nine months, I chose to return to IC. I wanted to focus on craft and on building a platform that amplified every frontend engineer at the company. That's what I did: tooling, documentation, and infrastructure that helped other teams build faster and dream bigger.

### Everything But The House

_Mar 2021 – Dec 2021_

#### Senior Software Engineer / Frontend Team Lead

- Built a React and Next.js e-commerce platform for estate sales
- Implemented a new design system for consistent, accessible UI
- Built typed utility libraries

### American Electric Power

_Dec 2019 – Mar 2021_

#### Software Developer

Modernized legacy applications to Lit and Polymer 3. Delivered Oracle Data Analytics Cloud solutions, PHP widgets, and RESTful APIs.

### Maydm

_Aug 2016 – Nov 2019_

#### Technology Coordinator / Project Manager

One of three employees at a STEM education nonprofit. Built a CS teaching platform (700+ students, 3rd–12th grade), and led operations and technical direction. Later launched the e-commerce site for Pioneer Possibilities, the org's spin-off into physical activity kits for underrepresented students.

### Freelance Web/App Development

_2011 – 2015_

## Education

### Oberlin College

_2015_

Bachelor of Arts, Computer Science

## Toolkit

- **Languages** TypeScript, HTML, CSS, Go, Python, Odin, Gleam, Rust, SQL
- **Frameworks** Datastar, Svelte, React, Solid, Next.js, TanStack, Astro, Tailwind, FastAPI
- **Runtimes** Node, Bun, Deno, BEAM
- **Tooling** Turborepo/Nx, pnpm, uv, oxc, Playwright, Vite, Nix, Sentry, Grafana, Figma, Terraform
- **Data** Postgres, SQLite, Zero
- **Platforms** AWS, GCP, Cloudflare
- **AI** Claude, Pi, Custom harnesses

## Recent Projects

### [wlls.dev](https://github.com/devdumpling/wlls)

This site. A ground-up Odin server on a $7 VPS that renders every page once at startup and drives the terminal, guestbook, and live chat as server-rendered HTML over SSE with Datastar.

`Odin` `Datastar` `SQLite` `Nix` `Caddy`

### [Snowglobe](https://github.com/devdumpling/snowglobe)

Interactive Year in Review template with real-time presence (live cursors, pixelated avatars), photo clusters, a guestbook, and easter eggs. Deduped cursor broadcasts every 50ms and spring-based animations keep it smooth. [Notes](/blog/snowglobe).

`SvelteKit` `TypeScript` `Gleam` `BEAM` `WebSockets` `Postgres`

### [devex](https://github.com/randomsound/devex)

A CLI for structured self-experiments on your workflow. Define hypotheses, work in time-boxed blocks, and collect subjective and objective data. Born from wanting actual data on AI-assisted coding instead of anecdotes. [Notes](/blog/devex).

`TypeScript` `Deno` `SQLite`
