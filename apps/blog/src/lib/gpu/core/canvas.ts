import type { TgpuRoot } from "typegpu";
import { getPreferredFormat } from "./device";

export interface CanvasConfig {
	canvas: HTMLCanvasElement;
	root: TgpuRoot;
	alphaMode?: GPUCanvasAlphaMode;
}

export interface ConfiguredCanvas {
	context: GPUCanvasContext;
	format: GPUTextureFormat;
	canvas: HTMLCanvasElement;
}

/**
 * Configure a canvas for WebGPU rendering
 */
export function configureCanvas({
	canvas,
	root,
	alphaMode = "premultiplied",
}: CanvasConfig): ConfiguredCanvas {
	const context = canvas.getContext("webgpu");
	if (!context) {
		throw new Error("Failed to get WebGPU context from canvas");
	}

	const format = getPreferredFormat();

	context.configure({
		device: root.device,
		format,
		alphaMode,
	});

	return { context, format, canvas };
}

/**
 * Handle canvas resize to match display size
 * Returns true if the canvas was resized
 */
export function resizeCanvasToDisplaySize(canvas: HTMLCanvasElement): boolean {
	const dpr = window.devicePixelRatio || 1;
	const displayWidth = Math.floor(canvas.clientWidth * dpr);
	const displayHeight = Math.floor(canvas.clientHeight * dpr);

	if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
		canvas.width = displayWidth;
		canvas.height = displayHeight;
		return true;
	}

	return false;
}

/**
 * Get the current texture from a canvas context for rendering
 */
export function getCurrentTexture(context: GPUCanvasContext): GPUTexture {
	return context.getCurrentTexture();
}
