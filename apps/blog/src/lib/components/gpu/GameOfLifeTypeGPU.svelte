<script lang="ts">
	/**
	 * Game of Life - TypeGPU Version
	 *
	 * This implementation uses TypeGPU's higher-level APIs:
	 * - Type-safe buffers with automatic serialization
	 * - Typed bind group layouts
	 * - TypeScript shader functions with 'use gpu' directive
	 * - Declarative pipeline creation
	 *
	 * Compare with GameOfLife.svelte (raw WebGPU) to see the difference.
	 */
	import { onMount } from "svelte";
	import tgpu, { type TgpuRoot } from "typegpu";
	import * as d from "typegpu/data";
	import {
		isWebGPUSupported,
		getWebGPUUnsupportedReason,
		getPreferredFormat,
	} from "$lib/gpu";

	interface Props {
		gridSize?: number;
		tickRate?: number;
		class?: string;
	}

	let { gridSize = 128, tickRate = 100, class: className = "" }: Props = $props();

	let canvas: HTMLCanvasElement;
	let supported = $state(true);
	let error = $state<string | null>(null);
	let loading = $state(true);
	let paused = $state(false);
	let generation = $state(0);
	let fps = $state(0);

	onMount(() => {
		let root: TgpuRoot | null = null;
		let animationFrame: number;
		let lastTick = 0;
		let destroyed = false;
		let frameCount = 0;
		let lastFpsUpdate = 0;

		async function init() {
			if (!isWebGPUSupported()) {
				supported = false;
				error = getWebGPUUnsupportedReason();
				loading = false;
				return;
			}

			try {
				// ============================================================
				// STEP 1: Initialize TypeGPU Root
				// ============================================================
				// TypeGPU handles the adapter/device dance for us.
				// The root is our gateway to all GPU operations.
				root = await tgpu.init();
				const device = root.device;

				// Configure canvas (still raw WebGPU - TypeGPU doesn't wrap this)
				const context = canvas.getContext("webgpu");
				if (!context) throw new Error("Failed to get WebGPU context");

				const format = getPreferredFormat();
				context.configure({ device, format, alphaMode: "premultiplied" });

				const dpr = window.devicePixelRatio || 1;
				canvas.width = Math.floor(canvas.clientWidth * dpr);
				canvas.height = Math.floor(canvas.clientHeight * dpr);

				// ============================================================
				// STEP 2: Define Data Types with TypeGPU Schemas
				// ============================================================
				// Instead of manually calculating byte sizes and alignments,
				// we define our data structure declaratively.

				// Grid uniforms - TypeGPU handles the struct layout
				const GridUniforms = d.struct({
					width: d.u32,
					height: d.u32,
				});

				// Cell state is just an array of u32 (0 = dead, 1 = alive)
				const cellCount = gridSize * gridSize;
				const CellStateArray = d.arrayOf(d.u32, cellCount);

				// ============================================================
				// STEP 3: Create Typed Buffers
				// ============================================================
				// TypeGPU buffers know their type and handle serialization.
				// No more manual Uint32Array creation and writeBuffer calls.

				// Uniform buffer - note the type-safe initial value
				const uniformBuffer = root
					.createBuffer(GridUniforms, { width: gridSize, height: gridSize })
					.$usage("uniform");

				// Create initial random state
				const initialState: number[] = [];
				for (let i = 0; i < cellCount; i++) {
					initialState.push(Math.random() < 0.15 ? 1 : 0);
				}

				// Cell state buffers for ping-pong
				// The .$usage() method is chainable and type-safe
				const cellStateA = root
					.createBuffer(CellStateArray, initialState)
					.$usage("storage");

				const cellStateB = root
					.createBuffer(CellStateArray)
					.$usage("storage");

				// ============================================================
				// STEP 4: Define Bind Group Layouts
				// ============================================================
				// TypeGPU layouts are declarative and type-checked.
				// The keys become the variable names in shaders.

				const computeLayout = tgpu.bindGroupLayout({
					uniforms: { uniform: GridUniforms },
					cellStateIn: { storage: CellStateArray, access: "readonly" },
					cellStateOut: { storage: CellStateArray, access: "mutable" },
				});

				const renderLayout = tgpu.bindGroupLayout({
					uniforms: { uniform: GridUniforms },
					cellState: { storage: CellStateArray, access: "readonly" },
				});

				// ============================================================
				// STEP 5: Create Bind Groups
				// ============================================================
				// Bind groups connect our buffers to the layout slots.
				// TypeGPU validates that buffer types match layout expectations.

				const computeBindGroups = [
					root.createBindGroup(computeLayout, {
						uniforms: uniformBuffer,
						cellStateIn: cellStateA,
						cellStateOut: cellStateB,
					}),
					root.createBindGroup(computeLayout, {
						uniforms: uniformBuffer,
						cellStateIn: cellStateB,
						cellStateOut: cellStateA,
					}),
				];

				const renderBindGroups = [
					root.createBindGroup(renderLayout, {
						uniforms: uniformBuffer,
						cellState: cellStateA,
					}),
					root.createBindGroup(renderLayout, {
						uniforms: uniformBuffer,
						cellState: cellStateB,
					}),
				];

				// ============================================================
				// STEP 6: Define Compute Shader
				// ============================================================
				// Here we use TypeGPU's computeFn with WGSL template.
				// The $uses() method injects our bind group layout.
				//
				// NOTE: We could also use 'use gpu' TypeScript functions here,
				// but WGSL templates are more explicit for learning.

				const computeMain = tgpu["~unstable"]
					.computeFn({
						workgroupSize: [8, 8, 1],
						in: { gid: d.builtin.globalInvocationId },
					})
					/* wgsl */ `{
						let x = in.gid.x;
						let y = in.gid.y;

						if (x >= uniforms.width || y >= uniforms.height) {
							return;
						}

						// Helper to get cell index with wrapping
						let width = uniforms.width;
						let height = uniforms.height;

						// Count neighbors (with toroidal wrapping)
						var neighbors: u32 = 0;

						for (var dy: i32 = -1; dy <= 1; dy++) {
							for (var dx: i32 = -1; dx <= 1; dx++) {
								if (dx == 0 && dy == 0) { continue; }

								let nx = (i32(x) + dx + i32(width)) % i32(width);
								let ny = (i32(y) + dy + i32(height)) % i32(height);
								let idx = u32(ny) * width + u32(nx);
								neighbors += cellStateIn[idx];
							}
						}

						let idx = y * width + x;
						let alive = cellStateIn[idx];

						// Conway's rules:
						// - Live cell with 2-3 neighbors survives
						// - Dead cell with exactly 3 neighbors becomes alive
						// - All other cells die or stay dead
						if (alive == 1 && (neighbors == 2 || neighbors == 3)) {
							cellStateOut[idx] = 1;
						} else if (alive == 0 && neighbors == 3) {
							cellStateOut[idx] = 1;
						} else {
							cellStateOut[idx] = 0;
						}
					}`
					.$uses({ uniforms: computeLayout.bound.uniforms, cellStateIn: computeLayout.bound.cellStateIn, cellStateOut: computeLayout.bound.cellStateOut });

				// ============================================================
				// STEP 7: Define Render Shaders
				// ============================================================
				// Vertex and fragment shaders for instanced quad rendering.

				const vertexMain = tgpu["~unstable"]
					.vertexFn({
						in: {
							vertexIndex: d.builtin.vertexIndex,
							instanceIndex: d.builtin.instanceIndex,
						},
						out: {
							position: d.builtin.position,
							cell: d.vec2f,
						},
					})
					/* wgsl */ `{
						let i = f32(in.instanceIndex);
						let cellCoord = vec2f(i % f32(uniforms.width), floor(i / f32(uniforms.width)));

						// Quad vertices (2 triangles = 6 vertices)
						var pos: array<vec2f, 6> = array<vec2f, 6>(
							vec2f(0, 0), vec2f(1, 0), vec2f(0, 1),
							vec2f(0, 1), vec2f(1, 0), vec2f(1, 1)
						);

						let cellOffset = cellCoord / vec2f(f32(uniforms.width), f32(uniforms.height)) * 2 - 1;
						let cellSize = 2.0 / vec2f(f32(uniforms.width), f32(uniforms.height));

						let vertPos = cellOffset + pos[in.vertexIndex] * cellSize;

						// TypeGPU uses Out() constructor to return vertex outputs
						// Arguments match order in 'out' definition: position, then cell
						return Out(vec4f(vertPos.x, -vertPos.y, 0, 1), cellCoord);
					}`
					.$uses({ uniforms: renderLayout.bound.uniforms });

				const fragmentMain = tgpu["~unstable"]
					.fragmentFn({
						in: { cell: d.vec2f },
						out: d.location(0, d.vec4f),
					})
					/* wgsl */ `{
						let idx = u32(in.cell.y) * uniforms.width + u32(in.cell.x);
						let alive = cellState[idx];

						if (alive == 1) {
							return vec4f(0.9, 0.55, 0.2, 1.0); // Accent color (orange)
						} else {
							return vec4f(0.1, 0.1, 0.1, 1.0); // Dark background
						}
					}`
					.$uses({ uniforms: renderLayout.bound.uniforms, cellState: renderLayout.bound.cellState });

				// ============================================================
				// STEP 8: Create Pipelines
				// ============================================================
				// TypeGPU's pipeline builder validates shader compatibility.

				const computePipeline = root["~unstable"]
					.withCompute(computeMain)
					.createPipeline();

				const renderPipeline = root["~unstable"]
					.withVertex(vertexMain, {})
					.withFragment(fragmentMain, { format })
					.createPipeline();

				// ============================================================
				// STEP 9: Animation Loop
				// ============================================================
				let step = 0;
				const workgroupCount = Math.ceil(gridSize / 8);

				function frame(time: number) {
					if (destroyed) return;

					// FPS calculation
					frameCount++;
					if (time - lastFpsUpdate >= 1000) {
						fps = frameCount;
						frameCount = 0;
						lastFpsUpdate = time;
					}

					// Run simulation at tick rate
					if (!paused && time - lastTick >= tickRate) {
						// TypeGPU pipeline execution - much cleaner!
						computePipeline
							.with(computeLayout, computeBindGroups[step % 2])
							.dispatchWorkgroups(workgroupCount, workgroupCount);

						step++;
						generation = step;
						lastTick = time;
					}

					// Render (always, even when paused)
					renderPipeline
						.with(renderLayout, renderBindGroups[step % 2])
						.withColorAttachment({
							view: context.getCurrentTexture().createView(),
							loadOp: "clear",
							storeOp: "store",
							clearValue: { r: 0.1, g: 0.1, b: 0.1, a: 1 },
						})
						.draw(6, cellCount);

					animationFrame = requestAnimationFrame(frame);
				}

				loading = false;
				animationFrame = requestAnimationFrame(frame);

			} catch (err) {
				console.error("TypeGPU init error:", err);
				error = err instanceof Error ? err.message : "Failed to initialize";
				loading = false;
			}
		}

		function handleResize() {
			if (!canvas) return;
			const dpr = window.devicePixelRatio || 1;
			canvas.width = Math.floor(canvas.clientWidth * dpr);
			canvas.height = Math.floor(canvas.clientHeight * dpr);
		}

		init();
		window.addEventListener("resize", handleResize);

		return () => {
			destroyed = true;
			cancelAnimationFrame(animationFrame);
			window.removeEventListener("resize", handleResize);
			root?.destroy();
		};
	});

	function togglePause() {
		paused = !paused;
	}
