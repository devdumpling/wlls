// @ts-check
// <wlls-slow>: types its paragraph out at a human pace when it scrolls into
// view, for ```embed:slow (src/content/embeds.odin). It's the bookend to the
// Copilot replay: there, code appears all at once; here, one line takes its
// time. The paragraph keeps its markup and its space: each character is
// hidden, then shown in turn, so nothing reflows. Screen readers get the
// whole line at once from a hidden copy. With reduced motion, or without
// JavaScript, it's just the paragraph.

const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)")
const BASE_MS = 85
const PAUSE_AFTER = /[,.…!?]/
const PAUSE_MS = 420

/** @param {number} ms */
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

class Slow extends HTMLElement {
  /** @type {IntersectionObserver | undefined} */
  #watch

  connectedCallback() {
    const paragraph = this.querySelector("p")
    if (!paragraph || reducedMotion.matches || this.#watch) return

    // A copy for assistive technology; the animated one is hidden from it.
    const copy = /** @type {HTMLElement} */ (paragraph.cloneNode(true))
    copy.className = "visually-hidden"
    paragraph.setAttribute("aria-hidden", "true")
    this.append(copy)

    // Split every text node into one span per character, all hidden.
    /** @type {HTMLSpanElement[]} */
    const characters = []
    const walker = document.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT)
    /** @type {Text[]} */
    const texts = []
    while (walker.nextNode()) texts.push(/** @type {Text} */ (walker.currentNode))
    for (const text of texts) {
      const fragment = document.createDocumentFragment()
      for (const character of text.data) {
        const span = document.createElement("span")
        span.className = "slow-char"
        span.textContent = character
        fragment.append(span)
        characters.push(span)
      }
      text.replaceWith(fragment)
    }
    this.dataset.state = "waiting"

    this.#watch = new IntersectionObserver(
      async (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return
        this.#watch?.disconnect()
        this.dataset.state = "typing"
        /** @type {HTMLSpanElement | undefined} */
        let previous
        for (const span of characters) {
          previous?.classList.remove("is-caret")
          span.classList.add("is-shown", "is-caret")
          previous = span
          const pause = PAUSE_AFTER.test(span.textContent ?? "") ? PAUSE_MS : 0
          await sleep(BASE_MS + Math.random() * 70 + pause)
        }
        this.dataset.state = "done"
        await sleep(2400)
        previous?.classList.remove("is-caret")
      },
      { threshold: 1, rootMargin: "0px 0px -15% 0px" },
    )
    this.#watch.observe(paragraph)
  }

  disconnectedCallback() {
    this.#watch?.disconnect()
  }
}

customElements.define("wlls-slow", Slow)
