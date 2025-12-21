// TypeGPU utilities and primitives
// Explicit exports for tree shaking (no wildcards)
export {
	acquireGPU,
	type CanvasConfig,
	type ConfiguredCanvas,
	configureCanvas,
	destroyGPU,
	getCurrentTexture,
	getOrCreateRoot,
	getPreferredFormat,
	getWebGPUUnsupportedReason,
	initGPUFromDevice,
	isWebGPUSupported,
	releaseGPU,
	resizeCanvasToDisplaySize,
} from "./core";
