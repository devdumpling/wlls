import { z } from "zod";

// Schema for blog post frontmatter
export const blogPostFrontmatterSchema = z.object({
	title: z.string().min(1, "Title is required"),
	date: z.string().min(1, "Date is required"),
	description: z.string().min(1, "Description is required"),
	layout: z.string().optional(),
});

// Schema for the complete blog post object from import.meta.glob()
export const blogPostSchema = z.object({
	frontmatter: blogPostFrontmatterSchema,
	url: z.string().optional(),
	file: z.string().optional(),
	default: z.any().optional(),
});

// Type exports
export type BlogPostFrontmatter = z.infer<typeof blogPostFrontmatterSchema>;
export type BlogPost = z.infer<typeof blogPostSchema>;

// Helper function to validate and parse blog posts
export function validateBlogPosts(posts: unknown[]): BlogPost[] {
	return posts.map((post, index) => {
		try {
			return blogPostSchema.parse(post);
		} catch (error) {
			if (error instanceof z.ZodError) {
				console.error(
					`Blog post validation error at index ${index}:`,
					error.issues,
				);
				throw new Error(
					`Invalid blog post at index ${index}: ${error.issues.map((i) => i.message).join(", ")}`,
				);
			}
			throw error;
		}
	});
}
