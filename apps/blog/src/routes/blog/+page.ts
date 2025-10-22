import type { Metadata, Post } from "$lib/types";

export const load = async () => {
	// Dynamically import all blog posts using Vite's import.meta.glob
	const postModules = import.meta.glob("./**/*.svx", { eager: true });

	const posts: Post[] = Object.entries(postModules).map(([path, module]) => {
		// Extract the slug from the path
		// Path format: ./hello-world/+page.svx -> hello-world
		const slug = path.match(/\.\/(.+?)\/\+page\.svx/)?.[1];

		// Access the metadata from the mdsvex module
		const metadata = (module as { metadata?: Metadata }).metadata || {};

		return {
			slug: slug || "",
			title: metadata.title || "",
			topic: metadata.topic,
			date: metadata.date || "",
			description: metadata.description || "",
		};
	});

	// Sort posts by date (newest first)
	posts.sort((a, b) => {
		const dateA = new Date(a.date);
		const dateB = new Date(b.date);
		return dateB.getTime() - dateA.getTime();
	});

	return {
		posts,
		title: "Blog - wlls.dev",
		description: "Technical writing and reflections.",
	};
};
