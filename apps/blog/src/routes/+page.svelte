<script>
import BlogHero from "$lib/components/BlogHero.svelte";
</script>

<BlogHero />

<section class="quick-links">
	<nav class="links">
		<a href="/blog">→ blog</a>
		<a href="/whois">→ whois</a>
		<a href="/lab">→ lab</a>
	</nav>
</section>

<style>
	.quick-links {
		position: fixed;
		bottom: 2rem;
		left: 0;
		right: 0;
		text-align: center;
		z-index: 10;
	}

	.links {
		display: flex;
		flex-direction: row;
		gap: 2rem;
		justify-content: center;
		font-size: 1.125rem;
	}

	.links a {
		color: var(--muted-foreground);
		text-decoration: none;
		border-bottom: 1px dashed transparent;
		transition: all 0.2s ease;
		display: inline-block;
	}

	.links a:hover {
		border-bottom-color: var(--accent);
		color: var(--accent);
	}

	.links a:active {
		transform: scale(0.92);
	}
</style>
