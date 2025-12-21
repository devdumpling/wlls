// Core GPU utilities

export {
	type CanvasConfig,
	type ConfiguredCanvas,
	configureCanvas,
	getCurrentTexture,
	resizeCanvasToDisplaySize,
} from "./canvas";
export {
	acquireGPU,
	destroyGPU,
	getOrCreateRoot,
	getPreferredFormat,
	getWebGPUUnsupportedReason,
	initGPUFromDevice,
	isWebGPUSupported,
	releaseGPU,
} from "./device";
