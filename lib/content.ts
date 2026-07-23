import { parsePost } from "./markdown.ts";

export { formatDate } from "./markdown.ts";
export type { Post } from "./markdown.ts";

const postSources = import.meta.glob<string>("/posts/*.md", {
  eager: true,
  import: "default",
  query: "?raw",
});

const posts = Object.entries(postSources)
  .map(([path, source]) => parsePost(source, path.slice(path.lastIndexOf("/") + 1, -3)))
  .sort((a, b) => b.date.localeCompare(a.date));

export function getPosts() {
  return posts;
}

export function getPost(slug: string) {
  return posts.find((post) => post.slug === slug);
}
