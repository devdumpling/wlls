import { getPosts } from "@/lib/content.ts";
import { createRss } from "@/lib/xml.ts";
import { define } from "@/utils.ts";

export const handler = define.handlers({
  GET() {
    return new Response(createRss(getPosts()), {
      headers: { "Content-Type": "application/rss+xml; charset=utf-8" },
    });
  },
});
