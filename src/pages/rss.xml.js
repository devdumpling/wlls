import rss from "@astrojs/rss";
import { validateBlogPosts } from "../utils/blogSchema";

export async function GET(context) {
	const rawPosts = Object.values(
		import.meta.glob("./fruits/*.mdx", { eager: true }),
	);
	const posts = validateBlogPosts(rawPosts);

	const items = posts
		.filter((post) => post.frontmatter.date !== "Coming Soon")
		.map((post) => {
			const slug = post.file?.split("/").pop()?.replace(".mdx", "");
			return {
				title: post.frontmatter.title,
				pubDate: new Date(post.frontmatter.date),
				description: post.frontmatter.description,
				link: `/fruits/${slug}/`,
			};
		})
		.sort((a, b) => b.pubDate.getTime() - a.pubDate.getTime());

	return rss({
		title: "Dev Wells - Digital Garden",
		description:
			"Thoughts, technical posts, and reflections from a digital garden",
		site: context.site || "https://wlls.dev",
		items,
		customData: `<language>en-us</language>`,
	});
}
