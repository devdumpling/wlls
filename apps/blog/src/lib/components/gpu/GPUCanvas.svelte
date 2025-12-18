<script lang="ts">
	import { onMount, setContext } from "svelte";
	import type { TgpuRoot } from "typegpu";
	import {
		isWebGPUSupported,
		getWebGPUUnsupportedReason,
		acquireGPU,
		releaseGPU,
		configureCanvas,
		resizeCanvasToDisplaySize,
		type ConfiguredCanvas,
	} from "$lib/gpu";

	interface Props {
		onReady?: (ctx: GPUContext) => void;
		onFrame?: (ctx: GPUContext, time: number) => void;
		onResize?: (ctx: GPUContext) => void;
		onDestroy?: () => void;
		class?: string;
	}

	export interface GPUContext {
		root: TgpuRoot;
		canvas: ConfiguredCanvas;
		width: number;
		height: number;
	}

	let {
		onReady,
		onFrame,
		onResize,
		onDestroy,
		class: className = "",
	}: Props = $props();

	let canvas: HTMLCanvasElement;
	let supported = $state(true);
	let error = $state<string | null>(null);
	let loading = $state(true);

	// Set context for child components
	let gpuContext = $state<GPUContext | null>(null);
	setContext("gpu", {
		get context() {
			return gpuContext;
		},
	});

	onMount(() => {
		let root: TgpuRoot | null = null;
		let animationFrame: number;
		let destroyed = false;

		async function init() {
			// Check support
			if (!isWebGPUSupported()) {
				supported = false;
				error = getWebGPUUnsupportedReason();
				loading = false;
				return;
			}

			// Initialize GPU
			const newRoot = await acquireGPU();
			if (!newRoot) {
				supported = false;
				error = "Failed to initialize WebGPU device";
				loading = false;
				return;
			}

			// Check if component was destroyed during async init
			if (destroyed) {
				releaseGPU();
				return;
			}

			root = newRoot;

			// Configure canvas
			try {
				resizeCanvasToDisplaySize(canvas);
				const configuredCanvas = configureCanvas({ canvas, root });

				gpuContext = {
					root,
					canvas: configuredCanvas,
					width: canvas.width,
					height: canvas.height,
				};

				loading = false;

				// Notify ready
				onReady?.(gpuContext);

				// Start render loop if onFrame provided
				if (onFrame) {
					function loop(time: number) {
						if (destroyed || !gpuContext) return;

						// Check for resize
						if (resizeCanvasToDisplaySize(canvas)) {
							gpuContext.width = canvas.width;
							gpuContext.height = canvas.height;
							onResize?.(gpuContext);
						}

						onFrame?.(gpuContext, time);
						animationFrame = requestAnimationFrame(loop);
					}
					animationFrame = requestAnimationFrame(loop);
				}
			} catch (err) {
				error = err instanceof Error ? err.message : "Failed to configure canvas";
				loading = false;
			}
		}

		// Handle window resize
		function handleResize() {
			if (!gpuContext) return;
			if (resizeCanvasToDisplaySize(canvas)) {
				gpuContext.width = canvas.width;
				gpuContext.height = canvas.height;
				onResize?.(gpuContext);
			}
		}

		init();
		window.addEventListener("resize", handleResize);

		return () => {
			destroyed = true;
			cancelAnimationFrame(animationFrame);
			window.removeEventListener("resize", handleResize);
			onDestroy?.();
			if (root) {
				releaseGPU();
			}
		};
	});
</script>

<div class="gpu-canvas-container {className}">
	{#if loading}
		<div class="gpu-loading">
			<div class="spinner"></div>
			<p>Initializing WebGPU...</p>
		</div>
	{/if}

	{#if !supported}
		<div class="gpu-fallback">
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
			<div class="browser-support">
				<p>Supported browsers:</p>
				<ul>
					<li>Chrome 113+</li>
					<li>Edge 113+</li>
					<li>Safari 18+ (macOS/iOS)</li>
					<li>Firefox (behind flag)</li>
				</ul>
			</div>
		</div>
	{/if}

	<canvas
		bind:this={canvas}
		class="gpu-canvas"
		class:hidden={!supported || loading}
	></canvas>
</div>

<style>
	.gpu-canvas-container {
		position: relative;
		width: 100%;
		height: 100%;
		min-height: 200px;
	}

	.gpu-canvas {
		width: 100%;
		height: 100%;
		display: block;
	}

	.gpu-canvas.hidden {
		visibility: hidden;
		position: absolute;
	}

	.gpu-loading,
	.gpu-fallback {
		position: absolute;
		inset: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		background: var(--background);
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

	.gpu-fallback {
		text-align: center;
		padding: 2rem;
	}

	.fallback-icon {
		color: var(--accent);
		opacity: 0.8;
	}

	.gpu-fallback h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 500;
		color: var(--foreground);
	}

	.gpu-fallback p {
		margin: 0;
		max-width: 400px;
		line-height: 1.5;
	}

	.browser-support {
		margin-top: 1rem;
		padding: 1rem;
		background: var(--border);
		border-radius: 0.5rem;
		font-size: 0.875rem;
	}

	.browser-support p {
		margin: 0 0 0.5rem 0;
		font-weight: 500;
	}

	.browser-support ul {
		margin: 0;
		padding: 0;
		list-style: none;
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem 1rem;
		justify-content: center;
	}

	.browser-support li {
		font-family: monospace;
	}
</style>
