export interface Post {
  url: string;
  frontmatter: {
    title: string;
    date: string;
    description?: string;
    draft?: boolean;
    tags?: string[];
  };
  compiledContent?: () => string;
  Content?: any; // Astro MDX component
}

export interface PostCollection {
  posts: Post[];
  total: number;
}