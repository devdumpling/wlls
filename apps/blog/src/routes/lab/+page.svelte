<script lang="ts">
const experiments = [
	{
		title: "GPU Lab",
		description:
			"WebGPU compute shaders, simulations, and visual effects running directly on your graphics card.",
		href: "/lab/gpu",
		tech: "WebGPU + TypeGPU",
	},
	{
		title: "3D Lab",
		description:
			"WebGL experiments with Threlte and Three.js. Wireframe geometries, particles, and abstract structures.",
		href: "/lab/3d",
		tech: "Threlte + Three.js",
	},
];
</script>

<svelte:head>
	<title>Lab - wlls.dev</title>
</svelte:head>

<section class="lab-index">
	<div class="lab-header">
		<h1>Lab</h1>
		<p class="description">
			Experiments with graphics, compute, and interactive visualizations. A place to tinker.
		</p>
	</div>

	<div class="experiments-grid">
		{#each experiments as experiment}
			<a href={experiment.href} class="experiment-card">
				<div class="card-content">
					<h2>{experiment.title}</h2>
					<p>{experiment.description}</p>
				</div>
				<span class="tech-badge">{experiment.tech}</span>
			</a>
		{/each}
	</div>
</section>

<style>
	.lab-index {
		max-width: 88rem;
		margin: 0 auto;
		padding: 8rem 1.5rem;
	}

	.lab-header {
		margin-bottom: 4rem;
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

	.experiments-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
		gap: 1.5rem;
	}

	.experiment-card {
		display: flex;
		flex-direction: column;
		justify-content: space-between;
		padding: 1.75rem;
		background: var(--background);
		border: 1px solid var(--border);
		border-radius: 0.5rem;
		text-decoration: none;
		color: inherit;
		transition:
			border-color 0.15s,
			transform 0.15s;
		min-height: 180px;
	}

	.experiment-card:hover {
		border-color: var(--accent);
		transform: translateY(-2px);
	}

	.card-content h2 {
		font-size: 1.5rem;
		font-weight: 400;
		margin: 0 0 0.75rem 0;
	}

	.card-content p {
		margin: 0;
		color: var(--muted-foreground);
		font-size: 0.9375rem;
		line-height: 1.6;
	}

	.tech-badge {
		display: inline-block;
		font-size: 0.75rem;
		font-family: monospace;
		padding: 0.25rem 0.5rem;
		background: color-mix(in oklch, var(--accent) 10%, transparent);
		border: 1px solid color-mix(in oklch, var(--accent) 30%, transparent);
		border-radius: 0.25rem;
		color: var(--accent);
		margin-top: 1rem;
		align-self: flex-start;
	}
</style>
