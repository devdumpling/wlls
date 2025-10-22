<script lang="ts">
	import { onMount } from 'svelte';
	import type { TocItem } from "$lib/types";
	import { throttle } from "$lib/utils";

	let { items }: { items: TocItem[] } = $props();

	let activeSection = $state('');

	onMount(() => {
		const handleScroll = () => {
			// Find all h2 headings with IDs
			const headings = document.querySelectorAll('h2[id]');
			let current = '';

			// Find the heading that's currently visible at the top of the viewport
			headings.forEach((heading) => {
				const rect = heading.getBoundingClientRect();
				// Consider a heading active if it's within 100px of the top
				if (rect.top <= 100 && rect.top >= -100) {
					current = heading.id;
				}
			});

			// If no heading is in the sweet spot, use the last one that's above the viewport
			if (!current) {
				headings.forEach((heading) => {
					const rect = heading.getBoundingClientRect();
					if (rect.top <= 100) {
						current = heading.id;
					}
				});
			}

			activeSection = current;
		};

		// Throttle scroll handler to run at most every 100ms
		const throttledScroll = throttle(handleScroll, 100);

		// Run once on mount
		handleScroll();

		window.addEventListener('scroll', throttledScroll, { passive: true });
		return () => window.removeEventListener('scroll', throttledScroll);
	});

	// Smooth scroll to heading
	function scrollToHeading(id: string, event: MouseEvent) {
		event.preventDefault();
		const element = document.getElementById(id);
		if (element) {
			const offset = 80; // Account for fixed nav
			const elementPosition = element.getBoundingClientRect().top;
			const offsetPosition = elementPosition + window.scrollY - offset;

			window.scrollTo({
				top: offsetPosition,
				behavior: 'smooth'
			});
		}
	}
</script>

{#if items.length > 0}
	<aside class="table-of-contents">
		<nav>
			<p class="toc-title">Contents</p>
			<ul>
				{#each items as item (item.id)}
					<li>
						<a
							href="#{item.id}"
							class="toc-link"
							class:active={activeSection === item.id}
							aria-current={activeSection === item.id ? 'location' : undefined}
							onclick={(e) => scrollToHeading(item.id, e)}
						>
							{item.text}
						</a>
					</li>
				{/each}
			</ul>
		</nav>
	</aside>
{/if}

<style>
	.table-of-contents {
		display: none;
	}

	/* Only show on large screens (xl breakpoint: 1280px) */
	@media (min-width: 1280px) {
		.table-of-contents {
			display: block;
			position: fixed;
			left: 2rem;
			top: 50%;
			transform: translateY(-50%);
			width: 12rem;
			z-index: 30;
		}
	}

	.toc-title {
		font-size: 0.75rem;
		font-family: monospace;
		color: var(--muted-foreground);
		margin: 0 0 1rem 0;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	ul {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	li {
		margin: 0;
	}

	.toc-link {
		display: block;
		font-size: 0.875rem;
		color: var(--muted-foreground);
		text-decoration: none;
		border: none;
		transition: color 0.3s ease;
		line-height: 1.4;
	}

	.toc-link:hover {
		color: var(--foreground);
		border: none;
	}

	.toc-link.active {
		color: var(--accent);
		font-weight: 500;
	}
</style>
