import { describe, expect, it } from "vitest";
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

	// Edge cases
	describe("frontmatter validation edge cases", () => {
		it("should handle very long strings", () => {
			const longString = "a".repeat(10000);
			const frontmatter = {
				title: longString,
				date: "2024-01-01",
				description: longString,
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatter);
			expect(result.success).toBe(true);
		});

		it("should handle special characters in strings", () => {
			const frontmatter = {
				title: "Test 😀 Post with émojis & spëcial chârs!",
				date: "2024-01-01",
				description: "Description with\nnewlines\tand\ttabs",
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatter);
			expect(result.success).toBe(true);
		});

		it("should handle whitespace-only strings", () => {
			const frontmatter = {
				title: "   ",
				date: "2024-01-01",
				description: "Valid",
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatter);
			expect(result.success).toBe(true);
		});

		it("should handle null and undefined values", () => {
			const frontmatter = {
				title: null as any,
				date: undefined as any,
				description: "Valid",
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatter);
			expect(result.success).toBe(false);
			if (!result.success) {
				expect(result.error.issues).toHaveLength(2);
			}
		});

		it("should handle numeric values incorrectly passed", () => {
			const frontmatter = {
				title: 123 as any,
				date: new Date() as any,
				description: true as any,
			};

			const result = blogPostFrontmatterSchema.safeParse(frontmatter);
			expect(result.success).toBe(false);
		});
	});

	describe("blog post schema edge cases", () => {
		it("should handle post with all optional fields", () => {
			const post = {
				frontmatter: {
					title: "Full Post",
					date: "2024-01-01",
					description: "Complete post",
					layout: "custom",
				},
				url: "/test",
				file: "/test.mdx",
				default: () => console.log("default export"),
			};

			const result = blogPostSchema.safeParse(post);
			expect(result.success).toBe(true);
		});

		it("should handle post with extra unexpected fields", () => {
			const post = {
				frontmatter: {
					title: "Extra Fields",
					date: "2024-01-01",
					description: "Has extra fields",
					unexpectedField: "should be ignored",
				},
				url: "/test",
				extraField: "ignored",
			};

			const result = blogPostSchema.safeParse(post);
			expect(result.success).toBe(true);
		});

		it("should handle deeply nested default export", () => {
			const complexDefault = {
				Component: () => null,
				metadata: { tags: ["test"] },
				render: () => ({ html: "" }),
			};

			const post = {
				frontmatter: {
					title: "Complex Default",
					date: "2024-01-01",
					description: "Complex default export",
				},
				default: complexDefault,
			};

			const result = blogPostSchema.safeParse(post);
			expect(result.success).toBe(true);
		});
	});

	describe("validateBlogPosts edge cases", () => {
		it("should handle very large arrays efficiently", () => {
			const largePosts = Array.from({ length: 1000 }, (_, i) => ({
				frontmatter: {
					title: `Post ${i}`,
					date: `2024-01-${String((i % 28) + 1).padStart(2, "0")}`,
					description: `Description ${i}`,
				},
			}));

			const startTime = performance.now();
			const result = validateBlogPosts(largePosts);
			const endTime = performance.now();

			expect(result).toHaveLength(1000);
			expect(endTime - startTime).toBeLessThan(100); // Should be fast
		});

		it("should provide helpful error for partially valid data", () => {
			const mixedPosts = [
				{
					frontmatter: {
						title: "Valid",
						date: "2024-01-01",
						description: "Valid",
					},
				},
				{
					frontmatter: {
						title: "Missing Description",
						date: "2024-01-01",
						// Missing description
					},
				},
			];

			expect(() => validateBlogPosts(mixedPosts)).toThrow(/index 1/);
		});

		it("should handle posts with circular references", () => {
			const circular: any = {
				frontmatter: {
					title: "Circular",
					date: "2024-01-01",
					description: "Has circular ref",
				},
			};
			circular.self = circular; // Create circular reference

			// Should handle without infinite loop
			const result = blogPostSchema.safeParse(circular);
			expect(result.success).toBe(true);
		});

		it("should validate dates in various formats", () => {
			const posts = [
				{
					frontmatter: {
						title: "ISO Date",
						date: "2024-01-15T10:30:00Z",
						description: "ISO format",
					},
				},
				{
					frontmatter: {
						title: "Coming Soon",
						date: "Coming Soon",
						description: "Special string",
					},
				},
				{
					frontmatter: {
						title: "US Format",
						date: "01/15/2024",
						description: "US date",
					},
				},
			];

			const result = validateBlogPosts(posts);
			expect(result).toHaveLength(3);
			// All date formats should be accepted as strings
			result.forEach((post) => {
				expect(typeof post.frontmatter.date).toBe("string");
			});
		});

		it("should handle malformed input gracefully", () => {
			const malformed = [
				null,
				undefined,
				"not an object",
				123,
				[],
				{ notFrontmatter: {} },
			];

			for (const input of malformed) {
				expect(() => validateBlogPosts([input as any])).toThrow();
			}
		});
	});

	describe("error message quality", () => {
		it("should provide clear error for missing frontmatter", () => {
			const post = {
				url: "/test",
				file: "/test.mdx",
				// Missing frontmatter entirely
			};

			try {
				validateBlogPosts([post as any]);
				expect.fail("Should have thrown");
			} catch (error: any) {
				expect(error.message).toContain("Invalid");
				expect(error.message).toContain("index 0");
			}
		});

		it("should provide clear error for wrong type", () => {
			const post = {
				frontmatter: "not an object" as any,
			};

			try {
				validateBlogPosts([post]);
				expect.fail("Should have thrown");
			} catch (error: any) {
				expect(error.message).toContain("Invalid");
				expect(error.message).toContain("index 0");
			}
		});
	});
});
