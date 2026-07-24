import { parsePostSource, type PostSource, type PostSummary } from "./frontmatter.ts";
import { type Post, renderPost } from "./markdown.ts";

const postsDirectory = new URL("../posts/", import.meta.url);
const aboutFile = new URL("../content/about.md", import.meta.url);

export async function loadPostSources(): Promise<PostSource[]> {
  const filenames: string[] = [];

  for await (const entry of Deno.readDir(postsDirectory)) {
    if (entry.isFile && entry.name.endsWith(".md")) filenames.push(entry.name);
  }

  const sources = await Promise.all(
    filenames.map(async (filename) => {
      const source = await Deno.readTextFile(new URL(filename, postsDirectory));
      return parsePostSource(source, filename.slice(0, -3));
    }),
  );

  return sources.sort((a, b) => b.date.localeCompare(a.date));
}

export function summarizePosts(sources: readonly PostSource[]): PostSummary[] {
  return sources.map(({ body: _body, ...post }) => post);
}

export function renderPosts(sources: readonly PostSource[]): Post[] {
  return sources.map(renderPost);
}

export async function loadAboutSource(): Promise<string> {
  return await Deno.readTextFile(aboutFile);
}
