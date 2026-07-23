import type { Post } from "@/lib/content.ts";

interface PostListProps {
  posts: readonly Post[];
}

export function PostList({ posts }: PostListProps) {
  const seasons = groupBySeason(posts);
  const yearAlignments = new Map<number, "start" | "end">();

  return (
    <div class="post-seasons">
      {seasons.map((season) => {
        if (!yearAlignments.has(season.year)) {
          yearAlignments.set(season.year, yearAlignments.size % 2 === 0 ? "start" : "end");
        }
        const alignment = yearAlignments.get(season.year);

        return (
          <section class={`post-season post-season--${alignment}`}>
            <h2>{season.label}</h2>
            <ol class="post-list">
              {season.posts.map((post) => (
                <li>
                  <article>
                    <a class="post-list__link" href={`/blog/${post.slug}`}>
                      <h3>{post.title}</h3>
                      <p>{post.description}</p>
                    </a>
                  </article>
                </li>
              ))}
            </ol>
          </section>
        );
      })}
    </div>
  );
}

interface PostSeason {
  label: string;
  year: number;
  posts: Post[];
}

function groupBySeason(posts: readonly Post[]): PostSeason[] {
  const seasons = new Map<string, PostSeason>();

  for (const post of posts) {
    const dateYear = Number(post.date.slice(0, 4));
    const month = Number(post.date.slice(5, 7));
    const [name, year] = month <= 2
      ? ["Winter", dateYear]
      : month <= 5
      ? ["Spring", dateYear]
      : month <= 8
      ? ["Summer", dateYear]
      : month <= 11
      ? ["Fall", dateYear]
      : ["Winter", dateYear];
    const label = `${name} ${year}`;
    const season = seasons.get(label);

    if (season) {
      season.posts.push(post);
    } else {
      seasons.set(label, { label, year, posts: [post] });
    }
  }

  return [...seasons.values()];
}
