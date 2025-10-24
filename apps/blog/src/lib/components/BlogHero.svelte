<script lang="ts">
import { onMount } from 'svelte';

type Cell = {
	x: number;
	y: number;
	alive: boolean;
	nextAlive: boolean;
	opacity: number;
	scale: number;
	baseOpacity: number; // Each cell has its own max opacity
	stableFor: number; // How many ticks this cell has remained unchanged
	color: string; // Color of the cell
};

let canvas: HTMLCanvasElement;
let ctx: CanvasRenderingContext2D;
let cells: Cell[][] = [];
let animationFrame: number;

const GRID_SIZE = 30; // Cells per row/column
const CELL_SIZE = 8; // Visual size of each cell
const CONNECTION_DISTANCE = 120; // Max distance to draw lines
const TICK_RATE = 800; // ms between GoL updates
const STABLE_THRESHOLD = 3; // Ticks before cell considered stable
const STAGNATION_CHECK_COUNT = 5; // Check alive count stability

// Colors (Rose Pine inspired)
const ACTIVE_COLOR = 'oklch(0.7 0.18 45)'; // Default accent
const STABLE_COLOR_1 = 'oklch(0.75 0.1 320)'; // Lavender
const STABLE_COLOR_2 = 'oklch(0.72 0.12 25)'; // Salmon

// Stagnation detection
let aliveCounts: number[] = [];
let populationHistory: number[] = [];

onMount(() => {
	ctx = canvas.getContext('2d')!;
	resizeCanvas();
	initializeCells();

	let lastTick = Date.now();

	function animate() {
		const now = Date.now();

		// Update Game of Life
		if (now - lastTick > TICK_RATE) {
			updateGameOfLife();
			lastTick = now;
		}

		// Animate cell opacity/scale
		animateCells();

		// Render
		render();

		animationFrame = requestAnimationFrame(animate);
	}

	animate();

	window.addEventListener('resize', resizeCanvas);

	return () => {
		cancelAnimationFrame(animationFrame);
		window.removeEventListener('resize', resizeCanvas);
	};
});

function resizeCanvas() {
	canvas.width = window.innerWidth;
	canvas.height = window.innerHeight;
}

function initializeCells() {
	const width = canvas.width;
	const height = canvas.height;
	const cellSpacingX = width / GRID_SIZE;
	const cellSpacingY = height / GRID_SIZE;

	cells = [];

	for (let row = 0; row < GRID_SIZE; row++) {
		cells[row] = [];
		for (let col = 0; col < GRID_SIZE; col++) {
			// Add some randomness to position for organic feel
			const randomX = (Math.random() - 0.5) * cellSpacingX * 0.3;
			const randomY = (Math.random() - 0.5) * cellSpacingY * 0.3;

			const alive = Math.random() < 0.12; // 12% initial alive chance (reduced from 25%)

			// Each cell gets a random base opacity between 0.3 and 1.0
			const baseOpacity = 0.3 + Math.random() * 0.7;

			cells[row][col] = {
				x: col * cellSpacingX + cellSpacingX / 2 + randomX,
				y: row * cellSpacingY + cellSpacingY / 2 + randomY,
				alive,
				nextAlive: alive,
				opacity: alive ? baseOpacity : 0,
				scale: alive ? 1 : 0,
				baseOpacity,
				stableFor: 0,
				color: ACTIVE_COLOR,
			};
		}
	}
}

function updateGameOfLife() {
	// Calculate next state for each cell
	for (let row = 0; row < GRID_SIZE; row++) {
		for (let col = 0; col < GRID_SIZE; col++) {
			const cell = cells[row][col];
			const neighbors = countNeighbors(row, col);

			// Conway's Game of Life rules
			if (cell.alive) {
				cell.nextAlive = neighbors === 2 || neighbors === 3;
			} else {
				cell.nextAlive = neighbors === 3;
			}
		}
	}

	// Apply next state and track stability
	let aliveCount = 0;
	for (let row = 0; row < GRID_SIZE; row++) {
		for (let col = 0; col < GRID_SIZE; col++) {
			const cell = cells[row][col];
			const wasAlive = cell.alive;
			cell.alive = cell.nextAlive;

			if (cell.alive) aliveCount++;

			// Track stability
			if (cell.alive === wasAlive) {
				cell.stableFor++;

				// Change color based on stability
				if (cell.stableFor >= STABLE_THRESHOLD) {
					// Alternate between lavender and salmon for variety
					cell.color = (row + col) % 2 === 0 ? STABLE_COLOR_1 : STABLE_COLOR_2;
				}
			} else {
				cell.stableFor = 0;
				cell.color = ACTIVE_COLOR;
			}
		}
	}

	// Track population for stagnation detection
	populationHistory.push(aliveCount);
	if (populationHistory.length > STAGNATION_CHECK_COUNT) {
		populationHistory.shift();
	}

	// Check for stagnation (same population for N ticks)
	if (populationHistory.length === STAGNATION_CHECK_COUNT) {
		const allSame = populationHistory.every(count => count === populationHistory[0]);
		if (allSame || aliveCount === 0) {
			// Reset the simulation
			setTimeout(() => {
				initializeCells();
				populationHistory = [];
			}, 2000); // Wait 2 seconds before reset
		}
	}
}

