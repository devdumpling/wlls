// @ts-check
// <wlls-ping>: Steve's readout, for ```embed:ping (src/content/embeds.odin).
// One line with this page's real latency, measured in the reader's browser
// how long the server took to start answering the page, and a round trip to
// /healthz. Nothing without JavaScript.

const SAMPLES = 3;

/** Time from sending the page request to its first byte, in ms. */
const pageLatency = () => {
  const [navigation] = /** @type {PerformanceNavigationTiming[]} */ (
    performance.getEntriesByType("navigation")
  );
  if (!navigation || navigation.responseStart <= 0) return null;
  return navigation.responseStart - (navigation.requestStart || navigation.startTime);
};

/** The median of a few sequential round trips to the server, in ms. */
const roundTrip = async () => {
  const times = [];
  for (let i = 0; i < SAMPLES; i++) {
    const started = performance.now();
    const response = await fetch("/healthz", { cache: "no-store" });
    await response.arrayBuffer();
    times.push(performance.now() - started);
  }
  return times.sort((a, b) => a - b)[Math.floor(times.length / 2)];
};

/** @param {number} ms */
const format = (ms) => `${Math.max(1, Math.round(ms))} ms`;

/** @param {string} page @param {string} trip */
const readout = (page, trip) =>
  `Steve's readout: this page reached you in ${page} and a round trip to the server takes ${trip}.`;

class Ping extends HTMLElement {
  #line = document.createElement("p");
  #watch = new IntersectionObserver((entries) => {
    if (!entries.some((entry) => entry.isIntersecting)) return;
    this.#watch.disconnect();
    this.#measure();
  });

  // The line is written at once, with blanks, so it already has its space
  // when the numbers arrive, filling them in doesn't move the page.
  connectedCallback() {
    if (!this.#line.isConnected) {
      this.#line.className = "ping";
      this.#line.textContent = readout("… ms", "… ms");
      this.replaceChildren(this.#line);
    }
    this.#watch.observe(this);
  }

  disconnectedCallback() {
    this.#watch.disconnect();
  }

  async #measure() {
    const page = pageLatency();
    let trip = null;
    try {
      trip = await roundTrip();
    } catch {
      // Offline, or the request was blocked: report what we have.
    }
    this.#line.textContent = readout(
      page === null ? "? ms" : format(page),
      trip === null ? "? ms" : format(trip),
    );
  }
}

customElements.define("wlls-ping", Ping);
