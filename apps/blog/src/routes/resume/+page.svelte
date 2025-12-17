<script lang="ts">
import RoleDetail from "$lib/components/RoleDetail.svelte";

function handlePrint() {
	window.print();
}
</script>

<svelte:head>
	<style>
		@media print {
			/* Hide site chrome and web-only elements */
			nav,
			.skip-link,
			.download-button,
			.screen-only {
				display: none !important;
			}

			/* Force light mode for print */
			:root {
				--background: oklch(1 0 0) !important;
				--foreground: oklch(0.15 0.01 106) !important;
				--muted-foreground: oklch(0.45 0.01 106) !important;
				--accent: oklch(0.5 0.15 45) !important;
				--border: oklch(0.8 0.005 106) !important;
			}

			body {
				background: white !important;
				color: black !important;
			}

			/* Keep section headers with their content */
			h2 {
				break-after: avoid;
				page-break-after: avoid;
			}

			/* Keep company header + first role together */
			.experience-header {
				break-after: avoid;
				page-break-after: avoid;
			}

			/* Keep role title with at least first few bullets */
			.role {
				break-after: avoid;
				page-break-after: avoid;
			}

			/* Condensed items are small enough to keep together */
			.experience-item.condensed {
				break-inside: avoid;
				page-break-inside: avoid;
			}

			/* Keep education and toolkit sections together */
			.education,
			.toolkit {
				break-inside: avoid;
				page-break-inside: avoid;
			}

			/* Tighter margins for print */
			.resume {
				padding: 0 !important;
				max-width: none !important;
			}

			/* Ensure links show URLs in print */
			a[href^="http"]::after {
				content: none;
			}
		}

		@page {
			margin: 0.75in;
			size: letter;
		}
	</style>
</svelte:head>

