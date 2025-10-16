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
});