</script>

<div class="game-of-life {className}">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Initializing TypeGPU...</p>
		</div>
	{/if}

	{#if !supported}
		<div class="fallback">
			<div class="fallback-icon">
				<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
				</svg>
			</div>
			<h3>WebGPU Not Available</h3>
			<p>{error}</p>
		</div>
	{/if}

	<canvas bind:this={canvas} class="canvas" class:hidden={!supported || loading}></canvas>

	{#if supported && !loading}
		<div class="controls">
			<span class="badge">TypeGPU</span>
			<button onclick={togglePause} class="control-btn">
				{paused ? "Play" : "Pause"}
			</button>
			<span class="stat">Gen {generation}</span>
			<span class="stat">{fps} FPS</span>
		</div>
	{/if}
</div>

<style>
	.game-of-life {
		position: relative;
		width: 100%;
		height: 100%;
		min-height: 400px;
		background: oklch(0.1 0.01 106);
		border-radius: 0.5rem;
		overflow: hidden;
	}

	.canvas {
		width: 100%;
		height: 100%;
		display: block;
	}

	.canvas.hidden {
		visibility: hidden;
		position: absolute;
	}

	.loading,
	.fallback {
		position: absolute;
		inset: 0;
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
		to { transform: rotate(360deg); }
	}

	.fallback {
		text-align: center;
		padding: 2rem;
	}

	.fallback-icon {
		color: var(--accent);
		opacity: 0.8;
	}

	.fallback h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 500;
		color: var(--foreground);
	}

	.fallback p {
		margin: 0;
		max-width: 400px;
	}

	.controls {
		position: absolute;
		bottom: 1rem;
		left: 1rem;
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 0.5rem 0.75rem;
		background: oklch(0.15 0.01 106 / 0.9);
		border-radius: 0.375rem;
		backdrop-filter: blur(4px);
	}

	.badge {
		font-size: 0.625rem;
		font-family: monospace;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		padding: 0.25rem 0.5rem;
		background: oklch(0.5 0.15 280);
		color: white;
		border-radius: 0.25rem;
	}

	.control-btn {
		padding: 0.375rem 0.75rem;
		font-size: 0.875rem;
		font-family: inherit;
		color: var(--foreground);
		background: var(--border);
		border: none;
		border-radius: 0.25rem;
		cursor: pointer;
		transition: background 0.15s;
	}

	.control-btn:hover {
		background: var(--accent);
	}

	.stat {
		font-size: 0.75rem;
		font-family: monospace;
		color: var(--muted-foreground);
	}
</style>
