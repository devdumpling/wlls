// deno-lint-ignore-file react-no-danger -- Markdown is sanitized and JSON-LD is escaped.
import { page } from "fresh";
import { MarkdownContent } from "@/components/MarkdownContent.tsx";
import { NotFound } from "@/components/NotFound.tsx";
import { PageMeta } from "@/components/PageMeta.tsx";
import { formatDate, getPost } from "@/lib/content.ts";
import { absoluteUrl, site } from "@/lib/site.ts";
import { define } from "@/utils.ts";

export const handler = define.handlers({
  async GET(ctx) {
    const post = await getPost(ctx.params.slug);
    return page({ post, path: ctx.url.pathname }, { status: post ? 200 : 404 });
  },
});

export default define.page<typeof handler>(function Article({ data }) {
  const { post } = data;
  if (!post) return <NotFound path={data.path} />;

  const structuredData = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.description,
    datePublished: post.date,
    author: { "@type": "Person", name: site.author },
    mainEntityOfPage: absoluteUrl(`/blog/${post.slug}`),
  }).replaceAll("<", "\\u003c");

  return (
    <>
      <PageMeta
        title={post.title}
        description={post.description}
        path={`/blog/${post.slug}`}
        type="article"
        published={post.date}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: structuredData }}
      />
      <article class="article">
        <header class="article-header">
          <p class="article-meta">
            {post.topic && <span>{post.topic}</span>}
            <time dateTime={post.date}>{formatDate(post.date)}</time>
            <span>{post.minutes} min read</span>
          </p>
          <h1>{post.title}</h1>
          <p class="article-dek">{post.description}</p>
        </header>
        <MarkdownContent content={post.content} />
        <footer class="article-footer">
          <a href="/">Back</a>
        </footer>
      </article>
    </>
  );
});
