import { loadAboutSource, loadPostSources, renderPosts, summarizePosts } from "./content.ts";
import { formatDate } from "./frontmatter.ts";
import { parsePage } from "./markdown.ts";
import {
  type Assets,
  renderAbout,
  renderArticle,
  renderHome,
  renderNotFound,
  renderResume,
} from "./templates.ts";
import { createRss, createSitemap } from "./xml.ts";

const buildDirectory = new URL("../build/", import.meta.url);
const staticDirectory = new URL("../static/", import.meta.url);
const stylesDirectory = new URL("./styles/", import.meta.url);
const clientFile = new URL("./client/site.js", import.meta.url);
const styleFiles = [
  "foundation.css",
  "layout.css",
  "components.css",
  "prose.css",
  "book.css",
  "resume.css",
  "transitions.css",
  "utilities.css",
];

export async function buildSite(): Promise<void> {
  const [sources, aboutSource, css, javascript] = await Promise.all([
    loadPostSources(),
    loadAboutSource(),
    readStyles(),
    Deno.readTextFile(clientFile),
  ]);
  const posts = renderPosts(sources);
  const summaries = summarizePosts(sources);
  const about = parsePage(aboutSource, "about");
  const assets = await createAssets(css, javascript);

  await replaceBuildDirectory();
  await copyDirectory(staticDirectory, buildDirectory);
  await writeAsset(assets.css.slice(1), css);
  await writeAsset(assets.js.slice(1), javascript);

  await Promise.all([
    writeRoute("/", renderHome(summaries, assets)),
    writeRoute("/about", renderAbout(about, assets)),
    writeRoute("/resume", renderResume(assets)),
    writeRoute("/404", renderNotFound(assets)),
    writeFile("rss.xml", createRss(summaries)),
    writeFile("sitemap.xml", createSitemap(summaries)),
    ...posts.map((post) =>
      writeRoute(`/blog/${post.slug}`, renderArticle(post, formatDate(post.date), assets))
    ),
  ]);

  console.log(`Built ${posts.length + 4} pages and 2 XML feeds`);
}

async function readStyles(): Promise<string> {
  const files = await Promise.all(
    styleFiles.map((filename) => Deno.readTextFile(new URL(filename, stylesDirectory))),
  );
  return files.join("\n");
}

async function createAssets(css: string, javascript: string): Promise<Assets> {
  const [cssHash, jsHash] = await Promise.all([contentHash(css), contentHash(javascript)]);
  return {
    css: `/assets/site-${cssHash}.css`,
    js: `/assets/site-${jsHash}.js`,
  };
}

async function contentHash(content: string): Promise<string> {
  const bytes = new TextEncoder().encode(content);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return Array.from(digest.slice(0, 6), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function replaceBuildDirectory(): Promise<void> {
  try {
    await Deno.remove(buildDirectory, { recursive: true });
  } catch (error) {
    if (!(error instanceof Deno.errors.NotFound)) throw error;
  }
  await Deno.mkdir(buildDirectory, { recursive: true });
}

async function copyDirectory(source: URL, destination: URL): Promise<void> {
  await Deno.mkdir(destination, { recursive: true });
  for await (const entry of Deno.readDir(source)) {
    if (entry.name === ".DS_Store") continue;
    const sourceEntry = new URL(entry.name, source);
    const destinationEntry = new URL(entry.name, destination);
    if (entry.isDirectory) {
      await copyDirectory(
        new URL(`${entry.name}/`, source),
        new URL(`${entry.name}/`, destination),
      );
    } else if (entry.isFile) {
      await Deno.copyFile(sourceEntry, destinationEntry);
    }
  }
}

async function writeRoute(path: string, content: string): Promise<void> {
  const filename = path === "/" ? "index.html" : `${path.slice(1)}.html`;
  await writeFile(filename, content);
}

async function writeAsset(path: string, content: string): Promise<void> {
  await writeFile(path, content);
}

async function writeFile(path: string, content: string): Promise<void> {
  const file = new URL(path, buildDirectory);
  await Deno.mkdir(new URL("./", file), { recursive: true });
  await Deno.writeTextFile(file, content);
}
