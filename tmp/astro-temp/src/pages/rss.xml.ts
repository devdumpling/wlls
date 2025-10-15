import rss from "@astrojs/rss";
import type { APIContext } from "astro";
import {
	getPostSlug,
	getPublishedPosts,
	sortPostsByDate,
} from "../utils/posts";

export async function GET(context: APIContext) {
	const posts = getPublishedPosts();
	const sortedPosts = sortPostsByDate(posts);

	const items = sortedPosts.map((post) => {
		const slug = getPostSlug(post);
		return {
			title: post.frontmatter.title,
			pubDate: new Date(post.frontmatter.date),
			description: post.frontmatter.description,
			link: `/fruits/${slug}/`,
		};
	});

	return rss({
		title: "Dev Wells - Digital Garden",
		description:
			"Thoughts, technical posts, and reflections from a digital garden",
		site: context.site || "https://wlls.dev",
		items,
		customData: `<language>en-us</language>`,
	});
}
