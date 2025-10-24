<script>
import { onMount } from "svelte";
import { resolve } from "$app/paths";
import { page } from "$app/state";

// Build breadcrumb segments from current path
const breadcrumbs = $derived.by(() => {
	const pathname = page.url.pathname;
	if (pathname === "/") return [];

	const segments = pathname.split("/").filter(Boolean);
	return segments.map((segment, index) => {
		const path = "/" + segments.slice(0, index + 1).join("/");
		return { label: segment, path };
	});
});

// Auto-hide nav on scroll down, show on scroll up
let isVisible = $state(true);
let lastScrollY = $state(0);

onMount(() => {
	const handleScroll = () => {
		const currentScrollY = window.scrollY;

		// Show nav if scrolled to top
		if (currentScrollY < 10) {
			isVisible = true;
		}
		// Hide on scroll down, show on scroll up
		else if (currentScrollY > lastScrollY && currentScrollY > 100) {
			isVisible = false;
		} else if (currentScrollY < lastScrollY) {
			isVisible = true;
		}

		lastScrollY = currentScrollY;
	};

	window.addEventListener("scroll", handleScroll, { passive: true });
	return () => window.removeEventListener("scroll", handleScroll);
});
</script>

<nav class:hidden={!isVisible}>
	<a href={resolve("/")} class="home">wlls.dev</a>
	{#if breadcrumbs.length > 0}
		<span class="divider">/</span>
		<span class="breadcrumb-wrapper">
			{#each breadcrumbs as crumb, i (crumb.path)}
				<span style="view-transition-name: nav-crumb-{i};">
					<a href={resolve(crumb.path)} class="crumb">
						{crumb.label}
					</a>
				</span>
				{#if i < breadcrumbs.length - 1}
					<span class="divider">/</span>
				{/if}
			{/each}
		</span>
	{/if}
</nav>

<style>
	nav {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
		padding: 1rem 1.5rem;
		transition: transform 0.3s ease;
	}

	nav.hidden {
		transform: translateY(-100%);
	}

	/* Below 1280px: add background for readability (matches TOC breakpoint) */
	@media (max-width: 1279px) {
		nav {
			background: var(--background);
			border-bottom: 1px solid var(--border);
			backdrop-filter: blur(10px);
			background: color-mix(in oklch, var(--background) 95%, transparent);
		}
	}

	/* 1280px+: transparent, positioned top-left */
	@media (min-width: 1280px) {
		nav {
			top: 2rem;
			left: 2rem;
			right: auto;
			width: auto;
			padding: 0;
			background: transparent;
			border: none;
		}

		nav.hidden {
			transform: none; /* Don't hide on larger screens */
		}
	}

	a {
		color: inherit;
		text-decoration: none;
		border-bottom: 1px dotted transparent;
		transition: border-color 0.2s ease, transform 0.1s ease;
		display: inline-block;
	}

	a:hover {
		border-bottom-color: currentColor;
	}

	a:active {
		transform: scale(0.92);
	}

	.home {
		font-weight: 600;
	}

	.divider {
		color: oklch(0.6 0 0);
		user-select: none;
	}

	.crumb {
		font-weight: 400;
	}

	.breadcrumb-wrapper {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	@media (prefers-color-scheme: dark) {
		.divider {
			color: oklch(0.5 0 0);
		}
	}
</style>
