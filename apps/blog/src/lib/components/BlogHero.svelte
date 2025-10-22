<section class="hero">
	<div class="floating-elements">
		<div class="dot dot-1 animate-float"></div>
		<div class="dot dot-2 animate-drift"></div>
		<div class="dot dot-3 animate-float"></div>
		<div class="dot dot-4 animate-drift"></div>
	</div>

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

	.floating-elements {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.dot {
		position: absolute;
		border-radius: 50%;
		background: var(--accent);
	}

	.dot-1 {
		top: 5rem;
		left: 10%;
		width: 0.5rem;
		height: 0.5rem;
		opacity: 0.2;
	}

	.dot-2 {
		top: 10rem;
		right: 15%;
		width: 0.75rem;
		height: 0.75rem;
		opacity: 0.1;
		animation-delay: 1s;
	}

	.dot-3 {
		bottom: 8rem;
		left: 20%;
		width: 0.5rem;
		height: 0.5rem;
		opacity: 0.15;
		animation-delay: 2s;
	}

	.dot-4 {
		top: 60%;
		right: 25%;
		width: 1rem;
		height: 1rem;
		opacity: 0.1;
		animation-delay: 3s;
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
