import type { BlogPost } from "./blogSchema";
import { validateBlogPosts } from "./blogSchema";

export function getLatestPost(): BlogPost | undefined {
	const rawPosts = Object.values(
		import.meta.glob("/src/pages/fruits/*.mdx", { eager: true }),
	);
	const posts = validateBlogPosts(rawPosts);
	
	return posts
		.sort((a, b) => new Date(b.frontmatter.date).getTime() - new Date(a.frontmatter.date).getTime())
		.at(0);
}