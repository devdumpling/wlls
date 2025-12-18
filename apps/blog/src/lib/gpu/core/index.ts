// Core GPU utilities
export {
	isWebGPUSupported,
	getWebGPUUnsupportedReason,
	acquireGPU,
	releaseGPU,
	destroyGPU,
	initGPUFromDevice,
	getOrCreateRoot,
	getPreferredFormat,
} from "./device";

export {
	configureCanvas,
	resizeCanvasToDisplaySize,
	getCurrentTexture,
	type CanvasConfig,
	type ConfiguredCanvas,
} from "./canvas";
