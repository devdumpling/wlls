import { parsePost } from "../src/markdown.ts";
import { createRss, createSitemap } from "../src/xml.ts";

const post = parsePost(
  `---
title: "A & B"
description: "Less < more"
date: "2026-07-22"
topic: Engineering
---
Body
`,
  "a-and-b",
);

Deno.test("createRss escapes content and includes canonical URLs", () => {
  const rss = createRss([post]);
  assert(rss.includes("<title>A &amp; B</title>"));
  assert(rss.includes("https://wlls.dev/blog/a-and-b"));
  assert(rss.includes("<pubDate>Wed, 22 Jul 2026 00:00:00 GMT</pubDate>"));
});

Deno.test("createSitemap includes pages and post dates", () => {
  const sitemap = createSitemap([post]);
  assert(sitemap.includes("<loc>https://wlls.dev/</loc>"));
  assert(sitemap.includes("<loc>https://wlls.dev/about</loc>"));
  assert(!sitemap.includes("<loc>https://wlls.dev/blog</loc>"));
  assert(sitemap.includes("<lastmod>2026-07-22</lastmod>"));
});

function assert(condition: unknown): asserts condition {
  if (!condition) throw new Error("Assertion failed");
}
