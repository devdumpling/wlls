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
 * Shared GPU root singleton with reference counting.
 * Prevents multiple GPU contexts from exhausting the adapter.
 */
let sharedRoot: TgpuRoot | null = null;
let sharedRootRefCount = 0;
let sharedRootPromise: Promise<TgpuRoot | null> | null = null;

/**
 * Acquire a shared TypeGPU root. Multiple components share the same root.
 * Call releaseGPU() when done to decrement the reference count.
 */
export async function acquireGPU(): Promise<TgpuRoot | null> {
	if (!isWebGPUSupported()) {
		return null;
	}

	// If already initialized, increment ref count and return
	if (sharedRoot) {
		sharedRootRefCount++;
		return sharedRoot;
	}

	// If initialization is in progress, wait for it
	if (sharedRootPromise) {
		const root = await sharedRootPromise;
		if (root) sharedRootRefCount++;
		return root;
	}

	// Start initialization
	sharedRootPromise = (async () => {
		try {
			const root = await tgpu.init();
			sharedRoot = root;
			sharedRootRefCount = 1;
			return root;
		} catch (error) {
			console.error("Failed to initialize WebGPU:", error);
			return null;
		} finally {
			sharedRootPromise = null;
		}
	})();

	return sharedRootPromise;
}

/**
 * Release a reference to the shared GPU root.
 * When ref count hits 0, the root is destroyed.
 */
export function releaseGPU(): void {
	if (sharedRootRefCount > 0) {
		sharedRootRefCount--;
	}

	if (sharedRootRefCount === 0 && sharedRoot) {
		sharedRoot.destroy();
		sharedRoot = null;
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
