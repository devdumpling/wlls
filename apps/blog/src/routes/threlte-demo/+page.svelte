<script lang="ts">
import type { ComponentType } from "svelte";
import { onMount } from "svelte";

// Dynamic import to prevent Three.js from being included in SSR bundle
// Three.js uses setTimeout in global scope, which is not allowed in Cloudflare Workers
let ThrelteDemo: ComponentType | null = $state(null);
let loading = $state(true);

onMount(async () => {
	const module = await import("$lib/components/ThrelteDemo.svelte");
	ThrelteDemo = module.default;
	loading = false;
});
</script>

<svelte:head>
	<title>Threlte Demo - wlls.dev</title>
</svelte:head>

<div class="demo-page">
	<h1>Threlte 3D Demo</h1>
	<p>
		A simple 3D scene using Threlte - a declarative Three.js framework for
		Svelte.
	</p>

	{#if loading}
		<div class="loading">Loading 3D scene...</div>
	{:else if ThrelteDemo}
		<ThrelteDemo />
	{/if}

	<div class="info">
		<h2>About this scene</h2>
		<p>
			This scene features two nested icosahedron geometries rotating at
			different speeds. The wireframe outer geometry rotates slowly while the
			solid inner geometry rotates in the opposite direction. The scene uses
			ambient and directional lighting with OrbitControls for camera
			interaction.
		</p>
		<p>
			Try dragging to rotate the camera view, or just watch the automatic
			rotation.
		</p>
	</div>
</div>

<style>
	.demo-page {
		max-width: 56rem;
		margin: 0 auto;
		padding: 4rem 1.5rem;
	}

	h1 {
		font-size: clamp(2rem, 4vw, 3rem);
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	h2 {
		font-size: 1.5rem;
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	p {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 2rem 0;
	}

	.info {
		margin-top: 3rem;
	}

	.loading {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 400px;
		color: var(--muted-foreground);
		background: oklch(0.1 0.01 106);
		border-radius: 0.5rem;
	}
</style>
