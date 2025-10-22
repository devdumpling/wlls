<script lang="ts">
import FeaturedPosts from "$lib/components/FeaturedPosts.svelte";
import type { PageProps } from "./$types";

let { data }: PageProps = $props();
</script>

<FeaturedPosts posts={data.posts} />
