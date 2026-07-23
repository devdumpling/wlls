import { App, staticFiles } from "fresh";
import type { State } from "./utils.ts";

export const app = new App<State>();

app.use(async (ctx) => {
  const response = await ctx.next();
  const contentType = response.headers.get("content-type") ?? "";

  if (ctx.req.method === "GET" && ctx.url.pathname.startsWith("/fonts/")) {
    response.headers.set("Cache-Control", "public, max-age=31536000, immutable");
  } else if (
    ctx.req.method === "GET" &&
    (contentType.includes("text/html") || contentType.includes("xml"))
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
