import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";
import devtoolsJson from "vite-plugin-devtools-json";

export default defineConfig({
	plugins: [sveltekit(), devtoolsJson()],
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
					// Split Three.js and related packages into separate chunks
					if (id.includes('three')) {
						return 'three';
					}
					if (id.includes('@threlte')) {
						return 'threlte';
					}
					// Split node_modules into vendor chunk
					if (id.includes('node_modules')) {
						return 'vendor';
					}
				},
			},
		},
	},
});
