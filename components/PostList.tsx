import { formatDate, type Post } from "@/lib/content.ts";

interface PostListProps {
  posts: readonly Post[];
  compact?: boolean;
}

export function PostList({ posts, compact = false }: PostListProps) {
  return (
    <ol class={`post-list${compact ? " post-list--compact" : ""}`}>
      {posts.map((post) => (
        <li>
          <article>
            <a class="post-list__link" href={`/blog/${post.slug}`}>
              <div class="post-list__heading">
                <h2>{post.title}</h2>
                <time dateTime={post.date}>{formatDate(post.date, "short")}</time>
              </div>
              <p>{post.description}</p>
              <span class="post-list__meta">
                {post.topic && <span>{post.topic}</span>}
                <span>{post.minutes} min read</span>
              </span>
            </a>
          </article>
        </li>
      ))}
    </ol>
  );
}
