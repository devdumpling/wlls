<script lang="ts">
import type { Snippet } from "svelte";

interface Props {
	title?: string;
	open?: boolean;
	children: Snippet;
}

let { title = "Aside", open = false, children }: Props = $props();
</script>

<aside class="aside">
	<details {open}>
		<summary>
			<span class="summary-text">{title}</span>
			<svg
				class="chevron"
				width="16"
				height="16"
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
</aside>

<style>
	.aside {
		margin: 2rem 0;
		background: color-mix(in oklch, var(--foreground) 2%, transparent);
		border: 1px solid var(--border);
		border-radius: 8px;
		overflow: hidden;
	}

	details {
		margin: 0;
	}

	summary {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
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
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--muted-foreground);
		transition:
			color 0.2s ease,
			background 0.2s ease;
		list-style: none;
	}

	summary::-webkit-details-marker {
		display: none;
	}

	summary::marker {
		display: none;
	}

	summary:hover {
		color: var(--foreground);
		background: color-mix(in oklch, var(--foreground) 3%, transparent);
	}

	.summary-text {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.summary-text::before {
		content: "→";
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
		padding: 0 1.25rem 1.25rem;
		font-size: 1rem;
		line-height: 1.7;
		color: var(--foreground);
		border-top: 1px solid var(--border);
		padding-top: 1.25rem;
	}

	/* Override article styles for nested content */
	.content :global(p) {
		margin: 0 0 1rem 0;
		font-size: 1rem;
	}

	.content :global(p:last-child) {
		margin-bottom: 0;
	}

	.content :global(code) {
		font-size: 0.875em;
		background: color-mix(in oklch, var(--foreground) 5%, transparent);
		padding: 0.2em 0.4em;
		border-radius: 4px;
	}

	.content :global(a) {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px solid transparent;
		transition: border-color 0.2s;
	}

	.content :global(a:hover) {
		border-bottom-color: var(--accent);
	}
</style>
