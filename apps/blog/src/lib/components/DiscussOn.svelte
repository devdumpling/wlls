<script lang="ts">
interface DiscussLink {
	platform: string;
	url: string;
}

interface Props {
	links: DiscussLink[];
}

let { links }: Props = $props();
</script>

<div class="discuss-on">
	<div class="discuss-content">
		<span class="discuss-label">Discuss on:</span>
		<div class="discuss-links">
			{#each links as link}
				<a href={link.url} target="_blank" rel="noopener noreferrer">
					{link.platform}
				</a>
			{/each}
		</div>
	</div>
</div>

<style>
	.discuss-on {
		margin-top: 4rem;
		background: color-mix(in oklch, var(--foreground) 2%, transparent);
		border: 1px solid var(--border);
		border-radius: 8px;
		padding: 1.5rem;
		transition: background 0.2s ease;
		font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New",
			monospace;
	}

	.discuss-on:hover {
		background: color-mix(in oklch, var(--foreground) 3%, transparent);
	}

	.discuss-content {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.75rem;
		font-size: 0.9375rem;
	}

	.discuss-label {
		color: var(--muted-foreground);
		font-weight: 500;
	}

	.discuss-links {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.discuss-links a {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px solid var(--accent);
		transition:
			border-color 0.2s,
			opacity 0.2s;
	}

	.discuss-links a:hover {
		opacity: 0.8;
	}

	@media (max-width: 640px) {
		.discuss-content {
			flex-direction: column;
			align-items: flex-start;
			gap: 0.5rem;
		}
	}
</style>
