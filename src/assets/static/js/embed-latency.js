// @ts-check
// <wlls-latency>: a nod to Bret Victor's platformer in "Inventing on
// Principle", for ```embed:latency (src/content/embeds.odin). A smith runs,
// jumps, and tries to reach a coin on a ledge. One slider tunes the jump;
// too weak hits the wall, too strong bonks the overhang. The dotted arc
// shows where the current jump goes, so tuning is a conversation with the
// world, until the feedback delay control makes every change take a while
// to show.
//
// Canvas 2D, a fixed 120 Hz physics step, and colors read from the theme.
// It runs only while in view, and with reduced motion it waits for "run".

const WORLD = { width: 320, height: 180, ground: 160 };
const PLAYER = { width: 10, height: 14, start: 14 };
const RUN_SPEED = 90;
const GRAVITY = 900;
const TAKEOFF = 112;
// Tuned by simulation: jumps of 379 to 423 land on the ledge. Weaker ones
// fall short or hit the wall, stronger ones bonk the overhang. The default
// hits the wall.
const PILLAR = { x: 176, top: 96 };
const OVERHANG = { x0: 136, x1: 210, bottom: 48 };
const COIN = { x: 268, y: 84, radius: 5 };
const JUMP = { min: 200, max: 600, initial: 300 };
const DELAYS = [0, 250, 2000];
const STEP = 1 / 120;
const PAUSE = 0.8; // seconds to rest after a try before the next one
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
const darkScheme = matchMedia("(prefers-color-scheme: dark)");

let instances = 0;

/**
 * @param {string} tag
 * @param {string} [className]
 * @param {string} [text]
 */
const make = (tag, className, text) => {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text) element.textContent = text;
  return element;
};

/** @typedef {"run" | "air" | "fall" | "ledge" | "rest"} Phase */
/** @typedef {{ x: number, y: number, vx: number, vy: number, phase: Phase, outcome: string }} Smith */

/** @returns {Smith} */
const spawn = () => ({
  x: PLAYER.start,
  y: WORLD.ground - PLAYER.height,
  vx: RUN_SPEED,
  vy: 0,
  phase: "run",
  outcome: "",
});

/**
 * One physics step. Returns true when the try is over.
 * @param {Smith} body
 * @param {number} jump
 */
const step = (body, jump) => {
  if (body.phase === "run" && body.x >= TAKEOFF) {
    body.phase = "air";
    body.vy = -jump;
  }
  const previousBottom = body.y + PLAYER.height;
  body.x += body.vx * STEP;
  if (body.phase === "air" || body.phase === "fall") {
    body.vy += GRAVITY * STEP;
    body.y += body.vy * STEP;
  }
  const right = body.x + PLAYER.width;
  const bottom = body.y + PLAYER.height;
  if (
    body.phase === "air" &&
    body.vy < 0 &&
    body.y < OVERHANG.bottom &&
    right > OVERHANG.x0 &&
    body.x < OVERHANG.x1
  ) {
    // Knocked back, so a bonk never falls onto the ledge.
    body.y = OVERHANG.bottom;
    body.vy = 0;
    body.vx = -RUN_SPEED / 3;
    body.phase = "fall";
    body.outcome = "bonk";
  }
  if (body.phase !== "ledge" && right > PILLAR.x && bottom > PILLAR.top) {
    if (previousBottom <= PILLAR.top) {
      body.y = PILLAR.top - PLAYER.height;
      body.vy = 0;
      body.vx = RUN_SPEED;
      body.phase = "ledge";
    } else {
      body.x = PILLAR.x - PLAYER.width;
      body.vx = 0;
      body.phase = "fall";
      body.outcome ||= "wall";
    }
  }
  if ((body.phase === "air" || body.phase === "fall") && body.y + PLAYER.height >= WORLD.ground) {
    body.y = WORLD.ground - PLAYER.height;
    body.outcome ||= "short";
    return true;
  }
  if (body.phase === "ledge" && body.x + PLAYER.width >= COIN.x - COIN.radius) {
    body.outcome = "coin";
    return true;
  }
  return false;
};

/**
 * Where a jump goes from takeoff: a point every few steps until it ends.
 * @param {number} jump
 */
const arc = (jump) => {
  const body = spawn();
  body.x = TAKEOFF;
  const points = [];
  for (let i = 0; i < 600; i++) {
    const over = step(body, jump);
    if (i % 5 === 0) points.push([body.x + PLAYER.width / 2, body.y + PLAYER.height]);
    if (over || body.phase === "ledge") break;
  }
  return points;
};

