import { describe, expect, it } from "vitest";
import { z } from "zod";
import {
	type BlogPost,
	type BlogPostFrontmatter,
	blogPostFrontmatterSchema,
	blogPostSchema,
	validateBlogPosts,
} from "./blogSchema";

describe("blogSchema", () => {
	describe("blogPostFrontmatterSchema", () => {
		it("should validate correct frontmatter", () => {
			const validFrontmatter = {
				title: "Test Post",
				date: "2024-01-01",
				description: "This is a test post",
			};

			const result = blogPostFrontmatterSchema.safeParse(validFrontmatter);
			expect(result.success).toBe(true);
			if (result.success) {
				expect(result.data).toEqual(validFrontmatter);
			}
		});

		it("should accept optional layout field", () => {
			const frontmatterWithLayout = {
				title: "Test Post",
				date: "2024-01-01",
				description: "This is a test post",
				layout: "custom-layout",
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatterWithLayout);
			expect(result.success).toBe(true);
		});

		it("should reject missing required fields", () => {
			const invalidFrontmatter = {
				title: "Test Post",
				// missing date and description
			};

			const result = blogPostFrontmatterSchema.safeParse(invalidFrontmatter);
			expect(result.success).toBe(false);
			if (!result.success) {
				expect(result.error.issues).toHaveLength(2);
			}
		});

		it("should reject empty strings", () => {
			const emptyFieldsFrontmatter = {
				title: "",
				date: "2024-01-01",
				description: "Valid description",
			};

			const result = blogPostFrontmatterSchema.safeParse(
				emptyFieldsFrontmatter,
			);
			expect(result.success).toBe(false);
			if (!result.success) {
				expect(result.error.issues[0].message).toBe("Title is required");
			}
		});
	});

	describe("blogPostSchema", () => {
		it("should validate complete blog post object", () => {
			const validPost = {
				frontmatter: {
					title: "Test Post",
					date: "2024-01-01",
					description: "This is a test post",
				},
				url: "/posts/test-post",
				file: "/src/pages/posts/test-post.mdx",
				default: () => {},
			};

			const result = blogPostSchema.safeParse(validPost);
			expect(result.success).toBe(true);
		});

		it("should accept post with only required frontmatter", () => {
			const minimalPost = {
				frontmatter: {
					title: "Minimal Post",
					date: "2024-01-01",
					description: "Minimal description",
				},
			};

			const result = blogPostSchema.safeParse(minimalPost);
			expect(result.success).toBe(true);
		});
	});

	describe("validateBlogPosts", () => {
		it("should validate array of valid posts", () => {
			const validPosts = [
				{
					frontmatter: {
						title: "Post 1",
						date: "2024-01-01",
						description: "First post",
					},
				},
				{
					frontmatter: {
						title: "Post 2",
						date: "2024-01-02",
						description: "Second post",
					},
				},
			];

			const result = validateBlogPosts(validPosts);
			expect(result).toHaveLength(2);
			expect(result[0].frontmatter.title).toBe("Post 1");
		});

		it("should throw error for invalid post", () => {
			const invalidPosts = [
				{
					frontmatter: {
						title: "Valid Post",
						date: "2024-01-01",
						description: "Valid description",
					},
				},
				{
					frontmatter: {
						title: "Invalid Post",
						// missing required fields
					},
				},
			];

			expect(() => validateBlogPosts(invalidPosts)).toThrow(
				"Invalid blog post at index 1",
			);
		});

		it("should handle empty array", () => {
			const result = validateBlogPosts([]);
			expect(result).toEqual([]);
		});

		it("should provide detailed error messages", () => {
			const invalidPost = [
				{
					frontmatter: {
						title: "",
						date: "",
						description: "",
					},
				},
			];

			expect(() => validateBlogPosts(invalidPost)).toThrow(/Title is required/);
			expect(() => validateBlogPosts(invalidPost)).toThrow(/Date is required/);
			expect(() => validateBlogPosts(invalidPost)).toThrow(
				/Description is required/,
			);
		});
	});

	describe("TypeScript types", () => {
		it("should correctly type BlogPostFrontmatter", () => {
			const frontmatter: BlogPostFrontmatter = {
				title: "Type Test",
				date: "2024-01-01",
				description: "Testing types",
				layout: "optional-layout",
			};

			expect(frontmatter.title).toBe("Type Test");
			expect(frontmatter.layout).toBe("optional-layout");
		});

		it("should correctly type BlogPost", () => {
			const post: BlogPost = {
				frontmatter: {
					title: "Type Test",
					date: "2024-01-01",
					description: "Testing types",
				},
				url: "/test",
				file: "/test.mdx",
			};

			expect(post.frontmatter.title).toBe("Type Test");
			expect(post.url).toBe("/test");
		});
	});
});
