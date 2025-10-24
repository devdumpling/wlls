<section class="hero">
	<div class="floating-elements">
		<!-- Abstract shapes with interesting details -->

		<!-- Circle with a missing chunk and inner dot -->
		<div class="shape shape-circle">
			<div class="inner-dot"></div>
		</div>

		<!-- Square rotated 45deg with gradient border -->
		<div class="shape shape-square"></div>

		<!-- Triangle with subtle animation -->
		<div class="shape shape-triangle"></div>

		<!-- Line that slowly rotates -->
		<div class="shape shape-line"></div>
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

	.shape {
		position: absolute;
		opacity: 0.08;
	}

	/* Circle with missing chunk and inner dot */
	.shape-circle {
		width: 200px;
		height: 200px;
		top: 15%;
		right: 20%;
		border: 2px solid var(--accent);
		border-radius: 50%;
		animation: rotate-circle 25s linear infinite, drift-subtle 18s ease-in-out infinite;
	}

	/* Create the missing chunk using a background-colored wedge */
	.shape-circle::before {
		content: '';
		position: absolute;
		width: 30px;
		height: 30px;
		background: var(--background);
		top: 50%;
		right: -2px;
		transform: translateY(-50%) rotate(45deg);
		z-index: 1;
	}

	.inner-dot {
		position: absolute;
		width: 8px;
		height: 8px;
		background: var(--accent);
		border-radius: 50%;
		top: 50%;
		right: 10px;
		transform: translateY(-50%);
		z-index: 2;
	}

	@keyframes rotate-circle {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes drift-subtle {
		0%, 100% {
			transform: translate(0, 0) rotate(0deg);
		}
		33% {
			transform: translate(15px, -10px) rotate(120deg);
		}
		66% {
			transform: translate(-10px, 8px) rotate(240deg);
		}
	}

	/* Square rotated with gradient-like effect using multiple borders */
	.shape-square {
		width: 120px;
		height: 120px;
		bottom: 25%;
		left: 15%;
		border: 2px solid var(--accent);
		transform: rotate(45deg);
		animation: rotate-slow 30s linear infinite, drift-square 22s ease-in-out infinite;
		box-shadow:
			inset 0 0 0 1px oklch(0.7 0.18 340),
			inset 0 0 0 2px oklch(0.65 0.15 45);
	}

	/* Triangle */
	.shape-triangle {
		width: 0;
		height: 0;
		border-left: 60px solid transparent;
		border-right: 60px solid transparent;
		border-bottom: 100px solid var(--accent);
		top: 60%;
		right: 25%;
		animation: pulse-subtle 8s ease-in-out infinite, drift-triangle 20s ease-in-out infinite;
	}

	/* Rotating line */
	.shape-line {
		width: 150px;
		height: 2px;
		background: linear-gradient(
			to right,
			transparent,
			var(--accent),
			transparent
		);
		top: 35%;
		left: 25%;
		transform-origin: center;
		animation: rotate-line 25s linear infinite, drift-line 24s ease-in-out infinite;
	}

	@keyframes drift-slow {
		0%, 100% {
			transform: translate(0, 0) rotate(0deg);
		}
		33% {
			transform: translate(20px, -15px) rotate(5deg);
		}
		66% {
			transform: translate(-15px, 10px) rotate(-3deg);
		}
	}

	@keyframes rotate-slow {
		from {
			transform: rotate(45deg);
		}
		to {
			transform: rotate(405deg);
		}
	}

	@keyframes pulse-subtle {
		0%, 100% {
			opacity: 0.08;
			transform: scale(1);
		}
		50% {
			opacity: 0.12;
			transform: scale(1.05);
		}
	}

	@keyframes rotate-line {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes drift-square {
		0%, 100% {
			transform: translate(0, 0) rotate(45deg);
		}
		50% {
			transform: translate(-12px, 10px) rotate(45deg);
		}
	}

	@keyframes drift-triangle {
		0%, 100% {
			transform: translate(0, 0);
		}
		50% {
			transform: translate(10px, -8px);
		}
	}

	@keyframes drift-line {
		0%, 100% {
			transform: translate(0, 0);
		}
		50% {
			transform: translate(-8px, 12px);
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
