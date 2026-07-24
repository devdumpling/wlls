import { resolvePath } from "../scripts/server.ts";

Deno.test("resolvePath confines requests to generated output", () => {
  const cases = [
    ["/", "index.html"],
    ["/about", "about.html"],
    ["/assets/site.css", "assets/site.css"],
    ["/%2FUsers%2Fexample%2Fsecret.txt", null],
    ["/%252e%252e/secret.txt", null],
    ["/%E0%A4%A", null],
    ["/..\\secret.txt", null],
  ] as const;

  for (const [path, expected] of cases) {
    const actual = resolvePath(path);
    if (actual !== expected) throw new Error(`${path}: expected ${expected}, got ${actual}`);
  }
});
