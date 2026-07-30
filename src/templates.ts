import type { Post, RenderedContent } from "./markdown.ts";
import type { PostSummary } from "./frontmatter.ts";
import { absoluteUrl, serializeJsonLd, site } from "./site.ts";

export interface Assets {
  css: string;
  js: string;
}

interface PageOptions {
  assets: Assets;
  path: string;
  title?: string;
  description?: string;
  main: string;
  type?: "website" | "article";
  published?: string;
  structuredData?: unknown;
  noIndex?: boolean;
  canonical?: boolean;
}

interface PostSeason {
  label: string;
  posts: PostSummary[];
}

export function renderHome(posts: readonly PostSummary[], assets: Assets): string {
  const seasons = groupBySeason(posts);
  const newestYear = posts[0]?.date.slice(0, 4);
  const oldestYear = posts.at(-1)?.date.slice(0, 4);
  const yearRange = oldestYear === newestYear ? newestYear : `${oldestYear}—${newestYear}`;
  const list = seasons.map((season) => `
    <section class="post-season">
      <h2>${escapeHtml(season.label)}</h2>
      <ol class="post-list">
        ${
    season.posts.map((post) => `
          <li>
            <article>
              <a class="post-list__link" href="/blog/${post.slug}">
                <span class="post-transition-mark" aria-hidden="true"></span>
                <h3>${escapeHtml(post.title)}</h3>
                <p>${escapeHtml(post.description)}</p>
              </a>
            </article>
          </li>`).join("")
  }
      </ol>
    </section>`).join("");

  return renderDocument({
    assets,
    path: "/",
    main: `<div class="page-shell home-shell">
      <h1 class="visually-hidden">Writing</h1>
      <div class="post-seasons">${list}</div>
      <aside class="archive-index" aria-label="Archive summary">
        <p class="archive-index__count"><strong>${posts.length}</strong><span>${
      posts.length === 1 ? "entry" : "entries"
    }</span></p>
        <p class="archive-index__range">${yearRange}</p>
      </aside>
    </div>`,
  });
}

export function renderAbout(
  page: { title: string; description: string; content: RenderedContent },
  assets: Assets,
): string {
  return renderDocument({
    assets,
    path: "/about",
    title: "About",
    description: page.description,
    main: `<article class="article about-page">
      <header class="article-header">
        <p class="eyebrow">About</p>
        <h1>${escapeHtml(page.title)}</h1>
        <p class="article-dek">${escapeHtml(page.description)}</p>
      </header>
      ${renderMarkdownContent(page.content)}
    </article>`,
  });
}

export function renderArticle(post: Post, formattedDate: string, assets: Assets): string {
  const path = `/blog/${post.slug}`;
  const topic = post.topic ? `<span>${escapeHtml(post.topic)}</span>` : "";

  return renderDocument({
    assets,
    path,
    title: post.title,
    description: post.description,
    type: "article",
    published: post.date,
    structuredData: {
      "@context": "https://schema.org",
      "@type": "BlogPosting",
      headline: post.title,
      description: post.description,
      datePublished: post.date,
      author: { "@type": "Person", name: site.author },
      mainEntityOfPage: absoluteUrl(path),
    },
    main: `<article class="article">
      <header class="article-header">
        <span class="post-transition-mark" aria-hidden="true"></span>
        <p class="article-meta">
          ${topic}
          <time datetime="${post.date}">${escapeHtml(formattedDate)}</time>
          <span>${post.minutes} min read</span>
        </p>
        <h1>${escapeHtml(post.title)}</h1>
        <p class="article-dek">${escapeHtml(post.description)}</p>
      </header>
      ${renderMarkdownContent(post.content)}
      <footer class="article-footer"><a href="/">Back</a></footer>
    </article>`,
  });
}

