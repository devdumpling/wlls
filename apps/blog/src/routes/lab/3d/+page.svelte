<script lang="ts">
import type { Component } from "svelte";
import { onMount } from "svelte";

// NOTE: Using onMount pattern instead of experimental async (<svelte:boundary> + await)
// because Threlte's context API is incompatible with async boundaries as of Svelte 5.3.
// When components load through <svelte:boundary>, they lose the reactive context that
// Threlte's useTask depends on, breaking animations.
// TODO: Check if Threlte has updated to work with experimental async boundaries
// See: https://svelte.dev/docs/svelte/svelte-boundary
let ThrelteScene: Component | null = null;
let loading = true;

onMount(async () => {
	try {
		const module = await import("$lib/components/ThrelteScene.svelte");
		ThrelteScene = module.default;
	} finally {
		loading = false;
	}
});
</script>

<svelte:head>
	<title>3D Lab - wlls.dev</title>
</svelte:head>

<section class="lab-page">
	<div class="lab-header">
		<a href="/lab" class="back-link">&larr; Lab</a>
		<h1>3D Lab</h1>
		<p class="description">
			Experiments with WebGL, 3D graphics, and interactive visualizations.
		</p>
	</div>

	<div class="scene-container">
		{#if loading}
			<div class="scene-loading">
				<div class="spinner"></div>
				<p>Loading 3D scene...</p>
			</div>
		{:else if ThrelteScene}
			<ThrelteScene />
		{/if}
	</div>

	<div class="scene-info">
		<h2>3D Scene</h2>
		<p>
			Built with <a href="https://threlte.xyz" target="_blank">Threlte</a> and
			Three.js. Features wireframe dice geometries (d4, d8, d20), flowing
			particles, and abstract branch structures.
		</p>
		<p class="tech-note">
			This scene uses ~190KB of gzipped JavaScript. That's why it lives here
			instead of the landing page.
		</p>
	</div>
</section>

<style>
	.lab-page {
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

	.scene-container {
		width: 100%;
		height: 600px;
		border-radius: 0.5rem;
		overflow: hidden;
		margin-bottom: 3rem;
		border: 1px solid var(--border);
	}

	.scene-info {
		max-width: 42rem;
	}

	h2 {
		font-size: 1.5rem;
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	.scene-info p {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 1rem 0;
	}

	.tech-note {
		font-size: 0.875rem;
		font-family: monospace;
		color: var(--accent);
	}

	.scene-info a {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px dashed var(--accent);
	}

	.scene-info a:hover {
		border-bottom-style: solid;
	}

	.scene-loading {
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		color: var(--muted-foreground);
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid var(--border);
		border-top-color: var(--accent);
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@media (min-width: 768px) {
		.scene-container {
			height: 800px;
		}
	}
</style>
