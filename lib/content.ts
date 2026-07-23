import { parsePostSource, type PostSource } from "./frontmatter.ts";

export { formatDate } from "./frontmatter.ts";
export type { PostSummary } from "./frontmatter.ts";
export type { Post } from "./markdown.ts";

const postSources = import.meta.glob<string>("/posts/*.md", {
  eager: true,
  import: "default",
  query: "?raw",
});

const sources = Object.entries(postSources)
  .map(([path, source]) => parsePostSource(source, path.slice(path.lastIndexOf("/") + 1, -3)))
  .sort((a, b) => b.date.localeCompare(a.date));
const posts = sources.map(({ body: _body, ...post }) => post);
const sourcesBySlug = new Map(sources.map((source) => [source.slug, source]));
const renderedPosts = new Map<string, Promise<import("./markdown.ts").Post>>();

export function getPosts() {
  return posts;
}

export function getPost(slug: string) {
  const source = sourcesBySlug.get(slug);
  if (!source) return Promise.resolve(undefined);

  let post = renderedPosts.get(slug);
  if (!post) {
    post = renderPost(source);
    renderedPosts.set(slug, post);
  }
  return post;
}

async function renderPost(source: PostSource) {
  const markdown = await import("./markdown.ts");
  return markdown.renderPost(source);
}
