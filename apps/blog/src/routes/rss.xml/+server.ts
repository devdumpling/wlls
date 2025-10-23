import type { Metadata, Post } from "$lib/types";

const site = {
	title: "wlls.dev",
	description: "Software engineer, tinkerer, writer.",
	url: "https://wlls.dev",
};

export const prerender = true;

export async function GET() {
	// Load all blog posts
	const postModules = import.meta.glob("../blog/**/*.svx", { eager: true });

	const posts: Post[] = Object.entries(postModules).map(([path, module]) => {
		// Extract the slug from the path
		// Path format: ../blog/hello-world/+page.svx -> hello-world
		const slug = path.match(/\.\.\/blog\/(.+?)\/\+page\.svx/)?.[1];

		// Access the metadata from the mdsvex module
		const metadata = (module as { metadata?: Metadata }).metadata || {};

		return {
			slug: slug || "",
			title: metadata.title || "",
			topic: metadata.topic,
			date: metadata.date || "",
			description: metadata.description || "",
			archive: metadata.archive || false,
		};
	});

	// Sort posts by date (newest first)
	posts.sort((a, b) => {
		const dateA = new Date(a.date);
		const dateB = new Date(b.date);
		return dateB.getTime() - dateA.getTime();
	});

	const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
	<channel>
		<title>${site.title}</title>
		<description>${site.description}</description>
		<link>${site.url}</link>
		<atom:link href="${site.url}/rss.xml" rel="self" type="application/rss+xml" />
		<language>en-us</language>
		<lastBuildDate>${new Date().toUTCString()}</lastBuildDate>
		${posts
			.map(
				(post) => `
		<item>
			<title>${escapeXml(post.title)}</title>
			<description>${escapeXml(post.description)}</description>
			<link>${site.url}/blog/${post.slug}</link>
			<guid isPermaLink="true">${site.url}/blog/${post.slug}</guid>
			<pubDate>${new Date(post.date).toUTCString()}</pubDate>
			${post.topic ? `<category>${escapeXml(post.topic)}</category>` : ""}
		</item>`,
			)
			.join("")}
	</channel>
</rss>`;

	return new Response(xml.trim(), {
		headers: {
			"Content-Type": "application/xml; charset=utf-8",
			"Cache-Control": "max-age=0, s-maxage=3600",
		},
	});
}

function escapeXml(unsafe: string): string {
	return unsafe
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&apos;");
}
