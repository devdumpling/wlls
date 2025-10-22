<script lang="ts">
	interface Props {
		title: string;
		date: string;
		description?: string;
		content?: string; // For calculating read time
	}

	let { title, date, description, content = '' }: Props = $props();

	// Calculate read time (average 200 words per minute)
	const readTime = $derived(() => {
		if (!content) return null;
		const words = content.trim().split(/\s+/).length;
		const minutes = Math.ceil(words / 200);
		return `${minutes} min read`;
	});

	// Format date nicely
	const formattedDate = $derived(() => {
		const d = new Date(date);
		return d.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
	});
</script>

<header class="post-header">
	<div class="metadata">
		<span class="date">{formattedDate()}</span>
		{#if readTime()}
			<span class="divider">·</span>
			<span class="read-time">{readTime()}</span>
		{/if}
	</div>
	<h1>{title}</h1>
	{#if description}
		<p class="description">{description}</p>
	{/if}
</header>

<style>
	.post-header {
		margin-bottom: 4rem;
	}

	.metadata {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 1.5rem;
		font-size: 0.875rem;
		color: var(--muted-foreground);
	}

	.divider {
		user-select: none;
	}

	h1 {
		font-size: clamp(2.5rem, 6vw, 3.75rem);
		font-weight: 300;
		letter-spacing: -0.03em;
		margin: 0 0 1.5rem 0;
		line-height: 1.1;
	}

	.description {
		font-size: 1.25rem;
		line-height: 1.6;
		color: var(--muted-foreground);
		margin: 0;
	}
</style>
