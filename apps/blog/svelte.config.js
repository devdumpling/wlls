import { join } from "node:path";
import { fileURLToPath } from "node:url";
import adapter from "@sveltejs/adapter-cloudflare";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";
import { mdsvex, escapeSvelte } from "mdsvex";
import rehypeSlug from "rehype-slug";
import { createHighlighter } from "shiki";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

// Create Shiki highlighter with common languages
const highlighter = await createHighlighter({
	themes: ["kanagawa-wave", "kanagawa-lotus"],
	langs: [
		"javascript",
		"typescript",
		"tsx",
		"jsx",
		"json",
		"css",
		"html",
		"svelte",
		"bash",
		"shell",
		"markdown",
		"yaml",
		"toml",
	],
});

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
			highlight: {
				highlighter: async (code, lang = "text") => {
					const html = escapeSvelte(
						highlighter.codeToHtml(code, {
							lang,
							themes: {
								light: "kanagawa-lotus",
								dark: "kanagawa-wave",
							},
						})
					);
					return `{@html \`${html}\`}`;
				},
			},
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
