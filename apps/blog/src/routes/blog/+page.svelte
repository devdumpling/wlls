<script lang="ts">
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<h1>Blog</h1>
<p>Welcome to the blog. Here are the latest posts:</p>

<ul>
  {#each data.posts as post (post.slug)}
    <li>
      <a href="/blog/{post.slug}">
        <h2>{post.title}</h2>
        <time>{post.date}</time>
        <p>{post.description}</p>
      </a>
    </li>
  {/each}
</ul>
