<script lang="ts">
import Nav from "$lib/components/Nav.svelte";
// Import non-critical CSS (blog-post styles, animations) - deferred by browser
import "../app.css";

let { children, data } = $props();
</script>

<svelte:head>
	<link rel="icon" href="/favicon.svg" />
	<title>{data?.title || "wlls.dev"}</title>
	{#if data?.description}
		<meta name="description" content={data.description} />
	{/if}

	<!-- Inline critical CSS to eliminate render-blocking request -->
	<style>
		/* CSS Variables */
		:root {
			--background: oklch(0.98 0.002 106);
			--foreground: oklch(0.25 0.01 106);
			--muted-foreground: oklch(0.55 0.01 106);
			--accent: oklch(0.65 0.15 45);
			--border: oklch(0.88 0.005 106);
		}

		@media (prefers-color-scheme: dark) {
			:root {
				--background: oklch(0.15 0.01 106);
				--foreground: oklch(0.95 0.005 106);
				--muted-foreground: oklch(0.65 0.01 106);
				--accent: oklch(0.7 0.18 45);
				--border: oklch(0.25 0.01 106);
			}
		}

		/* Reset & Base Styles */
		*,
		*::before,
		*::after {
			box-sizing: border-box;
		}

		* {
			margin: 0;
		}

		html {
			-webkit-font-smoothing: antialiased;
			-moz-osx-font-smoothing: grayscale;
		}

		body {
			line-height: 1.6;
			font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue",
				Arial, sans-serif;
			color: var(--foreground);
			background: var(--background);
			padding: 0;
			margin: 0;
		}

		/* Typography Scale */
		h1,
		h2,
		h3,
		h4,
		h5,
		h6 {
			font-weight: 600;
			line-height: 1.2;
			margin: 2em 0 0.75em;
			letter-spacing: -0.02em;
		}

		h1 {
			font-size: 2.5rem;
			margin-top: 0;
		}

		h2 {
			font-size: 1.75rem;
			margin-top: 2.5em;
		}

		h3 {
			font-size: 1.25rem;
		}

		p {
			margin: 1em 0;
		}

		/* Links */
		a {
			color: oklch(0.5 0.15 250);
			text-decoration: none;
			border-bottom: 1px dotted transparent;
			transition: border-color 0.2s;
		}

		a:hover {
			border-bottom-color: currentColor;
		}

		/* External links use solid underline - always visible */
		a[href^="http"]:not([href*="wlls.dev"]) {
			border-bottom: 1px solid currentColor;
		}

		/* Dark mode link color for better contrast */
		@media (prefers-color-scheme: dark) {
			a {
				color: oklch(0.75 0.12 180);
			}
		}

		/* Lists */
		ul,
		ol {
			margin: 1em 0;
			padding-left: 2em;
		}

		li {
			margin: 0.5em 0;
		}

		/* Blockquotes */
		blockquote {
			margin: 1.5em 0;
			padding: 0.5em 0 0.5em 1.5em;
			border-left: 3px solid oklch(0.8 0 0);
			font-style: italic;
			color: oklch(0.45 0 0);
		}

		blockquote p {
			margin: 0.5em 0;
		}

		/* Code */
		code {
			font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New",
				monospace;
			font-size: 0.9em;
			background: oklch(0.96 0 0);
			padding: 0.2em 0.4em;
			border-radius: 3px;
		}

		pre {
			margin: 1.5em 0;
			padding: 1em;
			background: oklch(0.96 0 0);
			border-radius: 4px;
			overflow-x: auto;
			line-height: 1.5;
		}

		pre code {
			background: none;
			padding: 0;
			font-size: 0.875rem;
		}

		/* Horizontal Rule */
		hr {
			margin: 3em 0;
			border: none;
			border-top: 1px solid oklch(0.88 0 0);
		}

		/* Emphasis */
		strong {
			font-weight: 600;
		}

		em {
			font-style: italic;
		}

		/* Dark mode support */
		@media (prefers-color-scheme: dark) {
			blockquote {
				color: oklch(0.65 0 0);
				border-left-color: oklch(0.35 0 0);
			}

			code {
				background: oklch(0.1 0.01 40);
			}

			pre {
				background: oklch(0.1 0.01 40);
			}

			hr {
				border-top-color: oklch(0.3 0 0);
			}
		}
	</style>
</svelte:head>

<a href="#main-content" class="skip-link">Skip to main content</a>

<Nav />

<main id="main-content">
	{@render children?.()}
</main>

<style>
	.skip-link {
		position: absolute;
		top: -80px;
		left: 0;
		background: var(--background);
		color: var(--foreground);
		padding: 0.5rem 1rem;
		text-decoration: none;
		border: 2px solid var(--accent);
		z-index: 100;
	}

	.skip-link:focus {
		top: 0;
	}
</style>
