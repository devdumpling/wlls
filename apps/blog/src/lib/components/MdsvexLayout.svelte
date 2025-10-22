<script lang="ts" module>
	export interface Metadata {
		title?: string;
		date?: string;
		description?: string;
		topic?: string;
		layout?: string;
	}
</script>

<script lang="ts">
import { onMount } from "svelte";
import ReadingProgress from "./ReadingProgress.svelte";
import TableOfContents from "./TableOfContents.svelte";

interface TocItem {
	id: string;
	text: string;
}

// Props that mdsvex provides - try both metadata and direct props
type Props = {
	metadata?: Metadata;
	children?: any;
} & Metadata;

let props = $props<Props>();

// Access metadata either from metadata prop or directly from props
const metadata: Metadata = props.metadata || {
	title: props.title,
	date: props.date,
	description: props.description,
	topic: props.topic,
};

// Format date nicely
const formattedDate = $derived.by(() => {
	if (!metadata.date) return null;
	const d = new Date(metadata.date);
	return d.toLocaleDateString("en-US", {
		year: "numeric",
		month: "long",
		day: "numeric",
	});
});

// Table of contents items
let tocItems = $state<TocItem[]>([]);

// Extract headings for table of contents after mount
onMount(() => {
	const article = document.querySelector("article");
	if (article) {
		const headings = article.querySelectorAll("h2[id]");
		tocItems = Array.from(headings).map((heading) => ({
			id: heading.id,
			text: heading.textContent || "",
		}));
	}
});

</script>

<ReadingProgress />

<TableOfContents items={tocItems} />

<article class="blog-post">
	<header class="post-header">
		<div class="metadata">
			{#if metadata.topic}
				<span class="topic">{metadata.topic}</span>
				<span class="divider">·</span>
			{/if}
			{#if formattedDate}
				<span class="date">{formattedDate}</span>
			{/if}
		</div>
		{#if metadata.title}
			<h1>{metadata.title}</h1>
		{/if}
		{#if metadata.description}
			<p class="description">{metadata.description}</p>
		{/if}
	</header>

	<div class="content">
		{@render props.children?.()}
	</div>

	<footer class="post-footer">
		<a href="/blog" class="back-link">
			<svg
				width="16"
				height="16"
				viewBox="0 0 24 24"
				fill="none"
				stroke="currentColor"
				stroke-width="2"
				stroke-linecap="round"
				stroke-linejoin="round"
			>
				<path d="m15 18-6-6 6-6" />
			</svg>
			Back to all posts
		</a>
	</footer>
</article>

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
	}

	.topic {
		font-family: monospace;
		color: var(--accent);
	}

	.date {
		color: var(--muted-foreground);
	}

	.divider {
		color: var(--muted-foreground);
		user-select: none;
	}

	.post-header h1 {
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

	.content {
		/* Content styles are handled by article styles in app.css */
	}

	.post-footer {
		margin-top: 6rem;
		padding-top: 3rem;
		border-top: 1px solid var(--border);
	}

	.back-link {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		color: var(--muted-foreground);
		text-decoration: none;
		border: none;
		transition: color 0.3s ease;
		font-size: 0.9375rem;
	}

	.back-link:hover {
		color: var(--accent);
		border: none;
	}

	.back-link svg {
		transition: transform 0.3s ease;
	}

	.back-link:hover svg {
		transform: translateX(-4px);
	}
</style>
