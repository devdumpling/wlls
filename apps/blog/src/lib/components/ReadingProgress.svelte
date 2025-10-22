<script>
	import { onMount } from 'svelte';

	let progress = $state(0);

	onMount(() => {
		const handleScroll = () => {
			const windowHeight = window.innerHeight;
			const documentHeight = document.documentElement.scrollHeight;
			const scrollTop = window.scrollY;
			const scrollProgress = (scrollTop / (documentHeight - windowHeight)) * 100;
			progress = Math.min(scrollProgress, 100);
		};

		window.addEventListener('scroll', handleScroll, { passive: true });
		return () => window.removeEventListener('scroll', handleScroll);
	});
</script>

<div class="reading-progress">
	<div class="progress-bar" style="width: {progress}%"></div>
</div>

<style>
	.reading-progress {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		height: 2px;
		background: var(--border);
		z-index: 100;
	}

	.progress-bar {
		height: 100%;
		background: var(--accent);
		transition: width 0.15s ease;
	}
</style>
