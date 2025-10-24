<script lang="ts">
import ThrelteDemo from "$lib/components/ThrelteDemo.svelte";
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

	<ThrelteDemo />

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
</style>
