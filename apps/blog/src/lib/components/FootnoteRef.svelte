<script lang="ts">
	interface Props {
		id: string | number;
	}

	let { id }: Props = $props();
</script>

<sup class="footnote-ref">
	<a href="#footnote-{id}" id="footnote-ref-{id}">{id}</a>
</sup>

<style>
	.footnote-ref {
		font-size: 0.75em;
		line-height: 1;
		vertical-align: super;
	}

	.footnote-ref a {
		color: var(--accent);
		text-decoration: none;
		padding: 0 0.1em;
		border-radius: 2px;
		transition: background-color 0.2s ease;
	}

	.footnote-ref a:hover {
		background-color: color-mix(in oklch, var(--accent) 15%, transparent);
	}
</style>
