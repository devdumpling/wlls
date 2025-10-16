<script lang="ts">
// This will be enhanced later to load posts dynamically
const posts = [
	{
		slug: "hello-world",
		title: "Hello World",
		date: "2025-10-15",
		description: "Testing mdsvex with SvelteKit",
	},
];
</script>

<h1>Blog</h1>
<p>Welcome to the blog. Here are the latest posts:</p>

<ul>
  {#each posts as post}
    <li>
      <a href="/blog/{post.slug}">
        <h2>{post.title}</h2>
        <time>{post.date}</time>
        <p>{post.description}</p>
      </a>
    </li>
  {/each}
</ul>
