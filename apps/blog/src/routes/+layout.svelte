<script lang="ts">
import Nav from "$lib/components/Nav.svelte";
import "../app.css";

let { children, data } = $props();
</script>

<svelte:head>
	<link rel="icon" href="/favicon.svg" />
	<title>{data?.title || "wlls.dev"}</title>
	{#if data?.description}
		<meta name="description" content={data.description} />
	{/if}
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
