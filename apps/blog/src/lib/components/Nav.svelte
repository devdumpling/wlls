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

<!-- Styles moved to inlined CSS in +layout.svelte for performance -->
