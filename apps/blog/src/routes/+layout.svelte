<script lang="ts">
import { onNavigate } from "$app/navigation";
import Nav from "$lib/components/Nav.svelte";

let { children, data } = $props();

// Typewriter effect with instant character appearance and natural variance
function typewriterEffect(element: HTMLElement, reverse = false) {
	const text = element.textContent || "";
	if (!text) return;

	// Split into character spans
	element.innerHTML = text
		.split("")
		.map(
			(char) => `<span class="char">${char === " " ? "&nbsp;" : char}</span>`,
		)
		.join("");

	const chars = element.querySelectorAll(".char");
	const baseDelay = 60; // Base ms between characters
	const variance = 40; // Random variance (+/- ms)

	chars.forEach((char, i) => {
		if (char instanceof HTMLElement) {
			// Add random variance to make it feel like real typing
			// Use full range variance (not just +/-)
			const randomVariance = (Math.random() - 0.5) * 2 * variance;
			const index = reverse ? chars.length - i - 1 : i;
			const delay = index * baseDelay + randomVariance;

			// Animate character appearance
			const animation = char.animate(
				[
					{ opacity: 0, offset: 0 },
					{ opacity: 0, offset: 0.99 },
					{ opacity: 1, offset: 1 },
				],
				{
					duration: 10, // Very short duration - instant appearance
					delay: Math.max(0, delay),
					easing: "linear",
					fill: "both",
				},
			);

			// Add cursor to this character when it appears, remove from all previous
			animation.finished.then(() => {
				// Remove cursor from ALL characters in the breadcrumb wrapper
				document.querySelectorAll(".breadcrumb-wrapper .char.has-cursor").forEach((c) => {
					c.classList.remove("has-cursor");
				});
				// Add cursor to current character
				char.classList.add("has-cursor");
			});
		}
	});
}

// Selection highlight and instant delete effect (like selecting text and hitting delete)
function selectAndDeleteEffect(element: HTMLElement) {
	element.animate(
		[
			{ background: "var(--accent)", color: "var(--background)", opacity: 1, offset: 0 },
			{ background: "var(--accent)", color: "var(--background)", opacity: 1, offset: 0.5 },
			{ background: "var(--accent)", color: "var(--background)", opacity: 0, offset: 0.501 },
			{ opacity: 0, offset: 1 },
		],
		{
			duration: 300,
			easing: "ease",
			fill: "both",
		},
	);
}

