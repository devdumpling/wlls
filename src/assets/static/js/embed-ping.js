// @ts-check
// <wlls-ping>: Steve's readout, for ```embed:ping (src/content/embeds.odin).
// One line with this page's real latency, measured in the reader's browser:
// how long the server took to start answering the page, and a round trip to
// /healthz. Nothing without JavaScript; it's a garnish.

const SAMPLES = 3

/** Time from sending the page request to its first byte, in ms. */
const pageLatency = () => {
  const [navigation] = /** @type {PerformanceNavigationTiming[]} */ (
    performance.getEntriesByType("navigation")
  )
  if (!navigation || navigation.responseStart <= 0) return null
  return navigation.responseStart - (navigation.requestStart || navigation.startTime)
}

/** The median of a few sequential round trips to the server, in ms. */
const roundTrip = async () => {
  const times = []
  for (let i = 0; i < SAMPLES; i++) {
    const started = performance.now()
    const response = await fetch("/healthz", { cache: "no-store" })
    await response.arrayBuffer()
    times.push(performance.now() - started)
  }
  return times.sort((a, b) => a - b)[Math.floor(times.length / 2)]
}

/** @param {number} ms */
const format = (ms) => `${Math.max(1, Math.round(ms))} ms`

class Ping extends HTMLElement {
  #watch = new IntersectionObserver((entries) => {
    if (!entries.some((entry) => entry.isIntersecting)) return
    this.#watch.disconnect()
    this.#measure()
  })

  connectedCallback() {
    this.#watch.observe(this)
  }

  disconnectedCallback() {
    this.#watch.disconnect()
  }

  async #measure() {
    const line = document.createElement("p")
    line.className = "ping"
    const page = pageLatency()
    let trip = null
    try {
      trip = await roundTrip()
    } catch {
      // Offline, or the request was blocked: report what we have.
    }
    if (page === null && trip === null) return
    const parts = ["Steve's readout:"]
    if (page !== null) parts.push(`this page reached you in ${format(page)}`)
    if (trip !== null) parts.push(`${page !== null ? "and " : ""}a round trip to the server takes ${format(trip)}`)
    line.textContent = `${parts.join(" ")}.`
    this.replaceChildren(line)
  }
}

customElements.define("wlls-ping", Ping)
