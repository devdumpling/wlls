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

<Nav />
{@render children?.()}
