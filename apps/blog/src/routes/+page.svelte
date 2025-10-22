<script>
	import BlogHero from "$lib/components/BlogHero.svelte";
	import { resolve } from "$app/paths";
</script>

<main>
	<BlogHero />

	<section class="quick-links">
		<nav class="links">
			<a href={resolve("/blog")}>→ blog</a>
			<a href={resolve("/whois")}>→ whois</a>
		</nav>
	</section>
</main>

<style>
	main {
		min-height: 100vh;
	}

	.quick-links {
		padding: 4rem 1.5rem;
		max-width: 56rem;
		margin: 0 auto;
		text-align: center;
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
		border-bottom: 1px dotted transparent;
		transition: all 0.3s ease;
	}

	.links a:hover {
		border-bottom-color: var(--accent);
		color: var(--accent);
	}
</style>
