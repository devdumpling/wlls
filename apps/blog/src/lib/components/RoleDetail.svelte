<script lang="ts">
import type { Snippet } from "svelte";

interface Props {
	title?: string;
	children: Snippet;
}

let { title = "Read more", children }: Props = $props();
</script>

<details class="role-detail screen-only">
	<summary>
		<span class="summary-text">{title}</span>
		<svg
			class="chevron"
			width="14"
			height="14"
			viewBox="0 0 24 24"
			fill="none"
			stroke="currentColor"
			stroke-width="2"
			stroke-linecap="round"
			stroke-linejoin="round"
		>
			<path d="m6 9 6 6 6-6" />
		</svg>
	</summary>
	<div class="content">
		{@render children()}
	</div>
</details>

<style>
	.role-detail {
		margin-top: 0.75rem;
	}

	summary {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		cursor: pointer;
		user-select: none;
		font-family:
			"SF Mono",
			Monaco,
			"Cascadia Code",
			"Roboto Mono",
			Consolas,
			"Courier New",
			monospace;
		font-size: 0.8125rem;
		color: var(--muted-foreground);
		transition: color 0.2s;
		list-style: none;
	}

	summary::-webkit-details-marker {
		display: none;
	}

	summary::marker {
		display: none;
	}

	summary:hover {
		color: var(--accent);
	}

	.chevron {
		transition: transform 0.2s ease;
		flex-shrink: 0;
	}

	details[open] .chevron {
		transform: rotate(180deg);
	}

	.content {
		margin-top: 0.75rem;
		padding-left: 1rem;
		border-left: 2px solid var(--border);
		font-size: 0.875rem;
		line-height: 1.6;
		color: var(--muted-foreground);
	}

	.content :global(p) {
		margin: 0 0 0.75rem 0;
	}

	.content :global(p:last-child) {
		margin-bottom: 0;
	}
</style>
