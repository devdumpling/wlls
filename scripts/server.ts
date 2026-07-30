const buildDirectory = new URL("../build/", import.meta.url);
const watchPaths = ["posts", "content", "src", "static"].map((path) =>
  new URL(`../${path}/`, import.meta.url).pathname
);
const reloadClients = new Set<ReadableStreamDefaultController<Uint8Array>>();
const encoder = new TextEncoder();

export async function serveSite(options: { liveReload?: boolean } = {}): Promise<void> {
  const liveReload = options.liveReload ?? false;
  const port = numberArgument("--port", liveReload ? 5173 : 4173);
  const hostname = stringArgument("--host", "127.0.0.1");

  if (liveReload) {
    const { buildSite } = await import("../src/build.ts");
    await buildSite();
    void watchAndBuild(buildSite).catch((error) => console.error(error));
  }

  const server = Deno.serve({ hostname, port, onListen() {} }, async (request) => {
    const url = new URL(request.url);
    if (liveReload && url.pathname === "/__dev/events") return liveReloadResponse();
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const canonical = canonicalPath(url.pathname);
    if (canonical) {
      const destination = new URL(canonical, url);
      destination.search = url.search;
      return Response.redirect(destination, 307);
    }

    const resolved = resolvePath(url.pathname);
    let status = resolved === null ? 404 : 200;
    let file = new URL(resolved ?? "404.html", buildDirectory);
    try {
      const info = await Deno.stat(file);
      if (!info.isFile) throw new Deno.errors.NotFound();
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
      file = new URL("404.html", buildDirectory);
      status = 404;
    }

    const contentType = mediaType(file.pathname);
    const headers = new Headers({
      "Content-Type": contentType,
      "Cache-Control": cacheControl(file.pathname),
      "X-Content-Type-Options": "nosniff",
    });
    if (request.method === "HEAD") return new Response(null, { status, headers });

    if (contentType.startsWith("text/html")) {
      let html = await Deno.readTextFile(file);
      if (liveReload) html = html.replace("</body>", `${liveReloadScript}</body>`);
      return new Response(html, { status, headers });
    }
    return new Response(await Deno.readFile(file), { status, headers });
  });

  console.log(`Serving ${buildDirectory.pathname} at http://${hostname}:${port}`);
  await server.finished;
}

async function watchAndBuild(buildSite: () => Promise<void>): Promise<void> {
  const watcher = Deno.watchFs(watchPaths);
  let timer: number | undefined;
  let building = false;
  let queued = false;

  const rebuild = async () => {
    if (building) {
      queued = true;
      return;
    }
    building = true;
    try {
      await buildSite();
      for (const controller of reloadClients) {
        controller.enqueue(encoder.encode("data: reload\n\n"));
      }
    } catch (error) {
      console.error(error);
    } finally {
      building = false;
      if (queued) {
        queued = false;
        await rebuild();
      }
    }
  };

  for await (const _event of watcher) {
    if (timer !== undefined) clearTimeout(timer);
    timer = setTimeout(() => void rebuild(), 75);
  }
}

function liveReloadResponse(): Response {
  let client: ReadableStreamDefaultController<Uint8Array>;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      client = controller;
      reloadClients.add(controller);
      controller.enqueue(encoder.encode(": connected\n\n"));
    },
    cancel() {
      reloadClients.delete(client);
    },
  });
  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-store",
      Connection: "keep-alive",
    },
  });
}

export function resolvePath(pathname: string): string | null {
  let path: string;
  try {
    path = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  if (!path.startsWith("/") || path.startsWith("//") || path.includes("\\")) return null;
  if (path === "/") return "index.html";
  const relative = path.slice(1);
  const resolved = relative.includes(".") ? relative : `${relative}.html`;
  const file = new URL(resolved, buildDirectory);
  return file.href.startsWith(buildDirectory.href) ? resolved : null;
}

function canonicalPath(pathname: string): string | null {
  if (pathname === "/") return null;
  if (pathname.endsWith("/")) return pathname.slice(0, -1);
  if (pathname.endsWith(".html")) return pathname.slice(0, -5) || "/";
  return null;
}

function mediaType(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1);
  return {
    css: "text/css; charset=utf-8",
    gif: "image/gif",
    html: "text/html; charset=utf-8",
    js: "text/javascript; charset=utf-8",
    json: "application/json; charset=utf-8",
    png: "image/png",
    svg: "image/svg+xml",
    webp: "image/webp",
    woff2: "font/woff2",
    xml: path.endsWith("rss.xml")
      ? "application/rss+xml; charset=utf-8"
      : "application/xml; charset=utf-8",
  }[extension] ?? "application/octet-stream";
}

function cacheControl(path: string): string {
  if (path.includes("/assets/")) return "public, max-age=31536000, immutable";
  if (path.includes("/fonts/")) return "public, max-age=604800, stale-while-revalidate=86400";
  return "public, max-age=0, s-maxage=86400, stale-while-revalidate=604800";
}

function stringArgument(name: string, fallback: string): string {
  const index = Deno.args.indexOf(name);
  return index === -1 ? fallback : Deno.args[index + 1] ?? fallback;
}

function numberArgument(name: string, fallback: number): number {
  const value = Number(stringArgument(name, String(fallback)));
  return Number.isFinite(value) ? value : fallback;
}

const liveReloadScript = `<script>
  new EventSource("/__dev/events").addEventListener("message", (event) => {
    if (event.data === "reload") location.reload();
  });
</script>`;
