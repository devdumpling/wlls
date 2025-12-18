<script lang="ts">
	import { onMount } from "svelte";
	import type { ComponentType } from "svelte";
	import CodeBlock from "$lib/components/CodeBlock.svelte";

	type Implementation = "raw" | "typegpu";

	let implementation = $state<Implementation>("typegpu");
	let GameOfLifeRaw: ComponentType | null = $state(null);
	let GameOfLifeTypeGPU: ComponentType | null = $state(null);
	let loading = $state(true);

	// Dynamic imports to keep bundles small
	onMount(async () => {
		try {
			const [rawModule, typegpuModule] = await Promise.all([
				import("$lib/components/gpu/GameOfLife.svelte"),
				import("$lib/components/gpu/GameOfLifeTypeGPU.svelte"),
			]);
			GameOfLifeRaw = rawModule.default;
			GameOfLifeTypeGPU = typegpuModule.default;
		} finally {
			loading = false;
		}
	});

	function setImplementation(impl: Implementation) {
		implementation = impl;
	}
</script>

<svelte:head>
	<title>Game of Life - GPU Lab - wlls.dev</title>
</svelte:head>

<section class="demo-page">
	<div class="demo-header">
		<h1>Game of Life</h1>
		<p class="description">
			Conway's cellular automaton running entirely on GPU compute shaders.
			Compare two implementations: raw WebGPU vs TypeGPU's higher-level API.
		</p>

		<div class="implementation-toggle">
			<button
				class="toggle-btn"
				class:active={implementation === "typegpu"}
				onclick={() => setImplementation("typegpu")}
			>
				TypeGPU
			</button>
			<button
				class="toggle-btn"
				class:active={implementation === "raw"}
				onclick={() => setImplementation("raw")}
			>
				Raw WebGPU
			</button>
		</div>
	</div>

	<div class="demo-container">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading demo...</p>
			</div>
		{:else if implementation === "typegpu" && GameOfLifeTypeGPU}
			<GameOfLifeTypeGPU gridSize={256} tickRate={50} />
		{:else if implementation === "raw" && GameOfLifeRaw}
			<GameOfLifeRaw gridSize={256} tickRate={50} />
		{/if}
	</div>

	<div class="demo-info">
		{#if implementation === "typegpu"}
			<h2>TypeGPU Implementation</h2>
			<p>
				This version uses <a href="https://docs.swmansion.com/TypeGPU/" target="_blank">TypeGPU</a>'s
				higher-level APIs. The code is more declarative and type-safe, with less boilerplate.
			</p>

			<h3>Key Differences</h3>

			<h4>1. Typed Buffers</h4>
			<p>Instead of manually calculating sizes and handling serialization:</p>
			<CodeBlock code={`// Raw WebGPU
const buffer = device.createBuffer({
  size: cellCount * 4,  // Manual size calculation
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(buffer, 0, new Uint32Array(data));

// TypeGPU
const CellArray = d.arrayOf(d.u32, cellCount);
const buffer = root.createBuffer(CellArray, data).$usage("storage");`} />

			<h4>2. Declarative Bind Group Layouts</h4>
			<p>Named keys instead of numeric binding indices:</p>
			<CodeBlock code={`// Raw WebGPU
const layout = device.createBindGroupLayout({
  entries: [
    { binding: 0, buffer: { type: "uniform" } },
    { binding: 1, buffer: { type: "read-only-storage" } },
    { binding: 2, buffer: { type: "storage" } },
  ],
});

// TypeGPU
const layout = tgpu.bindGroupLayout({
  uniforms: { uniform: GridUniforms },
  cellStateIn: { storage: CellStateArray, access: "readonly" },
  cellStateOut: { storage: CellStateArray, access: "mutable" },
});`} />

			<h4>3. Cleaner Pipeline Execution</h4>
			<p>Fluent API instead of command encoder boilerplate:</p>
			<CodeBlock code={`// Raw WebGPU
const encoder = device.createCommandEncoder();
const pass = encoder.beginComputePass();
pass.setPipeline(pipeline);
pass.setBindGroup(0, bindGroup);
pass.dispatchWorkgroups(32, 32);
pass.end();
device.queue.submit([encoder.finish()]);

// TypeGPU
computePipeline
  .with(layout, bindGroup)
  .dispatchWorkgroups(32, 32);`} />

			<h4>4. Shader Functions with $uses()</h4>
			<p>
				The <code>$uses()</code> method injects bind group members into shaders,
				making dependencies explicit and type-checked.
			</p>

		{:else}
			<h2>Raw WebGPU Implementation</h2>
			<p>
				This version uses the WebGPU API directly. It's more verbose but shows
				exactly what's happening at the lowest level.
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
		{/if}

		<h3>Tech Stack</h3>
		<ul>
			<li><strong>TypeGPU</strong> - Type-safe WebGPU toolkit</li>
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
		margin: 0 0 1.5rem 0;
	}

	.implementation-toggle {
		display: flex;
		gap: 0.5rem;
	}

	.toggle-btn {
		padding: 0.5rem 1rem;
		font-size: 0.875rem;
		font-family: monospace;
		color: var(--muted-foreground);
		background: transparent;
		border: 1px solid var(--border);
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.15s;
	}

	.toggle-btn:hover {
		border-color: var(--accent);
		color: var(--foreground);
	}

	.toggle-btn.active {
		background: var(--accent);
		border-color: var(--accent);
		color: white;
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

	.demo-info h4 {
		font-size: 1rem;
		font-weight: 500;
		margin: 1.5rem 0 0.5rem 0;
		color: var(--accent);
	}

	.demo-info p {
		color: var(--muted-foreground);
		line-height: 1.6;
		margin: 0 0 1rem 0;
	}

	.demo-info a {
		color: var(--accent);
		text-decoration: none;
		border-bottom: 1px dashed var(--accent);
	}

	.demo-info a:hover {
		border-bottom-style: solid;
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

	/* Inline code styling (for things like $uses(), instance_index) */
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
