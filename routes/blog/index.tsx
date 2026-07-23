import { PageMeta } from "@/components/PageMeta.tsx";
import { PostList } from "@/components/PostList.tsx";
import { getPosts } from "@/lib/content.ts";
import { define } from "@/utils.ts";

export default define.page(function Writing() {
  const posts = getPosts();
  const current = posts.filter((post) => !post.archive);
  const archive = posts.filter((post) => post.archive);

  return (
    <div class="page-shell index-page">
      <PageMeta
        title="Writing"
        description="Essays on software, craft, games, and the work of making things."
        path="/blog"
      />
      <header class="page-header">
        <p class="eyebrow">Writing</p>
        <h1>Essays and field notes</h1>
        <p>Software, creative work, games, and whatever else stays interesting long enough.</p>
      </header>
      <PostList posts={current} />
      {archive.length > 0 && (
        <section class="archive" aria-labelledby="archive-heading">
          <header>
            <p class="eyebrow">Earlier work</p>
            <h2 id="archive-heading">Archive</h2>
            <p>Older writing preserved as artifacts from a different era of my work.</p>
          </header>
          <PostList posts={archive} compact />
        </section>
      )}
    </div>
  );
});
