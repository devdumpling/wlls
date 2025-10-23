<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import { OrbitControls } from '@threlte/extras';

	let rotation = 0;

	useTask((delta) => {
		rotation += delta * 0.3;
	});
</script>

<!-- Camera -->
<T.PerspectiveCamera makeDefault position={[5, 5, 5]} fov={50}>
	<OrbitControls
		enableDamping
		autoRotate
		autoRotateSpeed={0.5}
		enableZoom={false}
	/>
</T.PerspectiveCamera>

<!-- Lighting -->
<T.AmbientLight intensity={0.4} />
<T.DirectionalLight
	position={[10, 10, 5]}
	intensity={1.5}
	castShadow
/>

<!-- Rotating geometry -->
<T.Mesh rotation.y={rotation} position={[0, 0, 0]}>
	<T.IcosahedronGeometry args={[1.5, 1]} />
	<T.MeshStandardMaterial
		color="#e0def4"
		wireframe={true}
		emissive="#31748f"
		emissiveIntensity={0.3}
	/>
</T.Mesh>

<!-- Smaller accent geometry -->
<T.Mesh rotation.y={-rotation * 1.5} position={[0, 0, 0]}>
	<T.IcosahedronGeometry args={[1, 0]} />
	<T.MeshStandardMaterial
		color="#9ccfd8"
		metalness={0.8}
		roughness={0.2}
	/>
</T.Mesh>
