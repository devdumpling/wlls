import { PageMeta } from "@/components/PageMeta.tsx";
import { PostList } from "@/components/PostList.tsx";
import { getPosts } from "@/lib/content.ts";
import { define } from "@/utils.ts";

export default define.page(function Home() {
  const recentPosts = getPosts().filter((post) => !post.archive).slice(0, 6);

  return (
    <div class="page-shell home-page">
      <PageMeta path="/" />
      <header class="home-intro">
        <p class="eyebrow">Devon Wells</p>
        <h1>Software, craft, and the occasional detour.</h1>
        <p>
          I am a dad, principal engineer, and writer interested in how tools shape the people who
          use them. This is where I work through those ideas.
        </p>
      </header>
      <section class="writing-section" aria-labelledby="recent-writing">
        <div class="section-heading">
          <h2 id="recent-writing">Recent writing</h2>
          <a href="/blog">All writing</a>
        </div>
        <PostList posts={recentPosts} compact />
      </section>
    </div>
  );
});
