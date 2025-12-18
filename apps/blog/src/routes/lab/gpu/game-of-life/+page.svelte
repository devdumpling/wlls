<script lang="ts">
	import { onMount } from "svelte";

	import type { ComponentType } from "svelte";

	// Dynamic import to keep bundle small for non-GPU pages
	let GameOfLife: ComponentType | null = null;
	let loading = true;

	onMount(async () => {
		try {
			const module = await import("$lib/components/gpu/GameOfLife.svelte");
			GameOfLife = module.default;
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Game of Life - GPU Lab - wlls.dev</title>
</svelte:head>

<section class="demo-page">
	<div class="demo-header">
		<h1>Game of Life</h1>
		<p class="description">
			Conway's cellular automaton running entirely on GPU compute shaders.
			Each cell follows simple rules: live cells with 2-3 neighbors survive,
			dead cells with exactly 3 neighbors become alive.
		</p>
	</div>

	<div class="demo-container">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading demo...</p>
			</div>
		{:else if GameOfLife}
			<GameOfLife gridSize={256} tickRate={50} />
		{/if}
	</div>

	<div class="demo-info">
		<h2>How it works</h2>
		<p>
			This simulation uses WebGPU compute shaders to update all cells in
			parallel. A 256x256 grid means 65,536 cells are processed simultaneously
			on your GPU each frame.
		</p>

		<h3>The Compute Shader</h3>
		<p>
			Unlike traditional CPU code that processes one cell at a time, a <strong>compute shader</strong>
			runs the same code across thousands of GPU threads simultaneously. Each thread handles
			one cell, counting its neighbors and applying Conway's rules.
		</p>
		<p>
			The shader is organized into <strong>workgroups</strong> of 8x8 threads (64 threads per group).
			For a 256x256 grid, we dispatch 32x32 = 1,024 workgroups, giving us the full 65,536 threads
			needed to process every cell in parallel.
		</p>

		<h3>Double Buffering</h3>
		<p>
			Here's a subtle problem: if all threads read and write to the same buffer,
			we get <strong>race conditions</strong>. Thread A might read a neighbor's state
			before Thread B has finished updating it, causing incorrect results.
		</p>
		<p>
			The solution is <strong>ping-pong buffering</strong>: we maintain two cell state buffers.
			All threads read from Buffer A and write to Buffer B. Next frame, they read from B
			and write to A. The buffers alternate, ensuring reads never conflict with writes.
		</p>

		<h3>Instanced Rendering</h3>
		<p>
			Drawing 65,536 individual quads would be slow. Instead, we use <strong>instancing</strong>:
			the GPU draws a single quad template 65,536 times, with each instance positioned based
			on its <code>instance_index</code>. The vertex shader calculates cell position, and the
			fragment shader reads cell state from the storage buffer to determine color.
		</p>

		<h3>WebGPU vs WebGL</h3>
		<p>
			WebGL (based on OpenGL ES) lacks compute shaders entirely. To run Game of Life on WebGL,
			you'd hack it through fragment shaders rendering to textures—awkward and limited.
			WebGPU provides first-class compute support, enabling true GPGPU (General-Purpose GPU)
			computing in the browser.
		</p>

		<h3>Tech Stack</h3>
		<ul>
			<li><strong>TypeGPU</strong> - Type-safe WebGPU toolkit for device initialization</li>
			<li><strong>WGSL</strong> - WebGPU Shading Language for compute and render shaders</li>
			<li><strong>Storage buffers</strong> - GPU memory for cell state (read/write from shaders)</li>
			<li><strong>Uniform buffers</strong> - GPU memory for constants like grid dimensions</li>
		</ul>
	</div>
</section>

<style>
	.demo-page {
		max-width: 88rem;
		margin: 0 auto;
		padding: 8rem 1.5rem 4rem;
	}

	.demo-header {
		margin-bottom: 2rem;
	}

	h1 {
		font-size: clamp(2rem, 4vw, 2.5rem);
		font-weight: 300;
		margin: 0 0 0.75rem 0;
	}

	.description {
		color: var(--muted-foreground);
		font-size: 1rem;
		max-width: 42rem;
		line-height: 1.6;
		margin: 0;
	}

	.demo-container {
		width: 100%;
		height: 600px;
		border-radius: 0.5rem;
		overflow: hidden;
		margin-bottom: 3rem;
		border: 1px solid var(--border);
	}

	.loading {
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		background: oklch(0.1 0.01 106);
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

	.demo-info {
		max-width: 42rem;
	}

	.demo-info h2 {
		font-size: 1.5rem;
		font-weight: 300;
		margin: 0 0 1rem 0;
	}

	.demo-info h3 {
		font-size: 1.125rem;
		font-weight: 500;
		margin: 2rem 0 0.75rem 0;
	}

	.demo-info p {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 1rem 0;
	}

	.demo-info ul {
		margin: 0;
		padding: 0 0 0 1.5rem;
		color: var(--muted-foreground);
		line-height: 1.8;
	}

	.demo-info li strong {
		color: var(--foreground);
	}

	.demo-info code {
		font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, monospace;
		font-size: 0.875em;
		padding: 0.125rem 0.375rem;
		background: var(--border);
		border-radius: 0.25rem;
	}

	@media (min-width: 768px) {
		.demo-container {
			height: 700px;
		}
	}
</style>
