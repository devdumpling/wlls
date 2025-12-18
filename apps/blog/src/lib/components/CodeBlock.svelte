<script lang="ts">
	import { onMount } from "svelte";

	interface Props {
		code: string;
		lang?: string;
	}

	let { code, lang = "typescript" }: Props = $props();

	let highlighted = $state<string | null>(null);

	onMount(async () => {
		try {
			// Dynamically import shiki to keep initial bundle small
			const { createHighlighter } = await import("shiki");

			const highlighter = await createHighlighter({
				themes: ["kanagawa-wave", "kanagawa-lotus"],
				langs: [lang],
			});

			highlighted = highlighter.codeToHtml(code.trim(), {
				lang,
				themes: {
					light: "kanagawa-lotus",
					dark: "kanagawa-wave",
				},
			});
		} catch (err) {
			console.warn("Shiki failed to load, showing plain code:", err);
		}
	});
</script>

<div class="code-block">
	{#if highlighted}
		{@html highlighted}
	{:else}
		<pre><code>{code.trim()}</code></pre>
	{/if}
</div>

<style>
	.code-block {
		margin: 0.5rem 0 1rem 0;
		border-radius: 0.5rem;
		overflow: hidden;
	}

	.code-block :global(pre) {
		margin: 0;
		padding: 1rem;
		overflow-x: auto;
		line-height: 1.5;
		border-radius: 0.5rem;
	}

	.code-block :global(pre code) {
		font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, monospace;
		font-size: 0.8125rem;
		background: transparent;
		padding: 0;
	}

	/* Fallback styling when Shiki hasn't loaded yet */
	.code-block pre:not(.shiki) {
		background: oklch(0.12 0.01 106);
	}

	.code-block pre:not(.shiki) code {
		color: var(--foreground);
	}

	/* Shiki dual-theme support */
	@media (prefers-color-scheme: dark) {
		.code-block :global(pre.shiki),
		.code-block :global(pre.shiki span) {
			color: var(--shiki-dark) !important;
			background-color: transparent !important;
		}

		.code-block :global(pre.shiki) {
			background-color: var(--shiki-dark-bg) !important;
		}
	}

	@media (prefers-color-scheme: light) {
		.code-block pre:not(.shiki) {
			background: oklch(0.96 0.005 106);
		}
	}
</style>
