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
 * Initialize a TypeGPU root with default settings
 * Returns null if WebGPU is not supported
 */
export async function initGPU(): Promise<TgpuRoot | null> {
	if (!isWebGPUSupported()) {
		return null;
	}

	try {
		const root = await tgpu.init();
		return root;
	} catch (error) {
		console.error("Failed to initialize WebGPU:", error);
		return null;
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
