import { sveltekit } from "@sveltejs/kit/vite";
import typegpu from "unplugin-typegpu/vite";
import { defineConfig } from "vite";
import devtoolsJson from "vite-plugin-devtools-json";

export default defineConfig({
	plugins: [sveltekit(), typegpu(), devtoolsJson()],
	server: {
		fs: {
			// Allow serving files from the workspace root (for Deno's node_modules)
			allow: ["../.."],
		},
	},
	build: {
		// Large libraries (Three.js, shiki) are lazy-loaded via dynamic imports
		chunkSizeWarningLimit: 800,
	},
});
