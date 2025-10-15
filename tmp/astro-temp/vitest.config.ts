import { getViteConfig } from "astro/config";
import { defineConfig } from "vitest/config";

export default defineConfig(
	getViteConfig(
		defineConfig({
			test: {
				globals: true,
				environment: "happy-dom",
				coverage: {
					provider: "v8",
					reporter: ["text", "json", "html"],
					exclude: [
						"node_modules/",
						"dist/",
						".astro/",
						"*.config.*",
						"**/*.d.ts",
						"**/*.spec.ts",
						"**/*.test.ts",
					],
				},
				include: ["src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}"],
				setupFiles: ["./src/test/setup.ts"],
			},
		}),
	),
);
