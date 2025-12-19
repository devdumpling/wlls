<script lang="ts">
	import { onMount } from "svelte";

	// Inline WebGPU check to avoid importing $lib/gpu which pulls in typegpu
	const isWebGPUSupported = () =>
		typeof navigator !== "undefined" && "gpu" in navigator;

	const demos = [
		{
			title: "Game of Life",
			description: "Conway's cellular automaton running on GPU compute shaders",
			href: "/lab/gpu/game-of-life",
			status: "live" as const,
		},
	];

	// Track both whether we've checked and whether it's supported
	// This prevents the warning from flashing during SSR/hydration
	let checked = $state(false);
	let supported = $state(false);

	onMount(() => {
		supported = isWebGPUSupported();
		checked = true;
	});
</script>

<svelte:head>
	<title>GPU Lab - wlls.dev</title>
</svelte:head>

<section class="gpu-lab">
	<div class="lab-header">
		<a href="/lab" class="back-link">&larr; Lab</a>
		<h1>GPU Lab</h1>
		<p class="description">
			Experiments with WebGPU and TypeGPU. Compute shaders, simulations, and
			visual effects running directly on your graphics card.
		</p>

		{#if checked && !supported}
			<div class="warning">
				<svg
					width="20"
					height="20"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="2"
				>
					<path
						d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
					/>
				</svg>
				<span>WebGPU not detected. Try Chrome 113+, Edge 113+, or Safari 18+.</span>
			</div>
		{/if}
	</div>

	<div class="demos-grid">
		{#each demos as demo}
			{@const isLive = demo.status === "live"}
			<a
				href={isLive ? demo.href : undefined}
				class="demo-card"
				class:coming={!isLive}
				aria-disabled={!isLive}
			>
				<div class="demo-header">
					<h2>{demo.title}</h2>
					{#if !isLive}
						<span class="badge">Coming Soon</span>
					{/if}
				</div>
				<p>{demo.description}</p>
			</a>
		{/each}
	</div>

	<div class="tech-info">
		<h2>About</h2>
		<p>
			These demos use <a
				href="https://docs.swmansion.com/TypeGPU/"
				target="_blank">TypeGPU</a
			> for device initialization and type-safe WebGPU development. The goal is
			to explore GPU computing through original experiments—not just ports of
			existing examples.
		</p>
		<p class="tech-note">
			WebGPU is the successor to WebGL, providing low-level access to modern GPU
			features including compute shaders for general-purpose GPU computing.
		</p>
	</div>
</section>

<style>
	.gpu-lab {
		max-width: 88rem;
		margin: 0 auto;
		padding: 8rem 1.5rem;
	}

	.lab-header {
		margin-bottom: 4rem;
	}

	.back-link {
		display: inline-block;
		color: var(--muted-foreground);
		text-decoration: none;
		font-size: 0.875rem;
		margin-bottom: 1rem;
		transition: color 0.15s;
	}

	.back-link:hover {
		color: var(--accent);
	}

	h1 {
		font-size: clamp(2.5rem, 5vw, 3.5rem);
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	.description {
		color: var(--muted-foreground);
		font-size: 1.125rem;
		max-width: 42rem;
		line-height: 1.6;
		margin: 0;
	}

	.warning {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-top: 1.5rem;
		padding: 0.875rem 1rem;
		background: oklch(0.95 0.05 45 / 0.5);
		border: 1px solid oklch(0.7 0.15 45);
		border-radius: 0.5rem;
		color: oklch(0.4 0.1 45);
		font-size: 0.875rem;
	}

	@media (prefers-color-scheme: dark) {
		.warning {
			background: oklch(0.25 0.05 45 / 0.5);
			border-color: oklch(0.5 0.1 45);
			color: oklch(0.8 0.1 45);
		}
	}

	.demos-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1.5rem;
		margin-bottom: 4rem;
	}

	.demo-card {
		display: block;
		padding: 1.5rem;
		background: var(--background);
		border: 1px solid var(--border);
		border-radius: 0.5rem;
		text-decoration: none;
		color: inherit;
		transition:
			border-color 0.15s,
			transform 0.15s;
	}

	.demo-card:not(.coming):hover {
		border-color: var(--accent);
		transform: translateY(-2px);
	}

	.demo-card.coming {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.demo-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.demo-card h2 {
		font-size: 1.25rem;
		font-weight: 500;
		margin: 0;
	}

	.badge {
		font-size: 0.75rem;
		font-family: monospace;
		padding: 0.25rem 0.5rem;
		background: var(--border);
		border-radius: 0.25rem;
		color: var(--muted-foreground);
	}

	.demo-card p {
		margin: 0;
		color: var(--muted-foreground);
		font-size: 0.9375rem;
		line-height: 1.5;
	}

	.tech-info {
		max-width: 42rem;
		border-top: 1px solid var(--border);
		padding-top: 2rem;
	}

	.tech-info h2 {
		font-size: 1.5rem;
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	.tech-info p {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 1rem 0;
	}

	.tech-note {
		font-size: 0.875rem;
		font-family: monospace;
		color: var(--accent);
	}

	.tech-info a {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px dashed var(--accent);
	}

	.tech-info a:hover {
		border-bottom-style: solid;
	}
</style>
