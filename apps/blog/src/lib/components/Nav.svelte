<script>
import { page } from "$app/state";
import { resolve } from "$app/paths";

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
</script>

<nav>
	<a href={resolve("/")} class="home">wlls.dev</a>
	{#if breadcrumbs.length > 0}
		<span class="divider">/</span>
		{#each breadcrumbs as crumb, i}
			<a href={resolve(crumb.path)} class="crumb">{crumb.label}</a>
			{#if i < breadcrumbs.length - 1}
				<span class="divider">/</span>
			{/if}
		{/each}
	{/if}
</nav>

<style>
	nav {
		position: fixed;
		top: 2rem;
		left: 2rem;
		z-index: 50;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	a {
		color: inherit;
		text-decoration: none;
		border-bottom: 1px dotted transparent;
	}

	a:hover {
		border-bottom-color: currentColor;
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

	@media (prefers-color-scheme: dark) {
		.divider {
			color: oklch(0.5 0 0);
		}
	}
</style>