export function renderResume(assets: Assets): string {
  return renderDocument({
    assets,
    path: "/resume",
    title: "Resume",
    description: "Devon Wells, principal software engineer.",
    main: `<article class="resume">
      <div class="screen-only resume-actions">
        <button class="print-button" type="button" data-print hidden>Print or save as PDF</button>
      </div>
      <header class="resume-header">
        <h1>Devon Wells</h1>
        <p class="resume-title">Principal Frontend Engineer</p>
        <p class="resume-contact">
          <a href="mailto:dev@wlls.dev">dev@wlls.dev</a><span aria-hidden="true">/</span>
          <a href="https://github.com/devdumpling"><span class="screen-only">GitHub</span><span class="print-only">github.com/devdumpling</span></a>
          <span aria-hidden="true">/</span>
          <a href="https://www.linkedin.com/in/devon-a-wells/"><span class="screen-only">LinkedIn</span><span class="print-only">linkedin.com/in/devon-a-wells</span></a>
        </p>
      </header>
      <section class="resume-section">
        <h2>Experience</h2>
        <div class="experience-item">
          <div class="experience-heading"><h3>Judi Health (Capital Rx) / Amino Health</h3><span>Feb 2025 - Present</span></div>
          <p class="role">Principal Software Engineer</p>
          <ul>
            <li>Led ground-up frontend rebuild from legacy Flask/React 16 to Next.js 15, React 19, Tailwind 4, and shadcn</li>
            <li>Reduced JS payload from multiple megabytes to &lt;500KB, eliminating slow page load on marginal devices</li>
            <li>Established full test coverage across user journeys with Vitest, Playwright, Turborepo, and pnpm, cutting CI feedback from hours to minutes</li>
            <li>Architected BFF layer enabling a thin client while keeping services decoupled</li>
            <li>Post-acquisition: leading frontend unification across Judi Care consumer products serving 54M+ plan members</li>
          </ul>
          <details class="role-detail screen-only"><summary>The story</summary><div>
            <p>Joined Amino Health, a healthtech startup focused on care navigation, to lead a complete frontend rebuild and redesign. The legacy stack was a Flask/Django backend serving client-side React 16, so every page load meant downloading megabytes of JavaScript before anything rendered.</p>
            <p>Within months, Capital Rx acquired Amino. Scope expanded from rebuilding one app to unifying frontend across all consumer-facing products under the Judi Care brand.</p>
          </div></details>
        </div>
        <div class="experience-item">
          <div class="experience-heading"><h3>GoodRx</h3><span>Jan 2022 - Feb 2025</span></div>
          <p class="role">Principal Software Engineer <span>2024 - 2025</span></p>
          <ul>
            <li>Rebuilt a legacy Next.js 11/Express frontend as Next.js 13 and React 18</li>
            <li>Designed a new Tailwind and shadcn-based design system</li>
            <li>Led migration of 1M+ lines of coupled legacy components into a modern monorepo</li>
            <li>Created the <code>sing</code> CLI for orchestrating common frontend tasks</li>
            <li>Built a documentation platform that transformed company knowledge culture</li>
            <li>Led the core pricing funnel rebuild across three previously siloed teams</li>
            <li>Led and organized the Frontend Guild community of practice</li>
          </ul>
          <p class="role">Engineering Manager <span>2023, nine months</span></p>
          <ul>
            <li>Managed the Application Platform Frontend team while contributing architecture</li>
            <li>Deliberately returned to the IC path to focus on hands-on craft</li>
          </ul>
          <p class="role">Lead (Staff) Software Engineer <span>2022 - 2023</span></p>
          <ul>
            <li>Removed 2M+ lines of dead code, cutting build times by more than ten minutes</li>
            <li>Moved CI from Lerna to Turborepo and pnpm, reducing two-hour pipelines to 15 minutes</li>
            <li>Restructured the monorepo for decoupled contributions</li>
            <li>Transformed the team's reputation from gatekeepers to trusted partners</li>
            <li>Hosted an internal engineering podcast to foster knowledge sharing</li>
          </ul>
          <details class="role-detail screen-only"><summary>The story</summary><div>
            <p>Joined to own a small CMS and lead a Design System team. Scope expanded as I fixed long-standing pain points: dead code slowing builds, CI pipelines that took hours, and a tangled monolith that made teams step on each other.</p>
            <p>The trust built across teams led naturally to management. After nine months I chose to return to IC work and focus on a platform that amplified every frontend engineer through tooling, documentation, and infrastructure.</p>
          </div></details>
        </div>
        ${
      renderExperience(
        "Everything But The House",
        "Mar 2021 - Dec 2021",
        "Senior Software Engineer / Frontend Team Lead",
        [
          "Built a React and Next.js e-commerce platform for estate sales",
          "Implemented an accessible design system and typed utility libraries",
        ],
      )
    }
        ${
      renderCondensedExperience(
        "American Electric Power",
        "Dec 2019 - Mar 2021",
        "Software Developer",
        "Modernized legacy applications with Lit and Polymer 3. Delivered Oracle Data Analytics Cloud solutions, PHP widgets, and REST APIs.",
      )
    }
        ${
      renderCondensedExperience(
        "Maydm",
        "Aug 2016 - Nov 2019",
        "Technology Coordinator / Project Manager",
        "One of three employees at a STEM education nonprofit. Built a CS teaching platform serving 700+ students and led operations and technical direction.",
      )
    }
        <div class="experience-item condensed"><div class="experience-heading"><h3>Freelance Web Development</h3><span>2010 - 2015</span></div></div>
      </section>
      <section class="resume-section education"><h2>Education</h2><p><strong>Oberlin College</strong> - Bachelor of Arts, Computer Science, 2015</p></section>
      <section class="resume-section toolkit"><h2>Toolkit</h2><dl>
        ${renderToolkit("Languages", "TypeScript, HTML, CSS, Python, Gleam, Rust, SQL")}
        ${renderToolkit("Frameworks", "Svelte, React, Next.js, TanStack, Astro")}
        ${renderToolkit("Runtimes", "Deno, Bun, Node")}
        ${renderToolkit("Tooling", "Turborepo, pnpm, Playwright, Vite, Figma")}
        ${renderToolkit("Data", "Postgres, SQLite, Zero")}
        ${renderToolkit("Platforms", "AWS, GCP, Cloudflare")}
      </dl></section>
      <section class="resume-section projects screen-only"><h2>Selected Projects</h2><div class="project-list">
        ${
      renderProject(
        "Snowglobe",
        "https://github.com/devdumpling/snowglobe",
        "Interactive year-in-review experience with realtime presence and a Gleam backend.",
      )
    }
        ${
      renderProject(
        "Beacon",
        "https://github.com/devdumpling/beacon",
        "Privacy-focused healthcare analytics with a sub-1KB web worker client.",
      )
    }
        ${
      renderProject(
        "Pulse",
        "https://github.com/wellwright-labs/pulse",
        "Deno CLI for running and recording structured workflow experiments.",
      )
    }
        ${
      renderProject(
        "wlls.dev",
        "https://github.com/devdumpling/wlls",
        "This site: a handcrafted home for writing and web experiments.",
      )
    }
      </div></section>
    </article>`,
  });
}

