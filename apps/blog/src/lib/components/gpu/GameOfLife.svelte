<script lang="ts">
	import { onMount } from "svelte";
	import tgpu, { type TgpuRoot } from "typegpu";
	import {
		isWebGPUSupported,
		getWebGPUUnsupportedReason,
		initGPU,
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

		// FPS tracking
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
				root = await initGPU();
				if (!root) {
					throw new Error("Failed to initialize GPU");
				}

				const device = root.device;

				// Configure canvas
				const context = canvas.getContext("webgpu");
				if (!context) throw new Error("Failed to get WebGPU context");

				const format = getPreferredFormat();
				context.configure({ device, format, alphaMode: "premultiplied" });

				// Resize canvas
				const dpr = window.devicePixelRatio || 1;
				canvas.width = Math.floor(canvas.clientWidth * dpr);
				canvas.height = Math.floor(canvas.clientHeight * dpr);

				// Create cell state buffers (ping-pong)
				const cellCount = gridSize * gridSize;
				const initialState = new Uint32Array(cellCount);

				// Random initial state with ~15% alive
				for (let i = 0; i < cellCount; i++) {
					initialState[i] = Math.random() < 0.15 ? 1 : 0;
				}

				const cellStateA = device.createBuffer({
					label: "Cell State A",
					size: cellCount * 4,
					usage:
						GPUBufferUsage.STORAGE |
						GPUBufferUsage.COPY_DST |
						GPUBufferUsage.COPY_SRC,
				});
				device.queue.writeBuffer(cellStateA, 0, initialState);

				const cellStateB = device.createBuffer({
					label: "Cell State B",
					size: cellCount * 4,
					usage:
						GPUBufferUsage.STORAGE |
						GPUBufferUsage.COPY_DST |
						GPUBufferUsage.COPY_SRC,
				});

				// Uniform buffer for grid size
				const uniformBuffer = device.createBuffer({
					label: "Grid Uniforms",
					size: 8, // 2x u32
					usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
				});
				device.queue.writeBuffer(
					uniformBuffer,
					0,
					new Uint32Array([gridSize, gridSize]),
				);

				// Compute shader for simulation
				const computeShaderCode = /* wgsl */ `
					struct Uniforms {
						width: u32,
						height: u32,
					}

					@group(0) @binding(0) var<uniform> uniforms: Uniforms;
					@group(0) @binding(1) var<storage, read> cellStateIn: array<u32>;
					@group(0) @binding(2) var<storage, read_write> cellStateOut: array<u32>;

					fn getIndex(x: u32, y: u32) -> u32 {
						return (y % uniforms.height) * uniforms.width + (x % uniforms.width);
					}

					fn getCell(x: u32, y: u32) -> u32 {
						return cellStateIn[getIndex(x, y)];
					}

					@compute @workgroup_size(8, 8)
					fn main(@builtin(global_invocation_id) cell: vec3u) {
						if (cell.x >= uniforms.width || cell.y >= uniforms.height) {
							return;
						}

						let x = cell.x;
						let y = cell.y;

						// Count living neighbors (with wrapping)
						var neighbors: u32 = 0;
						neighbors += getCell(x - 1, y - 1);
						neighbors += getCell(x, y - 1);
						neighbors += getCell(x + 1, y - 1);
						neighbors += getCell(x - 1, y);
						neighbors += getCell(x + 1, y);
						neighbors += getCell(x - 1, y + 1);
						neighbors += getCell(x, y + 1);
						neighbors += getCell(x + 1, y + 1);

						let idx = getIndex(x, y);
						let alive = cellStateIn[idx];

						// Conway's rules
						if (alive == 1 && (neighbors == 2 || neighbors == 3)) {
							cellStateOut[idx] = 1;
						} else if (alive == 0 && neighbors == 3) {
							cellStateOut[idx] = 1;
						} else {
							cellStateOut[idx] = 0;
						}
					}
				`;

				// Render shader for visualization
				const renderShaderCode = /* wgsl */ `
					struct Uniforms {
						width: u32,
						height: u32,
					}

					struct VertexOutput {
						@builtin(position) position: vec4f,
						@location(0) cell: vec2f,
					}

					@group(0) @binding(0) var<uniform> uniforms: Uniforms;
					@group(0) @binding(1) var<storage, read> cellState: array<u32>;

					@vertex
					fn vertexMain(@builtin(vertex_index) vertexIndex: u32,
								  @builtin(instance_index) instance: u32) -> VertexOutput {
						let i = f32(instance);
						let cell = vec2f(i % f32(uniforms.width), floor(i / f32(uniforms.width)));

						// Quad vertices (2 triangles)
						let pos = array<vec2f, 6>(
							vec2f(0, 0), vec2f(1, 0), vec2f(0, 1),
							vec2f(0, 1), vec2f(1, 0), vec2f(1, 1)
						);

						let cellOffset = cell / vec2f(f32(uniforms.width), f32(uniforms.height)) * 2 - 1;
						let cellSize = 2.0 / vec2f(f32(uniforms.width), f32(uniforms.height));

						var output: VertexOutput;
						output.position = vec4f(cellOffset + pos[vertexIndex] * cellSize, 0, 1);
						output.position.y = -output.position.y; // Flip Y
						output.cell = cell;
						return output;
					}

					@fragment
					fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
						let idx = u32(input.cell.y) * uniforms.width + u32(input.cell.x);
						let alive = cellState[idx];

						if (alive == 1) {
							return vec4f(0.9, 0.55, 0.2, 1.0); // Accent color
						} else {
							return vec4f(0.1, 0.1, 0.1, 1.0); // Dark
						}
					}
				`;

				// Create compute pipeline
				const computeShaderModule = device.createShaderModule({
					label: "Game of Life Compute",
					code: computeShaderCode,
				});

				const computeBindGroupLayout = device.createBindGroupLayout({
					entries: [
						{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
						{ binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" } },
						{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
					],
				});

				const computePipeline = device.createComputePipeline({
					label: "Game of Life Compute Pipeline",
					layout: device.createPipelineLayout({
						bindGroupLayouts: [computeBindGroupLayout],
					}),
					compute: {
						module: computeShaderModule,
						entryPoint: "main",
					},
				});

				// Create render pipeline
				const renderShaderModule = device.createShaderModule({
					label: "Game of Life Render",
					code: renderShaderCode,
				});

				const renderBindGroupLayout = device.createBindGroupLayout({
					entries: [
						{ binding: 0, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
						{ binding: 1, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } },
					],
				});

				const renderPipeline = device.createRenderPipeline({
					label: "Game of Life Render Pipeline",
					layout: device.createPipelineLayout({
						bindGroupLayouts: [renderBindGroupLayout],
					}),
					vertex: {
						module: renderShaderModule,
						entryPoint: "vertexMain",
					},
					fragment: {
						module: renderShaderModule,
						entryPoint: "fragmentMain",
						targets: [{ format }],
					},
				});

				// Create bind groups for ping-pong
				const computeBindGroups = [
					device.createBindGroup({
						layout: computeBindGroupLayout,
						entries: [
							{ binding: 0, resource: { buffer: uniformBuffer } },
							{ binding: 1, resource: { buffer: cellStateA } },
							{ binding: 2, resource: { buffer: cellStateB } },
						],
					}),
					device.createBindGroup({
						layout: computeBindGroupLayout,
						entries: [
							{ binding: 0, resource: { buffer: uniformBuffer } },
							{ binding: 1, resource: { buffer: cellStateB } },
							{ binding: 2, resource: { buffer: cellStateA } },
						],
					}),
				];

				const renderBindGroups = [
					device.createBindGroup({
						layout: renderBindGroupLayout,
						entries: [
							{ binding: 0, resource: { buffer: uniformBuffer } },
							{ binding: 1, resource: { buffer: cellStateA } },
						],
					}),
					device.createBindGroup({
						layout: renderBindGroupLayout,
						entries: [
							{ binding: 0, resource: { buffer: uniformBuffer } },
							{ binding: 1, resource: { buffer: cellStateB } },
						],
					}),
				];

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

					// Update simulation at tick rate
					if (!paused && time - lastTick >= tickRate) {
						const encoder = device.createCommandEncoder();

						// Compute pass
						const computePass = encoder.beginComputePass();
						computePass.setPipeline(computePipeline);
						computePass.setBindGroup(0, computeBindGroups[step % 2]);
						computePass.dispatchWorkgroups(workgroupCount, workgroupCount);
						computePass.end();

						device.queue.submit([encoder.finish()]);

						step++;
						generation = step;
						lastTick = time;
					}

					// Render pass (always render, even when paused)
					const encoder = device.createCommandEncoder();
					const renderPass = encoder.beginRenderPass({
						colorAttachments: [
							{
								view: context.getCurrentTexture().createView(),
								loadOp: "clear",
								storeOp: "store",
								clearValue: { r: 0.1, g: 0.1, b: 0.1, a: 1 },
							},
						],
					});

					renderPass.setPipeline(renderPipeline);
					renderPass.setBindGroup(0, renderBindGroups[step % 2]);
					renderPass.draw(6, cellCount);
					renderPass.end();

					device.queue.submit([encoder.finish()]);

					animationFrame = requestAnimationFrame(frame);
				}

				loading = false;
				animationFrame = requestAnimationFrame(frame);

			} catch (err) {
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
			<p>Initializing GPU...</p>
		</div>
	{/if}

	{#if !supported}
		<div class="fallback">
			<div class="fallback-icon">
				<svg
					width="48"
					height="48"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="1.5"
				>
					<path
						d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
					/>
				</svg>
			</div>
			<h3>WebGPU Not Available</h3>
			<p>{error}</p>
		</div>
	{/if}

	<canvas
		bind:this={canvas}
		class="canvas"
		class:hidden={!supported || loading}
	></canvas>

	{#if supported && !loading}
		<div class="controls">
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
		to {
			transform: rotate(360deg);
		}
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
