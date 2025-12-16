<script lang="ts">
import type { Snippet } from "svelte";

interface Props {
	id: string | number;
	children: Snippet;
}

let { id, children }: Props = $props();
</script>

<aside class="footnote" id="footnote-{id}">
	<span class="footnote-id">{id}.</span>
	<span class="footnote-content">
		{@render children()}
	</span>
	<a href="#footnote-ref-{id}" class="footnote-back" aria-label="Back to reference">↩</a>
</aside>

<style>
	.footnote {
		display: flex;
		align-items: baseline;
		gap: 0.5rem;
		margin: 1.5rem 0;
		padding: 1rem 1.25rem;
		background: color-mix(in oklch, var(--foreground) 2%, transparent);
		border: 1px solid var(--border);
		border-radius: 8px;
		font-size: 0.9375rem;
		line-height: 1.6;
		scroll-margin-top: 6rem;
	}

	.footnote-id {
		font-family:
			"SF Mono",
			Monaco,
			"Cascadia Code",
			"Roboto Mono",
			Consolas,
			"Courier New",
			monospace;
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--accent);
		flex-shrink: 0;
	}

	.footnote-content {
		flex: 1;
		color: var(--foreground);
	}

	.footnote-content :global(a) {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px solid transparent;
		transition: border-color 0.2s;
	}

	.footnote-content :global(a:hover) {
		border-bottom-color: var(--accent);
	}

	.footnote-back {
		color: var(--muted-foreground);
		text-decoration: none;
		font-size: 0.875rem;
		flex-shrink: 0;
		transition: color 0.2s ease;
	}

	.footnote-back:hover {
		color: var(--accent);
	}
</style>
