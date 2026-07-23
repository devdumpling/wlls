import { PageMeta } from "@/components/PageMeta.tsx";
import { PostList } from "@/components/PostList.tsx";
import { getPosts } from "@/lib/content.ts";
import { define } from "@/utils.ts";

export default define.page(function Home() {
  return (
    <div class="page-shell home-page">
      <PageMeta path="/" />
      <h1 class="visually-hidden">Writing</h1>
      <PostList posts={getPosts()} />
    </div>
  );
});
