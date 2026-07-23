import aboutSource from "@/content/about.md?raw";
import { MarkdownContent } from "@/components/MarkdownContent.tsx";
import { PageMeta } from "@/components/PageMeta.tsx";
import { parsePage } from "@/lib/markdown.ts";
import { define } from "@/utils.ts";

const about = parsePage(aboutSource, "about");

export default define.page(function About() {
  return (
    <>
      <PageMeta title="About" description={about.description} path="/about" />
      <article class="article about-page">
        <header class="article-header">
          <p class="eyebrow">About</p>
          <h1>{about.title}</h1>
          <p class="article-dek">{about.description}</p>
        </header>
        <MarkdownContent content={about.content} id="about-book-content" />
      </article>
    </>
  );
});
