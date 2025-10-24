<script lang="ts">
import { Canvas } from "@threlte/core";
import Scene from "./ThrelteScene.svelte";
</script>

<div class="threlte-container">
	<Canvas>
		<Scene />
	</Canvas>
</div>

<style>
	.threlte-container {
		width: 100%;
		height: 400px;
		border-radius: 0.5rem;
		overflow: hidden;
		background: radial-gradient(
			circle at 50% 50%,
			hsl(220 14% 20%),
			hsl(220 20% 10%)
		);
	}
</style>
