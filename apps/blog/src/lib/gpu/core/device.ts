import tgpu, { type TgpuRoot } from "typegpu";

/**
 * Check if WebGPU is supported in the current browser
 */
export function isWebGPUSupported(): boolean {
	return typeof navigator !== "undefined" && "gpu" in navigator;
}

/**
 * Get a human-readable reason why WebGPU is not supported
 */
export function getWebGPUUnsupportedReason(): string {
	if (typeof navigator === "undefined") {
		return "WebGPU is not available in this environment (server-side rendering)";
	}
	if (!("gpu" in navigator)) {
		return "Your browser does not support WebGPU. Try Chrome 113+, Edge 113+, or Safari 18+.";
	}
	return "WebGPU is not available for an unknown reason";
}

/**
 * GPU state stored on window to survive HMR.
 * Without this, module-level variables reset on HMR but the GPU device
 * remains held by the browser, causing adapter exhaustion.
 */
interface GPUState {
	root: TgpuRoot | null;
	refCount: number;
	promise: Promise<TgpuRoot | null> | null;
	/** Track if device was lost (e.g., GPU hang, driver crash) */
	deviceLost: boolean;
}

declare global {
	interface Window {
		__TYPEGPU_STATE__?: GPUState;
	}
}

function getGPUState(): GPUState {
	if (typeof window === "undefined") {
		// SSR - return a dummy state that will never be used
		return { root: null, refCount: 0, promise: null, deviceLost: false };
	}
	if (!window.__TYPEGPU_STATE__) {
		window.__TYPEGPU_STATE__ = {
			root: null,
			refCount: 0,
			promise: null,
			deviceLost: false,
		};
	}
	return window.__TYPEGPU_STATE__;
}

/**
 * Clean up GPU resources. Called before HMR or when explicitly needed.
 */
export function destroyGPU(): void {
	const state = getGPUState();
	if (state.root) {
		try {
			state.root.destroy();
		} catch {
			// Device may already be lost/destroyed
		}
		state.root = null;
	}
	state.refCount = 0;
	state.promise = null;
	state.deviceLost = false;
}

// Preserve GPU device across HMR updates
if (import.meta.hot) {
	import.meta.hot.dispose(() => {});
	import.meta.hot.accept();
}

/**
 * Acquire a shared TypeGPU root. Multiple components share the same root.
 * Call releaseGPU() when done to decrement the reference count.
 */
export async function acquireGPU(): Promise<TgpuRoot | null> {
	if (!isWebGPUSupported()) {
		return null;
	}

	const state = getGPUState();

	// If device was lost, clean up and try again
	if (state.deviceLost && state.root) {
		destroyGPU();
	}

	// If already initialized, increment ref count and return
	if (state.root) {
		state.refCount++;
		return state.root;
	}

	// If initialization is in progress, wait for it
	if (state.promise) {
		const root = await state.promise;
		if (root) state.refCount++;
		return root;
	}

	// Start initialization
	state.promise = (async () => {
		try {
			const root = await tgpu.init();

			// Listen for device loss
			root.device.lost.then((info) => {
				console.warn("[TypeGPU] Device lost:", info.message);
				state.deviceLost = true;
			});

			state.root = root;
			state.refCount = 1;
			return root;
		} catch (error) {
			console.error("Failed to initialize WebGPU:", error);
			return null;
		} finally {
			state.promise = null;
		}
	})();

	return state.promise;
}

/**
 * Release a reference to the shared GPU root.
 * When ref count hits 0, the root is destroyed to free the adapter.
 */
export function releaseGPU(): void {
	const state = getGPUState();

	if (state.refCount > 0) {
		state.refCount--;
	}

	// Only destroy when no components are using it
	if (state.refCount === 0 && state.root) {
		// In development, delay cleanup to allow HMR to reconnect
		if (import.meta.hot) {
			setTimeout(() => {
				const currentState = getGPUState();
				if (currentState.refCount === 0 && currentState.root) {
					destroyGPU();
				}
			}, 100);
		} else {
			destroyGPU();
		}
	}
}

/**
 * Initialize a TypeGPU root from an existing device
 */
export function initGPUFromDevice(device: GPUDevice): TgpuRoot {
	return tgpu.initFromDevice({ device });
}

/**
 * Cache for reusing roots across components
 */
const deviceToRootMap = new WeakMap<GPUDevice, TgpuRoot>();

/**
 * Get or create a TypeGPU root for a device
 * Useful when device is passed around
 */
export function getOrCreateRoot(device: GPUDevice): TgpuRoot {
	let root = deviceToRootMap.get(device);
	if (!root) {
		root = tgpu.initFromDevice({ device });
		deviceToRootMap.set(device, root);
	}
	return root;
}

/**
 * Get the preferred canvas format for the current platform
 */
export function getPreferredFormat(): GPUTextureFormat {
	if (!isWebGPUSupported()) {
		return "bgra8unorm";
	}
	return navigator.gpu.getPreferredCanvasFormat();
}
