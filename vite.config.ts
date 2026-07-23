import { fresh } from "@fresh/plugin-vite";
import { defineConfig, type Plugin } from "vite";

function markdownFiles(): Plugin {
  return {
    name: "wlls:markdown-files",
    enforce: "pre",
    load(id) {
      const path = id.split("?", 1)[0];
      if (!path.endsWith(".md")) return null;

      this.addWatchFile(path);
      return `export default ${JSON.stringify(Deno.readTextFileSync(path))};`;
    },
  };
}

export default defineConfig({
  plugins: [markdownFiles(), fresh()],
});
