import { App, staticFiles } from "fresh";
import type { State } from "./utils.ts";

export const app = new App<State>();

app.use(async (ctx) => {
  const response = await ctx.next();
  const contentType = response.headers.get("content-type") ?? "";
  const isCacheableDocument = contentType.startsWith("text/html") ||
    contentType.startsWith("application/xml") ||
    contentType.startsWith("application/rss+xml");

  if (
    (ctx.req.method === "GET" || ctx.req.method === "HEAD") &&
    ctx.url.pathname.startsWith("/fonts/")
  ) {
    response.headers.set("Cache-Control", "public, max-age=31536000, immutable");
  } else if (
    (ctx.req.method === "GET" || ctx.req.method === "HEAD") &&
    isCacheableDocument
  ) {
    response.headers.set(
      "Cache-Control",
      "public, max-age=0, s-maxage=86400, stale-while-revalidate=604800",
    );
  }

  return response;
});

app.use(staticFiles());
app.fsRoutes();