<article class="resume">
	<button class="download-button" onclick={handlePrint} aria-label="Download as PDF">
		<svg
			width="16"
			height="16"
			viewBox="0 0 16 16"
			fill="none"
			stroke="currentColor"
			stroke-width="1.5"
		>
			<path d="M8 1v9M8 10L5 7M8 10l3-3" />
			<path d="M2 11v3a1 1 0 001 1h10a1 1 0 001-1v-3" />
		</svg>
		PDF
	</button>

	<header class="header">
		<h1>Devon Wells</h1>
		<p class="title">Principal Frontend Engineer</p>
		<p class="contact">
			<a href="mailto:dev@wlls.dev">dev@wlls.dev</a>
			<span class="separator" aria-hidden="true">/</span>
			<a href="https://github.com/devdumpling"><span class="print-only">github.com/devdumpling</span><span class="screen-only">github</span></a>
			<span class="separator" aria-hidden="true">/</span>
			<a href="https://www.linkedin.com/in/devon-a-wells/"><span class="print-only">linkedin.com/in/devon-a-wells</span><span class="screen-only">linkedin</span></a>
		</p>
	</header>

	<section class="experience">
		<h2>Experience</h2>

		<div class="experience-item">
			<div class="experience-header">
				<h3>Judi Health (Capital Rx) / Amino Health</h3>
				<span class="dates">Feb 2025 – Present</span>
			</div>
			<p class="role">Principal Software Engineer</p>
			<ul>
				<li>
					Led ground-up frontend rebuild from legacy Flask/React 16 to Next.js 15, React 19,
					Tailwind 4, and shadcn
				</li>
				<li>Reduced JS payload from multiple megabytes to &lt;500KB, eliminating slow page load on marginal devices</li>
				<li>
					Established full test coverage across user journeys with vitest/playwright/Turborepo/pnpm, cutting CI
					feedback from hours to minutes
				</li>
				<li>Architected BFF layer enabling thin client while keeping backend services decoupled</li>
				<li>
					Post-acquisition: leading frontend unification across all Judi Care consumer products (54M+
					plan members)
				</li>
			</ul>
			<RoleDetail title="The story">
				<p>
					Joined Amino Health, a Healthtech startup focused on care navigation, to lead a complete frontend rebuild and redesign. The legacy stack was a Flask/Django backend serving client-side React 16—every page load meant downloading megabytes of JavaScript before anything rendered.
				</p>
				<p>
					Within months, Capital Rx acquired Amino (and shortly followed a Series F $400M raise, $3.25B valuation). Scope expanded from rebuilding one app to unifying frontend across all consumer-facing products under the new Judi Care brand, serving 54M+ plan members.
				</p>
			</RoleDetail>
		</div>

		<div class="experience-item">
			<div class="experience-header">
				<h3>GoodRx</h3>
				<span class="dates">Jan 2022 – Feb 2025</span>
			</div>

			<p class="role">Principal Software Engineer <span class="role-dates">2024 – 2025</span></p>
			<ul>
				<li>
					Rebuilt legacy monolithic frontend (Next.js 11/Express hybrid) → clean Next.js 13 +
					React 18 + graphQL
				</li>
				<li>Designed new Tailwind/shadcn-based design system</li>
				<li>Led migration of 1M+ lines of coupled legacy components into modern monorepo</li>
				<li>
					Created <code>sing</code> CLI for orchestrating common frontend tasks
				</li>
				<li>Built documentation platform that transformed company knowledge culture</li>
				<li>
					Led core pricing funnel rebuild—aligned 3 siloed teams, solved
					multi-year blockers
				</li>
				<li>Led and organized Frontend Guild (community of practice)</li>
			</ul>

			<p class="role">Engineering Manager <span class="role-dates">2023 (9 months)</span></p>
			<ul>
				<li>Managed Application Platform Frontend team while continuing architecture contributions</li>
				<li>Deliberate return to IC: chose hands-on craft over management track</li>
			</ul>

			<p class="role">
				Lead (Staff) Software Engineer <span class="role-dates">2022 – 2023</span>
			</p>
			<ul>
				<li>Removed 2M+ lines of dead code, cutting build times by 10+ minutes</li>
				<li>
					Rearchitected CI/CD: Lerna → Turborepo/pnpm, reducing pipeline from 2+ hours to 15 minutes
				</li>
				<li>Restructured monorepo for decoupled contributions</li>
				<li>
					Transformed team reputation from "gatekeepers" to highest-performing eng team in 18 months
				</li>
				<li>
				  Hosted internal engineering podcast, fostering community and knowledge sharing
				</li>
			</ul>
			<RoleDetail title="The story">
				<p>
					Joined to own a small CMS and lead a Design System team. Scope expanded quickly as I started fixing long-standing pain points—dead code slowing builds, CI pipelines that took hours, a tangled monolith that made teams step on each other. The Design System team had a reputation as gatekeepers. I focused on changing that through open communication (hosted internal podcast, open Slack huddles, Frontend Guild, workshops) and genuine partnership on other teams' problems.
				</p>
				<p>
					The trust I built across teams led naturally to a management role. After nine months, I chose to return to IC—I wanted to focus on craft and building a platform that amplified every frontend engineer at the company. That's what I did: tooling, documentation, and infrastructure that helped other teams build faster and dream bigger.
				</p>
			</RoleDetail>
		</div>

		<div class="experience-item">
			<div class="experience-header">
				<h3>Everything But The House</h3>
				<span class="dates">Mar 2021 – Dec 2021</span>
			</div>
			<p class="role">Senior Software Engineer / Frontend Team Lead</p>
			<ul>
				<li>Built React/Next.js e-commerce platform for estate sales</li>
				<li>Implemented new design system for consistent, accessible UI</li>
				<li>Built typed utility libraries</li>
			</ul>
		</div>

		<div class="experience-item condensed">
			<div class="experience-header">
				<h3>American Electric Power</h3>
				<span class="dates">Dec 2019 – Mar 2021</span>
			</div>
			<p class="role">Software Developer</p>
			<p class="condensed-description">
				Modernized legacy applications to Lit / Polymer 3. Delivered Oracle Data Analytics Cloud
				solutions, PHP widgets, and RESTful APIs.
			</p>
		</div>

		<div class="experience-item condensed">
			<div class="experience-header">
				<h3>Maydm</h3>
				<span class="dates">Aug 2016 – Nov 2019</span>
			</div>
			<p class="role">Technology Coordinator / Project Manager</p>
			<p class="condensed-description">
				One of three employees at STEM education non-profit. Built CS teaching platform (700+ students, 3rd–12th grade), led operations and technical direction. Later launched e-commerce site for Pioneer Possibilities, the org's spin-off into physical activity kits for underrepresented students.
			</p>
		</div>

		<div class="experience-item condensed">
			<div class="experience-header">
				<h3>Freelance Web Development</h3>
				<span class="dates">2010 – 2015</span>
			</div>
		</div>
	</section>

	<section class="education">
		<h2>Education</h2>
		<p><strong>Oberlin College</strong> — Bachelor of Arts, Computer Science, 2015</p>
	</section>

	<section class="toolkit">
		<h2>Toolkit</h2>
		<div class="toolkit-grid">
			<div>
				<span class="toolkit-label">Languages</span>
				<span>TypeScript, HTML, CSS, Python, Gleam, Rust, SQL</span>
			</div>
			<div>
				<span class="toolkit-label">Frameworks</span>
				<span>Svelte, React, Next.js, Tanstack, Astro, Tailwind</span>
			</div>
			<div>
				<span class="toolkit-label">Runtimes</span>
				<span>Node, Bun, Deno</span>
			</div>
			<div>
				<span class="toolkit-label">Tooling</span>
				<span>Turborepo, pnpm, Biome, Playwright, Vite, Sentry, Grafana, Figma</span>
			</div>
			<div>
				<span class="toolkit-label">Data</span>
				<span>Postgres, SQLite, Zero</span>
			</div>
			<div>
				<span class="toolkit-label">Platforms</span>
				<span>AWS, GCP, Cloudflare</span>
			</div>
		</div>
	</section>

	<section class="projects screen-only">
		<h2>Projects</h2>
		<div class="projects-grid">
			<div class="project">
				<h3><a href="https://github.com/devdumpling/snowglobe">Snowglobe</a></h3>
				<p>Interactive Year in Review template with real-time presence (live cursors, pixelated avatars), photo clusters, guestbook, and easter eggs. Deduped cursor broadcasts every 50ms and spring-based animations keep it smooth.</p>
				<div class="badges">
					<span class="badge">SvelteKit</span>
					<span class="badge">TypeScript</span>
					<span class="badge">Gleam</span>
					<span class="badge">BEAM</span>
					<span class="badge">WebSockets</span>
					<span class="badge">Postgres</span>
				</div>
			</div>
			<div class="project">
				<h3><a href="https://github.com/devdumpling/beacon">Beacon</a></h3>
				<p>Privacy-focused analytics for healthcare. Tiny client SDK (&lt;1kb gzipped) running in a web worker off the main thread. Self-host friendly, designed for FedRAMP/HIPAA. Pre-alpha.</p>
				<div class="badges">
					<span class="badge">SvelteKit</span>
					<span class="badge">TypeScript</span>
					<span class="badge">Gleam</span>
					<span class="badge">BEAM</span>
					<span class="badge">Zero</span>
					<span class="badge">Postgres</span>
				</div>
			</div>
			<div class="project">
				<h3><a href="https://github.com/wellwright-labs/pulse">Pulse</a></h3>
				<p>CLI for structured self-experiments on your workflow. Define hypotheses, work in time-boxed blocks, collect subjective and objective data. Born from wanting actual data on AI-assisted coding instead of anecdotes.</p>
				<div class="badges">
					<span class="badge">TypeScript</span>
					<span class="badge">Deno</span>
					<span class="badge">SQLite</span>
				</div>
			</div>
			<div class="project">
				<h3><a href="https://github.com/wellwright-labs/lume">Lume</a></h3>
				<p>Tooling for interactive fiction. Composable, event-sourced stories that can be traced and tested. Early stage.</p>
				<div class="badges">
					<span class="badge">TypeScript</span>
				</div>
			</div>
			<div class="project">
				<h3><a href="https://github.com/devdumpling/wlls">wlls.dev</a></h3>
				<p>This site. High interactivity and modern tooling without performance waste.</p>
				<div class="badges">
					<span class="badge">SvelteKit</span>
					<span class="badge">TypeScript</span>
					<span class="badge">mdsvex</span>
					<span class="badge">Cloudflare</span>
				</div>
			</div>
		</div>
	</section>