/**
 * How a try with this jump ends, played from the start like the real one.
 * @param {number} jump
 */
const outcome = (jump) => {
  const body = spawn();
  for (let i = 0; i < 1000; i++) if (step(body, jump)) break;
  return body.outcome;
};

class Latency extends HTMLElement {
  #built = false;
  /** @type {(() => void) | undefined} */
  #stop;

  connectedCallback() {
    if (this.#built) return;
    this.#built = true;
    const id = ++instances;

    const canvas = /** @type {HTMLCanvasElement} */ (make("canvas", "latency-world"));
    canvas.setAttribute("role", "img");
    const context = canvas.getContext("2d");
    if (!context) return;

    const slider = /** @type {HTMLInputElement} */ (make("input"));
    slider.type = "range";
    slider.min = String(JUMP.min);
    slider.max = String(JUMP.max);
    slider.value = String(JUMP.initial);
    slider.id = `latency-jump-${id}`;
    const jumpLabel = make("label", "latency-label", "jump");
    jumpLabel.setAttribute("for", slider.id);
    const jumpValue = make("output", "latency-value", slider.value);
    jumpValue.setAttribute("for", slider.id);

    const delays = make("fieldset", "latency-delays");
    delays.append(make("legend", "latency-label", "feedback delay"));
    for (const delay of DELAYS) {
      const option = make("label", "latency-delay");
      const radio = /** @type {HTMLInputElement} */ (make("input"));
      radio.type = "radio";
      radio.name = `latency-delay-${id}`;
      radio.value = String(delay);
      radio.checked = delay === 0;
      option.append(radio, make("span", "", delay < 1000 ? `${delay} ms` : `${delay / 1000} s`));
      delays.append(option);
    }

    const pending = make("span", "latency-pending", "applying…");
    pending.hidden = true;
    const runButton = make("button", "latency-run", "▶ run");
    runButton.setAttribute("type", "button");

    const jumpRow = make("div", "latency-jump");
    jumpRow.append(jumpLabel, slider, jumpValue);
    // While a delayed change is on its way, say so beside the delays.
    delays.append(pending, runButton);
    const controls = make("div", "latency-controls");
    controls.append(jumpRow, delays);
    const caption = make(
      "p",
      "latency-caption",
      "Tune the jump until the smith gets the coin. Then try it with a 2 s delay.",
    );

    // The theme's colors, resolved: canvas can't read var(--ink) itself.
    const swatches = ["ink", "soft", "accent", "paper"].map((name) => {
      const swatch = make("span", "latency-swatch");
      swatch.dataset.swatch = name;
      swatch.hidden = true;
      return swatch;
    });
    const game = make("div", "latency");
    game.append(canvas, controls, caption, ...swatches);
    this.replaceChildren(game);

    /** @type {Record<string, string>} */
    let colors = {};
    let font = "";
    const readColors = () => {
      colors = Object.fromEntries(
        swatches.map((swatch) => [swatch.dataset.swatch ?? "", getComputedStyle(swatch).color]),
      );
      // The labels' mono, so text in the world matches the controls.
      font = `7px ${getComputedStyle(jumpLabel).fontFamily}`;
    };
    readColors();

    // The world as the player sees it uses the applied jump, which trails
    // the slider by the chosen delay.
    let applied = JUMP.initial;
    let delay = 0;
    /** @type {Set<number>} */
    const timers = new Set();
    let body = spawn();
    let resting = 0;
    let collected = 0;
    let trail = arc(applied);
    let running = false;
    let frame = 0;
    let last = 0;
    let backlog = 0;

    const describe = () => {
      const result = {
        short: "falls short of the wall",
        wall: "hits the wall",
        coin: "lands on the ledge",
        bonk: "bonks the overhang",
      }[outcome(applied)];
      canvas.setAttribute(
        "aria-label",
        `A smith jumps toward a coin on a ledge. Jump ${applied}: ${result}.`,
      );
    };
    describe();

    const apply = (/** @type {number} */ value) => {
      applied = value;
      trail = arc(applied);
      describe();
      if (!running) draw();
    };
    slider.addEventListener("input", () => {
      const value = Number(slider.value);
      jumpValue.textContent = slider.value;
      if (delay === 0) return apply(value);
      pending.hidden = false;
      const timer = window.setTimeout(() => {
        timers.delete(timer);
        apply(value);
        pending.hidden = timers.size === 0;
      }, delay);
      timers.add(timer);
    });
    // A new delay drops changes still on their way and applies the slider
    // now, so an older change can never land after a newer one.
    delays.addEventListener("change", (event) => {
      delay = Number(/** @type {HTMLInputElement} */ (event.target).value);
      for (const timer of timers) clearTimeout(timer);
      timers.clear();
      pending.hidden = true;
      if (applied !== Number(slider.value)) apply(Number(slider.value));
    });

    let scale = 1;
    const resize = () => {
      const ratio = window.devicePixelRatio || 1;
      const width = canvas.clientWidth;
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round((width * WORLD.height * ratio) / WORLD.width);
      scale = canvas.width / WORLD.width;
      draw();
    };

    const draw = () => {
      const c = context;
      c.setTransform(scale, 0, 0, scale, 0, 0);
      c.clearRect(0, 0, WORLD.width, WORLD.height);
      c.lineWidth = 1 / scale;
      // Ground, pillar, and overhang: ink outlines over a faint wash.
      c.strokeStyle = colors.ink;
      c.fillStyle = colors.soft;
      c.globalAlpha = 0.18;
      c.fillRect(PILLAR.x, PILLAR.top, WORLD.width - PILLAR.x, WORLD.ground - PILLAR.top);
      c.fillRect(OVERHANG.x0, 0, OVERHANG.x1 - OVERHANG.x0, OVERHANG.bottom);
      c.globalAlpha = 1;
      c.lineWidth = 1.25;
      c.strokeRect(PILLAR.x, PILLAR.top, WORLD.width - PILLAR.x + 2, WORLD.ground - PILLAR.top);
      c.strokeRect(OVERHANG.x0, -2, OVERHANG.x1 - OVERHANG.x0, OVERHANG.bottom + 2);
      c.beginPath();
      c.moveTo(0, WORLD.ground);
      c.lineTo(WORLD.width, WORLD.ground);
      c.stroke();
      // The coin, until it's collected on this try.
      if (body.outcome !== "coin") {
        c.fillStyle = colors.accent;
        c.beginPath();
        c.arc(COIN.x, COIN.y, COIN.radius, 0, Math.PI * 2);
        c.fill();
      }
      // Where the applied jump goes.
      c.fillStyle = colors.accent;
      for (const [x, y] of trail) c.fillRect(x - 0.9, y - 0.9, 1.8, 1.8);
      // The smith.
      c.fillStyle = colors.ink;
      c.fillRect(body.x, body.y, PLAYER.width, PLAYER.height);
      c.font = font;
      c.fillText(`coins ${collected}`, 6, 12);
      // What happened, kept inside the world's right edge. A coin earns a
      // second nod to Streets 1:12.
      const message = { coin: "my insane pace", wall: "oof", bonk: "bonk", short: "oof" }[
        body.outcome
      ];
      if (message && body.phase !== "air") {
        const x = Math.min(body.x - 2, WORLD.width - c.measureText(message).width - 4);
        c.fillText(message, x, body.y - 4);
      }
    };

    const tick = (/** @type {number} */ now) => {
      backlog += Math.min((now - last) / 1000, 0.1);
      last = now;
      while (backlog >= STEP) {
        backlog -= STEP;
        if (resting > 0) {
          resting -= STEP;
          if (resting <= 0) {
            if (reducedMotion.matches) {
              running = false;
              body = spawn();
              draw();
              return;
            }
            body = spawn();
          }
        } else if (step(body, applied)) {
          resting = PAUSE;
          if (body.outcome === "coin") collected++;
        }
      }
      draw();
      frame = requestAnimationFrame(tick);
    };
    const start = () => {
      if (running) return;
      running = true;
      last = performance.now();
      frame = requestAnimationFrame(tick);
    };
    const stop = () => {
      running = false;
      cancelAnimationFrame(frame);
    };
    runButton.addEventListener("click", () => {
      body = spawn();
      resting = 0;
      start();
    });

    // Run while in view (and, with reduced motion, only when asked).
    const view = new IntersectionObserver((entries) => {
      const visible = entries.some((entry) => entry.isIntersecting);
      if (visible && !reducedMotion.matches) start();
      else if (!visible) stop();
    });
    view.observe(canvas);
    const size = new ResizeObserver(resize);
    size.observe(canvas);
    const recolor = () => {
      readColors();
      draw();
    };
    darkScheme.addEventListener("change", recolor);

    this.#stop = () => {
      stop();
      view.disconnect();
      size.disconnect();
      darkScheme.removeEventListener("change", recolor);
      for (const timer of timers) clearTimeout(timer);
    };
  }

  disconnectedCallback() {
    this.#stop?.();
  }
}

customElements.define("wlls-latency", Latency);
