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
		// We lazy load it via dynamic imports to avoid impacting main bundle
		chunkSizeWarningLimit: 800,
		// Don't use manualChunks for three/threlte/shiki - it causes shared Svelte
		// utilities to be bundled with those libraries, forcing every page to load them.
		// Dynamic imports already ensure proper code splitting.
	},
});
