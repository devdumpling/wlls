// Core GPU utilities
export {
	isWebGPUSupported,
	getWebGPUUnsupportedReason,
	initGPU,
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
