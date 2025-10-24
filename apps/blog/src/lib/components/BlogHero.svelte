<script lang="ts">
// Lazy load the constellation component
const ConstellationGoL = import('./ConstellationGoL.svelte').then(m => m.default);
</script>

<section class="hero">
	<!-- Lazy-loaded constellation background -->
	<svelte:boundary>
		{#snippet pending()}
			<!-- Show nothing while loading - hero content is visible below -->
		{/snippet}

		{@const Constellation = await ConstellationGoL}
		<Constellation />
	</svelte:boundary>

	<!-- Hero content (always visible) -->
	<div class="hero-content">
		<h1>Dev Wells</h1>
		<p class="tagline">
			Dad, engineer, sometimes writer,
			crafting elegant interfaces, exploring fantasy realms, and
			building worlds through code and story.
		</p>
	</div>
</section>

<style>
	.hero {
		position: relative;
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 5rem 1.5rem;
		overflow: hidden;
	}

	.hero-content {
		max-width: 56rem;
		margin: 0 auto;
		text-align: center;
		position: relative;
		z-index: 10;
	}

	h1 {
		font-size: clamp(3rem, 10vw, 6rem);
		font-weight: 300;
		letter-spacing: -0.03em;
		margin: 0 0 2rem 0;
		line-height: 1.1;
	}

	.tagline {
		font-size: clamp(1.125rem, 2.5vw, 1.5rem);
		color: var(--muted-foreground);
		font-weight: 300;
		line-height: 1.6;
		max-width: 42rem;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		h1 {
			font-size: clamp(4rem, 10vw, 8rem);
		}
	}
</style>
