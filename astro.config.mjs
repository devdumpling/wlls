// @ts-check

import mdx from "@astrojs/mdx";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "astro/config";

// https://astro.build/config
export default defineConfig({
	site: "https://wlls.dev",
	
	vite: {
		plugins: [tailwindcss()],
	},

	integrations: [mdx()],

	markdown: {
		shikiConfig: {
			theme: "everforest-dark",
		},
	},
});
