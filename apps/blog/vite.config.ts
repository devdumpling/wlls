import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";
import devtoolsJson from "vite-plugin-devtools-json";
import typegpu from "unplugin-typegpu/vite";

export default defineConfig({
	plugins: [sveltekit(), typegpu(), devtoolsJson()],
	server: {
		fs: {
			// Allow serving files from the workspace root (for Deno's node_modules)
			allow: ["../.."],
		},
	},
	build: {
		// Three.js is ~700KB minified - this is expected for 3D graphics libraries
		// We lazy load it on the /lab page to avoid impacting main bundle
		chunkSizeWarningLimit: 800,
		rollupOptions: {
			output: {
				manualChunks: (id) => {
					// Split heavy libraries into separate chunks for lazy loading
					if (id.includes("three")) {
						return "three";
					}
					if (id.includes("@threlte")) {
						return "threlte";
					}
					if (id.includes("typegpu")) {
						return "typegpu";
					}
					// Don't manually chunk shiki - let Vite handle it
					// Manual chunking was causing the preload helper to bundle with shiki,
					// which made the 9MB chunk load on every page
				},
			},
		},
	},
});