</article>

<style>
	.resume {
		max-width: 48rem;
		margin: 0 auto;
		padding: 4rem 1.5rem 3rem;
		position: relative;
	}

	/* Print/Screen visibility */
	.print-only {
		display: none;
	}

	@media print {
		.print-only {
			display: inline;
		}
		.screen-only {
			display: none;
		}
	}

	/* Download Button */
	.download-button {
		position: absolute;
		top: 4rem;
		right: 1.5rem;
		display: flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.5rem 0.75rem;
		background: transparent;
		border: 1px solid var(--border);
		border-radius: 4px;
		color: var(--muted-foreground);
		font-size: 0.8125rem;
		font-family: inherit;
		cursor: pointer;
		transition:
			color 0.2s,
			border-color 0.2s;
	}

	.download-button:hover {
		color: var(--foreground);
		border-color: var(--foreground);
	}

	.download-button:active {
		transform: scale(0.97);
	}

	/* Header */
	.header {
		margin-bottom: 2rem;
	}

	.header h1 {
		font-size: clamp(2rem, 5vw, 2.75rem);
		font-weight: 300;
		letter-spacing: -0.03em;
		line-height: 1.1;
		margin: 0 0 0.25rem;
	}

	.header .title {
		font-size: 1.125rem;
		color: var(--muted-foreground);
		margin: 0 0 0.75rem;
	}

	.header .contact {
		font-size: 0.875rem;
		margin: 0;
	}

	.header .contact a {
		color: var(--foreground);
		text-decoration: none;
		border-bottom: 1px dashed var(--border);
		transition: color 0.2s, border-color 0.2s;
	}

	.header .contact a:hover {
		color: var(--accent);
		border-bottom-color: var(--accent);
	}

	.separator {
		margin: 0 0.5rem;
		color: var(--muted-foreground);
	}

	/* Section Headings */
	h2 {
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.1em;
		color: var(--accent);
		margin: 0 0 1.25rem;
	}

	/* Experience */
	.experience {
		margin-bottom: 2rem;
	}

	.experience-item {
		margin-bottom: 2rem;
	}

	.experience-item:last-child {
		margin-bottom: 0;
	}

	.experience-header {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-bottom: 0.25rem;
	}

	.experience-header h3 {
		font-size: 1.125rem;
		font-weight: 500;
		margin: 0;
		letter-spacing: -0.01em;
	}

	.dates {
		font-size: 0.8125rem;
		color: var(--muted-foreground);
		white-space: nowrap;
	}

	.role {
		font-size: 0.9375rem;
		color: var(--foreground);
		margin: 0.25rem 0 0.5rem;
	}

	.role-dates {
		font-size: 0.8125rem;
		color: var(--muted-foreground);
		font-weight: 400;
	}

	.experience-item ul {
		margin: 0;
		padding-left: 1.25rem;
	}

	.experience-item li {
		font-size: 0.9375rem;
		line-height: 1.5;
		margin: 0.375rem 0;
		color: var(--foreground);
	}

	.experience-item li::marker {
		color: var(--muted-foreground);
	}

	.experience-item code {
		font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, monospace;
		font-size: 0.85em;
		background: color-mix(in oklch, var(--foreground) 5%, transparent);
		padding: 0.125em 0.375em;
		border-radius: 3px;
	}

	/* Condensed items for earlier career */
	.condensed-description {
		font-size: 0.9375rem;
		line-height: 1.5;
		color: var(--foreground);
		margin: 0.25rem 0 0;
	}

	/* Education */
	.education {
		margin-bottom: 2rem;
	}

	.education p {
		margin: 0;
		font-size: 0.9375rem;
	}

	.education strong {
		font-weight: 500;
	}

	/* Toolkit */
	.toolkit {
		margin-bottom: 3rem;
	}

	.toolkit-grid {
		display: grid;
		gap: 0.5rem;
	}

	.toolkit-grid > div {
		font-size: 0.9375rem;
		display: flex;
		gap: 0.75rem;
	}

	.toolkit-label {
		color: var(--muted-foreground);
		min-width: 5.5rem;
		flex-shrink: 0;
	}

	/* Projects (web only) */
	.projects {
		margin-bottom: 3rem;
	}

	.projects-grid {
		display: grid;
		gap: 1.5rem;
	}

	.project h3 {
		font-size: 1rem;
		font-weight: 500;
		margin: 0 0 0.375rem;
	}

	.project h3 a {
		color: var(--foreground);
		text-decoration: none;
		border-bottom: 1px dashed var(--border);
		transition: color 0.2s, border-color 0.2s;
	}

	.project h3 a:hover {
		color: var(--accent);
		border-bottom-color: var(--accent);
	}

	.project p {
		font-size: 0.875rem;
		line-height: 1.6;
		color: var(--muted-foreground);
		margin: 0;
	}

	.badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.375rem;
		margin-top: 0.5rem;
	}

	.badge {
		font-family:
			"SF Mono",
			Monaco,
			"Cascadia Code",
			"Roboto Mono",
			Consolas,
			"Courier New",
			monospace;
		font-size: 0.6875rem;
		padding: 0.125rem 0.5rem;
		background: color-mix(in oklch, var(--foreground) 5%, transparent);
		border-radius: 3px;
		color: var(--muted-foreground);
		letter-spacing: 0.01em;
	}

	/* Responsive adjustments */
	@media (max-width: 640px) {
		.resume {
			padding: 4rem 1rem 2rem;
		}

		.download-button {
			top: 4rem;
			right: 1rem;
		}

		.experience-header {
			flex-direction: column;
			gap: 0.125rem;
		}

		.toolkit-grid > div {
			flex-direction: column;
			gap: 0.125rem;
		}

		.toolkit-label {
			min-width: auto;
		}
	}
</style>
