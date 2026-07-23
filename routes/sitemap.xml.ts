import { getPosts } from "@/lib/content.ts";
import { createSitemap } from "@/lib/xml.ts";
import { define } from "@/utils.ts";

export const handler = define.handlers({
  GET() {
    return new Response(createSitemap(getPosts()), {
      headers: { "Content-Type": "application/xml; charset=utf-8" },
    });
  },
});
