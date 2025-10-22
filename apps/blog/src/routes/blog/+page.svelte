<script lang="ts">
	import type { PageProps } from './$types';
	import FeaturedPosts from '$lib/components/FeaturedPosts.svelte';

	let { data }: PageProps = $props();
</script>

<FeaturedPosts posts={data.posts} />
