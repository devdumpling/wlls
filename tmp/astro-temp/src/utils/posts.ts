import type { BlogPost } from "./blogSchema";
import { validateBlogPosts } from "./blogSchema";

// Centralized blog post fetching
export function getAllBlogPosts(): BlogPost[] {
	const rawPosts = Object.values(
		import.meta.glob("/src/pages/fruits/*.mdx", { eager: true }),
	);
	return validateBlogPosts(rawPosts);
}

// Sort posts by date (newest first)
export function sortPostsByDate(posts: BlogPost[]): BlogPost[] {
	return [...posts].sort(
		(a, b) =>
			new Date(b.frontmatter.date).getTime() -
			new Date(a.frontmatter.date).getTime(),
	);
}

// Get the latest post
export function getLatestPost(): BlogPost | undefined {
	const posts = getAllBlogPosts();
	const sorted = sortPostsByDate(posts);
	return sorted.at(0);
}

// Filter out draft posts
export function getPublishedPosts(): BlogPost[] {
	const posts = getAllBlogPosts();
	return posts.filter((post) => post.frontmatter.date !== "Coming Soon");
}

// Get post slug from file path
export function getPostSlug(post: BlogPost): string | undefined {
	return post.file?.split("/").pop()?.replace(".mdx", "");
}
