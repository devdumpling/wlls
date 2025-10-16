<script>
	import { resolve } from "$app/paths";
</script>

<main class="landing">
	<h1>wlls.dev</h1>
	<p class="intro">Software engineer, tinkerer, writer.</p>

	<nav class="links">
		<a href={resolve("/blog")}>→ blog</a>
		<a href={resolve("/whois")}>→ whois</a>
	</nav>
</main>

<style>
	.landing {
		margin-top: 4rem;
	}

	h1 {
		font-size: 2rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
	}

	.intro {
		color: #666;
		margin-bottom: 2rem;
	}

	.links {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.links a {
		color: inherit;
		text-decoration: none;
		border-bottom: none;
	}

	.links a:hover {
		border-bottom: 1px solid currentColor;
	}

	@media (prefers-color-scheme: dark) {
		.intro {
			color: #999;
		}
	}
</style>