// Enable view transitions with WAAPI typewriter for nav
onNavigate((navigation) => {
	if (!document.startViewTransition) return;

	return new Promise((resolve) => {
		// Capture current breadcrumbs before transition starts
		const oldCrumbLinks = Array.from(
			document.querySelectorAll(".breadcrumb-wrapper .crumb"),
		);
		const oldCrumbs = oldCrumbLinks.map((link) => link.textContent || "");

		// Determine navigation direction by comparing destination with current
		const targetPath = (navigation as any).to?.url?.pathname || window.location.pathname;
		const targetSegments = targetPath.split("/").filter(Boolean);
		const willGoUp = targetSegments.length < oldCrumbs.length;

		if (willGoUp) {
			// Going up tree: animate highlight+delete on removed segments (while still in DOM)
			const removedSegments = oldCrumbLinks.slice(targetSegments.length);
			removedSegments.forEach((link) => {
				if (link instanceof HTMLElement) {
					selectAndDeleteEffect(link);
				}
			});
		} else {
			// Going down/same level: remove all cursors immediately to prevent flash
			document.querySelectorAll(".breadcrumb-wrapper .char.has-cursor").forEach((char) => {
				char.classList.remove("has-cursor");
			});
		}

		const transition = document.startViewTransition(async () => {
			resolve();
			await navigation.complete;
		});

		// After DOM updates, handle cursor positioning and typewriter animations
		transition.ready.then(() => {
			const crumbLinks = Array.from(
				document.querySelectorAll(".breadcrumb-wrapper .crumb"),
			);
			const newCrumbs = crumbLinks.map((link) => link.textContent || "");

			// Helpers for cursor management
			const removeAllCursors = () => {
				document.querySelectorAll(".breadcrumb-wrapper .char.has-cursor").forEach((char) => {
					char.classList.remove("has-cursor");
				});
			};

			const addCursorToLastChar = (element: HTMLElement) => {
				const text = element.textContent || "";
				if (!text) return;

				removeAllCursors();

				// Split into character spans if needed
				const chars = element.querySelectorAll(".char");
				if (chars.length === 0) {
					element.innerHTML = text
						.split("")
						.map((char) => `<span class="char">${char === " " ? "&nbsp;" : char}</span>`)
						.join("");
				}

				// Add cursor to last character
				const allChars = element.querySelectorAll(".char");
				if (allChars.length > 0) {
					allChars[allChars.length - 1].classList.add("has-cursor");
				}
			};

			// Determine direction
			const goingUp = newCrumbs.length < oldCrumbs.length;
			const goingDown = newCrumbs.length > oldCrumbs.length;

			if (goingUp) {
				// Going up: add cursor to remaining segment (delete animation already ran)
				const lastCrumb = crumbLinks[crumbLinks.length - 1];
				if (lastCrumb instanceof HTMLElement) {
					addCursorToLastChar(lastCrumb);
				}
			} else if (goingDown) {
				// Going down: typewrite only NEW segments
				crumbLinks.forEach((link, i) => {
					if (link instanceof HTMLElement) {
						const isNew = i >= oldCrumbs.length || newCrumbs[i] !== oldCrumbs[i];
						if (isNew) {
							typewriterEffect(link);
						} else {
							// Existing segment: split into character spans (no cursor, no animation)
							const text = link.textContent || "";
							if (text && link.querySelectorAll(".char").length === 0) {
								link.innerHTML = text
									.split("")
									.map((char) => `<span class="char">${char === " " ? "&nbsp;" : char}</span>`)
									.join("");
							}
						}
					}
				});
			} else {
				// Same level: typewrite all segments
				crumbLinks.forEach((link) => {
					if (link instanceof HTMLElement) {
						typewriterEffect(link);
					}
				});
			}
		});
	});
});
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
			border-bottom: 1px dashed transparent;
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

		/* Animations - small enough to inline */
		@keyframes float {
			0%,
			100% {
				transform: translateY(0px);
			}
			50% {
				transform: translateY(-20px);
			}
		}

		@keyframes drift {
			0%,
			100% {
				transform: translateX(0px) rotate(0deg);
			}
			50% {
				transform: translateX(30px) rotate(5deg);
			}
		}

		.animate-float {
			animation: float 6s ease-in-out infinite;
		}

		.animate-drift {
			animation: drift 8s ease-in-out infinite;
		}

		/* ========================================
		   View Transitions
		   ======================================== */

		/* Disable default cross-fade on all pages */
		::view-transition-old(root),
		::view-transition-new(root) {
			animation: none;
		}

		/* Nav breadcrumbs: disable all default view transition animations (handled with WAAPI in JS) */
		::view-transition-old(nav-crumb-blog),
		::view-transition-old(nav-crumb-blog-ai-reflections),
		::view-transition-old(nav-crumb-blog-ai-agents),
		::view-transition-old(nav-crumb-blog-react-is-dead),
		::view-transition-old(nav-crumb-whois),
		::view-transition-old(nav-crumb-lab),
		::view-transition-new(nav-crumb-blog),
		::view-transition-new(nav-crumb-blog-ai-reflections),
		::view-transition-new(nav-crumb-blog-ai-agents),
		::view-transition-new(nav-crumb-blog-react-is-dead),
		::view-transition-new(nav-crumb-whois),
		::view-transition-new(nav-crumb-lab),
		::view-transition-group(nav-crumb-blog),
		::view-transition-group(nav-crumb-blog-ai-reflections),
		::view-transition-group(nav-crumb-blog-ai-agents),
		::view-transition-group(nav-crumb-blog-react-is-dead),
		::view-transition-group(nav-crumb-whois),
		::view-transition-group(nav-crumb-lab) {
			animation: none !important;
		}

		/* Post topics slide in from left when appearing */
		::view-transition-new(post-topic-*):only-child {
			animation: slide-in-left 0.3s cubic-bezier(0.4, 0, 0.2, 1) both;
		}

		/* Post dates fade in subtly when appearing */
		::view-transition-new(post-date-*):only-child {
			animation: fade-in-subtle 0.25s ease-out both;
		}

		/* Table of contents fades in when appearing on post pages */
		::view-transition-new(toc):only-child {
			animation: fade-in-subtle 0.3s ease-out 0.1s both;
		}

		/* When these elements exist on both pages, update instantly */
		::view-transition-group(post-topic-*):not(:only-child),
		::view-transition-group(post-date-*):not(:only-child),
		::view-transition-group(toc):not(:only-child) {
			animation: none;
		}

		::view-transition-old(post-topic-*):not(:only-child),
		::view-transition-old(post-date-*):not(:only-child),
		::view-transition-old(toc):not(:only-child),
		::view-transition-new(post-topic-*):not(:only-child),
		::view-transition-new(post-date-*):not(:only-child),
		::view-transition-new(toc):not(:only-child) {
			animation: instant-in 0.001ms both;
		}

		/* Keyframe animations */
		@keyframes instant-out {
			to {
				opacity: 0;
			}
		}

		@keyframes instant-in {
			from {
				opacity: 0;
			}
			to {
				opacity: 1;
			}
		}

		@keyframes slide-in-left {
			from {
				transform: translateX(-3rem);
				opacity: 0;
			}
			to {
				transform: translateX(0);
				opacity: 1;
			}
		}

		@keyframes fade-in-subtle {
			from {
				opacity: 0;
			}
			to {
				opacity: 1;
			}
		}

		/* Character spans for typewriter effect */
		:global(.char) {
			display: inline-block;
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
