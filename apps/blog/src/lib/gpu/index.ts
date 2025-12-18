// TypeGPU utilities and primitives
// Explicit exports for tree shaking (no wildcards)
export {
	isWebGPUSupported,
	getWebGPUUnsupportedReason,
	acquireGPU,
	releaseGPU,
	destroyGPU,
	initGPUFromDevice,
	getOrCreateRoot,
	getPreferredFormat,
	configureCanvas,
	resizeCanvasToDisplaySize,
	getCurrentTexture,
	type CanvasConfig,
	type ConfiguredCanvas,
} from "./core";
