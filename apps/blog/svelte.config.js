import { join } from "node:path";
import { fileURLToPath } from "node:url";
import adapter from "@sveltejs/adapter-cloudflare";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";
import { mdsvex } from "mdsvex";
import rehypeSlug from "rehype-slug";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

/** @type {import('@sveltejs/kit').Config} */
const config = {
	// Consult https://svelte.dev/docs/kit/integrations
	// for more information about preprocessors
	preprocess: [
		vitePreprocess(),
		mdsvex({
			layout: {
				_: join(__dirname, "src", "lib", "components", "MdsvexLayout.svelte"),
			},
			rehypePlugins: [
				rehypeSlug, // Auto-generate IDs for headings
			],
		}),
	],
	compilerOptions: {
		experimental: {
			async: true,
		},
	},
	kit: {
		adapter: adapter(),
	},
	extensions: [".svelte", ".svx"],
};

export default config;
