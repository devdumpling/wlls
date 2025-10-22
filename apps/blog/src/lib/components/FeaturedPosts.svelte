<script lang="ts">
import type { Post } from "$lib/types";
import { formatDate } from "$lib/utils";

let { posts }: { posts: Post[] } = $props();

// Separate current and archived posts
const currentPosts = posts.filter((post) => !post.archive);
const archivedPosts = posts.filter((post) => post.archive);
</script>

<section class="featured-posts">
	<h2>Words</h2>

	<!-- Current Posts -->
	<div class="posts-list">
		{#each currentPosts as post (post.slug)}
			<article class="post-item">
				<a href="/blog/{post.slug}" class="post-link">
					<div class="post-content">
						{#if post.topic}
							<div class="post-meta">
								<span class="post-topic">{post.topic}</span>
							</div>
						{/if}

						<div class="post-main">
							<h3>{post.title}</h3>
							<p class="post-excerpt">{post.description}</p>
							<div class="post-info">
								<span>{formatDate(post.date, 'short')}</span>
							</div>
						</div>

						<div class="post-arrow">
							<svg
								width="24"
								height="24"
								viewBox="0 0 24 24"
								fill="none"
								stroke="currentColor"
								stroke-width="2"
								stroke-linecap="round"
								stroke-linejoin="round"
							>
								<path d="M7 7h10v10" />
								<path d="M7 17 17 7" />
							</svg>
						</div>
					</div>
				</a>
			</article>
		{/each}
	</div>

	<!-- Archived Posts -->
	{#if archivedPosts.length > 0}
		<div class="archive-section">
			<h3 class="archive-heading">Archive</h3>
			<p class="archive-description">
				Older writing from my Medium days, preserved here as artifacts from a different era of my
				work.
			</p>

			<div class="posts-list archive-posts">
				{#each archivedPosts as post (post.slug)}
					<article class="post-item archive-item">
						<a href="/blog/{post.slug}" class="post-link">
							<div class="post-content">
								{#if post.topic}
									<div class="post-meta">
										<span class="post-topic">{post.topic}</span>
									</div>
								{/if}

								<div class="post-main">
									<h4>{post.title}</h4>
									<p class="post-excerpt">{post.description}</p>
									<div class="post-info">
										<span>{formatDate(post.date, 'short')}</span>
									</div>
								</div>

								<div class="post-arrow">
									<svg
										width="24"
										height="24"
										viewBox="0 0 24 24"
										fill="none"
										stroke="currentColor"
										stroke-width="2"
										stroke-linecap="round"
										stroke-linejoin="round"
									>
										<path d="M7 7h10v10" />
										<path d="M7 17 17 7" />
									</svg>
								</div>
							</div>
						</a>
					</article>
				{/each}
			</div>
		</div>
	{/if}
</section>

<style>
	.featured-posts {
		padding: 8rem 1.5rem;
		max-width: 88rem;
		margin: 0 auto;
	}

	h2 {
		font-size: clamp(2.5rem, 5vw, 3.5rem);
		font-weight: 300;
		margin: 0 0 5rem 0;
	}

	.posts-list {
		display: flex;
		flex-direction: column;
		gap: 6rem;
	}

	.post-item {
		position: relative;
		border-top: 1px solid var(--border);
		padding-top: 3rem;
		transition: all 0.5s ease;
	}

	.post-item:hover {
		border-top-color: var(--accent);
		opacity: 0.5;
	}

	.post-link {
		text-decoration: none;
		color: inherit;
		border: none;
	}

	.post-link:hover {
		border: none;
	}

	.post-content {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.post-meta {
		flex-shrink: 0;
	}

	.post-topic {
		font-size: 0.875rem;
		color: var(--accent);
		font-family: monospace;
	}

	.post-main {
		flex: 1;
	}

	h3 {
		font-size: clamp(1.875rem, 4vw, 2.5rem);
		font-weight: 300;
		margin: 0 0 1rem 0;
		transition: color 0.3s ease;
		line-height: 1.2;
	}

	.post-item:hover h3 {
		color: var(--accent);
	}

	.post-excerpt {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 1.5rem 0;
		max-width: 42rem;
	}

	.post-info {
		display: flex;
		align-items: center;
		gap: 1rem;
		font-size: 0.875rem;
		color: var(--muted-foreground);
	}

	.post-arrow {
		flex-shrink: 0;
		align-self: flex-start;
	}

	.post-arrow svg {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 3rem;
		height: 3rem;
		border-radius: 50%;
		border: 1px solid var(--border);
		padding: 0.75rem;
		color: var(--muted-foreground);
		transition: all 0.3s ease;
	}

	.post-item:hover .post-arrow svg {
		border-color: var(--accent);
		background: color-mix(in oklch, var(--accent) 5%, transparent);
		color: var(--accent);
	}

	/* Archive Section */
	.archive-section {
		margin-top: 8rem;
		padding-top: 4rem;
		border-top: 1px solid var(--border);
	}

	.archive-heading {
		font-size: clamp(1.5rem, 3vw, 2rem);
		font-weight: 300;
		margin: 0 0 1rem 0;
		color: var(--muted-foreground);
	}

	.archive-description {
		color: var(--muted-foreground);
		max-width: 42rem;
		margin: 0 0 3rem 0;
		line-height: 1.6;
	}

	.archive-posts {
		gap: 3rem;
	}

	.archive-item {
		opacity: 0.8;
	}

	.archive-item h4 {
		font-size: clamp(1.25rem, 3vw, 1.75rem);
		font-weight: 300;
		margin: 0 0 0.75rem 0;
		transition: color 0.3s ease;
		line-height: 1.2;
	}

	.archive-item:hover {
		opacity: 1;
	}

	.archive-item:hover h4 {
		color: var(--accent);
	}

	@media (min-width: 768px) {
		.post-content {
			flex-direction: row;
			gap: 4rem;
		}

		.post-meta {
			width: 8rem;
		}

		.post-arrow {
			align-self: center;
		}
	}
</style>
