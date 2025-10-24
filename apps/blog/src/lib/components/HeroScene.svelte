<script lang="ts">
import { T, useTask } from "@threlte/core";
import * as THREE from "three";

let rotation = $state(0);
let time = $state(0);

useTask((delta) => {
	rotation += delta * 0.15;
	time += delta;
});

// Particle stream configuration - slower, more subtle
const streamCount = 20;
const streams = Array.from({ length: streamCount }, (_, i) => ({
	angle: (i / streamCount) * Math.PI * 2,
	radius: 5 + Math.random() * 3,
	speed: 0.08 + Math.random() * 0.05, // Much slower
	offset: Math.random() * Math.PI * 2,
	color: i % 3 === 0 ? "#9ccfd8" : i % 3 === 1 ? "#c4a7e7" : "#eb6f92",
}));
</script>

<!-- Camera -->
<T.PerspectiveCamera makeDefault position={[0, 0, 12]} fov={50} />

<!-- Lighting -->
<T.AmbientLight intensity={0.5} />
<T.DirectionalLight position={[5, 5, 5]} intensity={0.4} />

<!-- Nested icosahedron - the d20! -->
<T.Mesh rotation.y={-rotation} rotation.z={rotation * 0.4} position={[0, 0, -2]}>
	<T.IcosahedronGeometry args={[1.2, 0]} />
	<T.MeshStandardMaterial
		color="#f6c177"
		wireframe={true}
		transparent={true}
		opacity={0.3}
	/>
</T.Mesh>

<!-- Orbiting tetrahedron - d4 -->
<T.Mesh
	rotation.y={rotation * 2}
	rotation.x={rotation}
	position={[Math.cos(time * 0.3) * 4, Math.sin(time * 0.2) * 2, -3]}>
	<T.TetrahedronGeometry args={[0.6, 0]} />
	<T.MeshStandardMaterial
		color="#c4a7e7"
		wireframe={true}
		transparent={true}
		opacity={0.2}
	/>
</T.Mesh>

<!-- Small octahedron - d8 -->
<T.Mesh rotation.y={-rotation * 0.7} rotation.x={rotation * 0.5} position={[5, -2, -5]}>
	<T.OctahedronGeometry args={[0.8, 0]} />
	<T.MeshStandardMaterial
		color="#9ccfd8"
		wireframe={true}
		transparent={true}
		opacity={0.15}
	/>
</T.Mesh>

<!-- Flowing particle streams -->
{#each streams as stream, i}
	{@const x = Math.cos(stream.angle + time * stream.speed) * stream.radius}
	{@const y = Math.sin(time * 0.5 + stream.offset) * 3}
	{@const z = Math.sin(stream.angle + time * stream.speed) * stream.radius - 5}

	<T.Mesh position={[x, y, z]}>
		<T.SphereGeometry args={[0.04, 8, 8]} />
		<T.MeshStandardMaterial
			color={stream.color}
			transparent={true}
			opacity={0.5}
			emissive={stream.color}
			emissiveIntensity={0.3}
		/>
	</T.Mesh>
{/each}

<!-- Abstract connecting lines / branches -->
{#each Array(6) as _, i}
	{@const angle = (i / 6) * Math.PI * 2 + time * 0.1}
	{@const x = Math.cos(angle) * 4}
	{@const z = Math.sin(angle) * 4 - 4}

	<T.Mesh position={[x, 0, z]} rotation.z={angle}>
		<T.CylinderGeometry args={[0.02, 0.02, 3, 8]} />
		<T.MeshStandardMaterial
			color="#f6c177"
			transparent={true}
			opacity={0.15}
		/>
	</T.Mesh>
{/each}
