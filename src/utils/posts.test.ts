import { describe, expect, it } from "vitest";
import type { BlogPost } from "./blogSchema";
import { getPostSlug, sortPostsByDate } from "./posts";

describe("posts utilities", () => {
	const mockPosts: BlogPost[] = [
		{
			frontmatter: {
				title: "Test Post 1",
				date: "2024-01-15",
				description: "First test post",
			},
			url: "/fruits/test-post-1",
			file: "/src/pages/fruits/test-post-1.mdx",
		},
		{
			frontmatter: {
				title: "Test Post 2",
				date: "2024-02-20",
				description: "Second test post",
			},
			url: "/fruits/test-post-2",
			file: "/src/pages/fruits/test-post-2.mdx",
		},
		{
			frontmatter: {
				title: "Draft Post",
				date: "Coming Soon",
				description: "This is a draft",
			},
			url: "/fruits/draft-post",
			file: "/src/pages/fruits/draft-post.mdx",
		},
	];

	describe("sortPostsByDate", () => {
		it("should sort posts by date in descending order", () => {
			const sorted = sortPostsByDate(mockPosts.slice(0, 2));
			expect(sorted[0].frontmatter.title).toBe("Test Post 2");
			expect(sorted[1].frontmatter.title).toBe("Test Post 1");
		});

		it("should handle empty array", () => {
			const sorted = sortPostsByDate([]);
			expect(sorted).toEqual([]);
		});

		it("should not mutate original array", () => {
			const original = [...mockPosts];
			sortPostsByDate(mockPosts);
			expect(mockPosts).toEqual(original);
		});

		it("should handle single post", () => {
			const sorted = sortPostsByDate([mockPosts[0]]);
			expect(sorted).toHaveLength(1);
			expect(sorted[0]).toEqual(mockPosts[0]);
		});

		it("should handle posts with same date", () => {
			const sameDatePosts: BlogPost[] = [
				{
					frontmatter: {
						title: "Post A",
						date: "2024-01-01",
						description: "First post same date",
					},
				},
				{
					frontmatter: {
						title: "Post B",
						date: "2024-01-01",
						description: "Second post same date",
					},
				},
			];
			const sorted = sortPostsByDate(sameDatePosts);
			expect(sorted).toHaveLength(2);
			// Both have same date, so order should be stable
			expect(sorted.map((p) => p.frontmatter.title)).toContain("Post A");
			expect(sorted.map((p) => p.frontmatter.title)).toContain("Post B");
		});
	});

	describe("getPostSlug", () => {
		it("should extract slug from file path", () => {
			const slug = getPostSlug(mockPosts[0]);
			expect(slug).toBe("test-post-1");
		});

		it("should handle post without file path", () => {
			const postWithoutFile: BlogPost = {
				frontmatter: {
					title: "No File",
					date: "2024-01-01",
					description: "No file path",
				},
			};
			const slug = getPostSlug(postWithoutFile);
			expect(slug).toBeUndefined();
		});

		it("should handle edge case file paths", () => {
			const postWithComplexPath: BlogPost = {
				frontmatter: {
					title: "Complex",
					date: "2024-01-01",
					description: "Complex path",
				},
				file: "/deep/nested/path/complex-post-name.mdx",
			};
			const slug = getPostSlug(postWithComplexPath);
			expect(slug).toBe("complex-post-name");
		});

		it("should handle file without extension", () => {
			const postWithoutExt: BlogPost = {
				frontmatter: {
					title: "No Extension",
					date: "2024-01-01",
					description: "No extension",
				},
				file: "/src/pages/fruits/no-extension",
			};
			const slug = getPostSlug(postWithoutExt);
			expect(slug).toBe("no-extension");
		});

		it("should handle file with multiple dots", () => {
			const postWithDots: BlogPost = {
				frontmatter: {
					title: "Multiple Dots",
					date: "2024-01-01",
					description: "Multiple dots in filename",
				},
				file: "/src/pages/fruits/my.special.post.mdx",
			};
			const slug = getPostSlug(postWithDots);
			expect(slug).toBe("my.special.post");
		});
	});
});