function countNeighbors(row: number, col: number): number {
	let count = 0;

	for (let dr = -1; dr <= 1; dr++) {
		for (let dc = -1; dc <= 1; dc++) {
			if (dr === 0 && dc === 0) continue;

			const newRow = row + dr;
			const newCol = col + dc;

			if (newRow >= 0 && newRow < GRID_SIZE && newCol >= 0 && newCol < GRID_SIZE) {
				if (cells[newRow][newCol].alive) {
					count++;
				}
			}
		}
	}

	return count;
}

function animateCells() {
	for (let row = 0; row < GRID_SIZE; row++) {
		for (let col = 0; col < GRID_SIZE; col++) {
			const cell = cells[row][col];
			// Target opacity is the cell's unique base opacity when alive, 0 when dead
			const targetOpacity = cell.alive ? cell.baseOpacity : 0;
			const targetScale = cell.alive ? 1 : 0;

			// Smooth interpolation
			cell.opacity += (targetOpacity - cell.opacity) * 0.1;
			cell.scale += (targetScale - cell.scale) * 0.1;
		}
	}
}

function render() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);

	// Draw connections first (behind cells)
	ctx.lineWidth = 1;

	for (let row = 0; row < GRID_SIZE; row++) {
		for (let col = 0; col < GRID_SIZE; col++) {
			const cell = cells[row][col];
			if (cell.opacity < 0.1) continue;

			// Draw lines to nearby living cells
			for (let r2 = row - 2; r2 <= row + 2; r2++) {
				for (let c2 = col - 2; c2 <= col + 2; c2++) {
					if (r2 === row && c2 === col) continue;
					if (r2 < 0 || r2 >= GRID_SIZE || c2 < 0 || c2 >= GRID_SIZE) continue;

					const other = cells[r2][c2];
					if (other.opacity < 0.1) continue;

					const dist = Math.hypot(cell.x - other.x, cell.y - other.y);
					if (dist < CONNECTION_DISTANCE) {
						const opacity = Math.min(cell.opacity, other.opacity) * (1 - dist / CONNECTION_DISTANCE) * 0.15;

						// Use the cell's color for the line
						ctx.strokeStyle = cell.color;
						ctx.globalAlpha = opacity;
						ctx.beginPath();
						ctx.moveTo(cell.x, cell.y);
						ctx.lineTo(other.x, other.y);
						ctx.stroke();
					}
				}
			}
		}
	}

	// Draw cells
	ctx.globalAlpha = 1;

	for (let row = 0; row < GRID_SIZE; row++) {
		for (let col = 0; col < GRID_SIZE; col++) {
			const cell = cells[row][col];
			if (cell.opacity < 0.01) continue;

			// Use cell's color
			ctx.fillStyle = cell.color;
			ctx.globalAlpha = cell.opacity * 0.6;
			ctx.beginPath();
			ctx.arc(cell.x, cell.y, CELL_SIZE * cell.scale, 0, Math.PI * 2);
			ctx.fill();
		}
	}

	ctx.globalAlpha = 1;
}
</script>

<section class="hero">
	<canvas bind:this={canvas} class="constellation-canvas"></canvas>

	<div class="hero-content">
		<h1>Dev Wells</h1>
		<p class="tagline">
			Dad, engineer, sometimes writer,
			crafting elegant interfaces, exploring fantasy realms, and
			building worlds through code and story.
		</p>
	</div>
</section>

<style>
	.hero {
		position: relative;
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 5rem 1.5rem;
		overflow: hidden;
	}

	.constellation-canvas {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.hero-content {
		max-width: 56rem;
		margin: 0 auto;
		text-align: center;
		position: relative;
		z-index: 10;
	}

	h1 {
		font-size: clamp(3rem, 10vw, 6rem);
		font-weight: 300;
		letter-spacing: -0.03em;
		margin: 0 0 2rem 0;
		line-height: 1.1;
	}

	.tagline {
		font-size: clamp(1.125rem, 2.5vw, 1.5rem);
		color: var(--muted-foreground);
		font-weight: 300;
		line-height: 1.6;
		max-width: 42rem;
		margin: 0 auto;
	}

	@media (min-width: 768px) {
		h1 {
			font-size: clamp(4rem, 10vw, 8rem);
		}
	}
</style>
