<section class="hero">
	<div class="floating-elements">
		<!-- Gradient orbs with CSS animations -->
		<div class="orb orb-1"></div>
		<div class="orb orb-2"></div>
		<div class="orb orb-3"></div>

		<!-- Subtle geometric shapes -->
		<div class="shape shape-1"></div>
		<div class="shape shape-2"></div>
		<div class="shape shape-3"></div>
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
		overflow: hidden;
	}

	/* Gradient orbs */
	.orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(60px);
		opacity: 0.15;
		animation: float 20s ease-in-out infinite;
	}

	.orb-1 {
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, var(--accent), transparent);
		top: 10%;
		left: 10%;
		animation-delay: 0s;
	}

	.orb-2 {
		width: 300px;
		height: 300px;
		background: radial-gradient(circle, #c4a7e7, transparent);
		bottom: 20%;
		right: 15%;
		animation-delay: 7s;
	}

	.orb-3 {
		width: 350px;
		height: 350px;
		background: radial-gradient(circle, #9ccfd8, transparent);
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		animation-delay: 14s;
	}

	/* Geometric shapes */
	.shape {
		position: absolute;
		border: 1px solid var(--accent);
		opacity: 0.1;
		animation: rotate-slow 30s linear infinite;
	}

	.shape-1 {
		width: 80px;
		height: 80px;
		top: 20%;
		right: 20%;
		transform: rotate(45deg);
	}

	.shape-2 {
		width: 120px;
		height: 120px;
		bottom: 30%;
		left: 15%;
		border-radius: 50%;
		animation: pulse 8s ease-in-out infinite;
	}

	.shape-3 {
		width: 60px;
		height: 60px;
		top: 60%;
		right: 30%;
		clip-path: polygon(50% 0%, 100% 100%, 0% 100%);
		animation: drift 12s ease-in-out infinite;
	}

	@keyframes float {
		0%, 100% {
			transform: translate(0, 0);
		}
		33% {
			transform: translate(30px, -30px);
		}
		66% {
			transform: translate(-20px, 20px);
		}
	}

	@keyframes rotate-slow {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes pulse {
		0%, 100% {
			transform: scale(1);
			opacity: 0.1;
		}
		50% {
			transform: scale(1.1);
			opacity: 0.2;
		}
	}

	@keyframes drift {
		0%, 100% {
			transform: translateX(0) translateY(0);
		}
		50% {
			transform: translateX(40px) translateY(-20px);
		}
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