export function renderNotFound(assets: Assets): string {
  return renderDocument({
    assets,
    path: "/404",
    title: "Page not found",
    description: "The requested page could not be found.",
    noIndex: true,
    canonical: false,
    main: `<div class="page-shell error-page">
      <p class="eyebrow">404</p>
      <h1>This page has wandered off.</h1>
      <p>The address may be wrong, or the page may no longer exist.</p>
      <a href="/">Return home</a>
    </div>`,
  });
}

function renderDocument({
  assets,
  path,
  title,
  description = site.description,
  main,
  type = "website",
  published,
  structuredData,
  noIndex = false,
  canonical = true,
}: PageOptions): string {
  const pageTitle = title ? `${title} | ${site.name}` : `${site.title} | ${site.name}`;
  const url = absoluteUrl(path);
  const canonicalTags = canonical
    ? `<link data-page-head rel="canonical" href="${escapeAttribute(url)}">
    <meta data-page-head property="og:url" content="${escapeAttribute(url)}">`
    : "";
  const publishedTag = published
    ? `<meta data-page-head property="article:published_time" content="${
      escapeAttribute(published)
    }">`
    : "";
  const robotsTag = noIndex ? `<meta data-page-head name="robots" content="noindex">` : "";
  const jsonLd = structuredData === undefined
    ? ""
    : `<script data-page-head type="application/ld+json">${
      serializeJsonLd(structuredData)
    }</script>`;

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <link rel="preload" href="/fonts/literata-latin.woff2" as="font" type="font/woff2" crossorigin>
    <link rel="icon" href="/favicon.svg">
    <link rel="alternate" type="application/rss+xml" title="wlls.dev" href="/rss.xml">
    <link rel="stylesheet" href="${assets.css}">
    <title data-page-head>${escapeHtml(pageTitle)}</title>
    <meta data-page-head name="description" content="${escapeAttribute(description)}">
    ${canonicalTags}
    <meta data-page-head property="og:type" content="${type}">
    <meta data-page-head property="og:title" content="${escapeAttribute(pageTitle)}">
    <meta data-page-head property="og:description" content="${escapeAttribute(description)}">
    <meta data-page-head property="og:site_name" content="${site.name}">
    <meta data-page-head name="twitter:card" content="summary">
    <meta data-page-head name="twitter:title" content="${escapeAttribute(pageTitle)}">
    <meta data-page-head name="twitter:description" content="${escapeAttribute(description)}">
    ${publishedTag}
    ${robotsTag}
    ${jsonLd}
  </head>
  <body>
    <a class="skip-link" href="#main-content">Skip to content</a>
    ${renderNavigation(path)}
    <main id="main-content" tabindex="-1">${main}</main>
    <script type="module" src="${assets.js}"></script>
  </body>
</html>`;
}

function renderNavigation(path: string): string {
  const aboutCurrent = path === "/about" ? ` aria-current="page"` : "";
  const homeCurrent = path === "/" ? ` aria-current="page"` : "";
  return `<header class="site-header">
    <nav aria-label="Primary navigation">
      <a href="/about"${aboutCurrent}>About</a>
      <a class="site-mark" href="/" aria-label="wlls.dev home"${homeCurrent}>wlls.dev</a>
      <a href="/rss.xml" data-native-navigation>RSS</a>
    </nav>
  </header>`;
}

function renderMarkdownContent(content: RenderedContent): string {
  if (content.kind === "flow") return `<div class="prose">${content.html}</div>`;

  const blocks = content.blocks.map((block, blockIndex) => {
    if (block.kind === "plate") {
      return `<div class="book-plate" data-book-plate>${block.html}</div>`;
    }
    const pages = block.pages.map((html, pageIndex) =>
      `<div class="book-page" data-book-page="${blockIndex + 1}.${pageIndex + 1}">${html}</div>`
    ).join("");
    return `<div class="book-spread" data-book-spread>${pages}</div>`;
  }).join("");

  return `<div class="prose book-prose" data-book-layout>${blocks}</div>`;
}

function groupBySeason(posts: readonly PostSummary[]): PostSeason[] {
  const seasons = new Map<string, PostSeason>();

  for (const post of posts) {
    const dateYear = Number(post.date.slice(0, 4));
    const month = Number(post.date.slice(5, 7));
    const [name, year] = month <= 2
      ? ["Winter", dateYear]
      : month <= 5
      ? ["Spring", dateYear]
      : month <= 8
      ? ["Summer", dateYear]
      : month <= 11
      ? ["Fall", dateYear]
      : ["Winter", dateYear];
    const label = `${name} ${year}`;
    const season = seasons.get(label);
    if (season) season.posts.push(post);
    else seasons.set(label, { label, posts: [post] });
  }

  return [...seasons.values()];
}

function renderExperience(company: string, dates: string, role: string, items: string[]): string {
  return `<div class="experience-item">
    <div class="experience-heading"><h3>${escapeHtml(company)}</h3><span>${
    escapeHtml(dates)
  }</span></div>
    <p class="role">${escapeHtml(role)}</p>
    <ul>${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>
  </div>`;
}

function renderCondensedExperience(
  company: string,
  dates: string,
  role: string,
  description: string,
): string {
  return `<div class="experience-item condensed">
    <div class="experience-heading"><h3>${escapeHtml(company)}</h3><span>${
    escapeHtml(dates)
  }</span></div>
    <p class="role">${escapeHtml(role)}</p><p>${escapeHtml(description)}</p>
  </div>`;
}

function renderToolkit(label: string, value: string): string {
  return `<div><dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd></div>`;
}

function renderProject(name: string, href: string, description: string): string {
  return `<article><h3><a href="${escapeAttribute(href)}">${escapeHtml(name)}</a></h3><p>${
    escapeHtml(description)
  }</p></article>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const escapeAttribute = escapeHtml;
