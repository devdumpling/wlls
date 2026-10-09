// @ts-check
// <wlls-copilot>: a replay of GitHub Copilot's 2021 technical preview, for
// ```embed:copilot (src/content/embeds.odin). The fence is both the fallback
// and the script: its leading comment lines are typed out, and the rest is
// the ghost-text suggestion that follows. Lines reading `// alt+]` separate
// alternative suggestions, which Alt+] cycles like the real thing did.
//
// Tab accepts a suggestion only while the editor has focus and a suggestion
// is showing, so it never traps keyboard focus: Esc dismisses it, and once
// it's accepted or dismissed, Tab moves on as usual. Every key has a button.
//
// A plain custom element rather than a Rocket component: it reads no
// signals and the server never patches it, so Datastar would add nothing.

const NEXT = "// alt+]"
const TYPE_MS = 42
const THINK_MS = 700
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)")

const TOKENS =
  /(\/\/.*$)|("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')|\b(function|var|let|const|for|if|else|return|true|false)\b|\b(\d+)\b/gm
const TOKEN_CLASSES = ["comment", "string", "keyword", "number"]

/**
 * @param {number} ms
 * @param {AbortSignal} signal
 */
const sleep = (ms, signal) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms)
    signal.addEventListener("abort", () => {
      clearTimeout(timer)
      reject(signal.reason)
    })
  })

/**
 * @param {string} tag
 * @param {string} [className]
 * @param {string} [text]
 */
const make = (tag, className, text) => {
  const element = document.createElement(tag)
  if (className) element.className = className
  if (text) element.textContent = text
  return element
}

const button = () => {
  const element = document.createElement("button")
  element.type = "button"
  element.className = "copilot-key"
  return element
}

/** Highlighted code, the way the editor colors accepted text. */
/** @param {string} source */
const highlight = (source) => {
  const fragment = document.createDocumentFragment()
  let at = 0
  for (const match of source.matchAll(TOKENS)) {
    const index = match.index ?? 0
    if (index > at) fragment.append(source.slice(at, index))
    const kind = TOKEN_CLASSES[match.slice(1).findIndex((group) => group !== undefined)]
    fragment.append(make("span", `tok-${kind}`, match[0]))
    at = index + match[0].length
  }
  fragment.append(source.slice(at))
  return fragment
}

/** @param {string} text */
const parse = (text) => {
  const lines = text.replace(/\n+$/, "").split("\n")
  let promptEnd = 0
  while (promptEnd < lines.length && lines[promptEnd].trim().startsWith("//")) promptEnd++
  const suggestions = []
  let current = []
  for (const line of lines.slice(promptEnd)) {
    if (line.trim() === NEXT) {
      suggestions.push(current.join("\n").trim())
      current = []
    } else {
      current.push(line)
    }
  }
  suggestions.push(current.join("\n").trim())
  return { prompt: lines.slice(0, promptEnd).join("\n"), suggestions: suggestions.filter(Boolean) }
}

class Copilot extends HTMLElement {
  /** @type {AbortController | undefined} */
  #run
  /** @type {IntersectionObserver | undefined} */
  #watch
  #built = false

  connectedCallback() {
    if (this.#built) return
    const fallback = this.querySelector("pre")
    if (!fallback) return
    const { prompt, suggestions } = parse(fallback.textContent ?? "")
    if (!prompt || suggestions.length === 0) return
    this.#built = true

    const code = make("code")
    const surface = make("pre", "copilot-code")
    surface.tabIndex = 0
    surface.setAttribute("aria-label", "Copilot replay. When a suggestion shows, Tab accepts it and Alt+] shows the next.")
    surface.setAttribute("aria-keyshortcuts", "Tab Alt+BracketRight Escape")
    surface.append(code)
    const count = make("span", "copilot-count")
    const status = make("span", "copilot-status-text", "Copilot")
    const accept = button()
    accept.append(make("kbd", "", "Tab"), " accept")
    const next = button()
    next.append(make("kbd", "", "Alt"), make("kbd", "", "]"), " next")
    const replay = button()
    replay.textContent = "↺ replay"
    const live = make("p", "visually-hidden")
    live.setAttribute("aria-live", "polite")

    const editor = make("div", "copilot")
    const tab = make("div", "copilot-tabs")
    tab.append(make("span", "copilot-tab", "palindrome.js"))
    const bar = make("div", "copilot-status")
    bar.append(status, count)
    const keys = make("div", "copilot-keys")
    keys.append(accept, next, replay)
    editor.append(tab, surface, bar, keys, live)
    // Reserve the finished height, so the page doesn't jump as lines appear.
    const rows = prompt.split("\n").length + Math.max(...suggestions.map((s) => s.split("\n").length)) + 1
    editor.style.setProperty("--copilot-rows", String(rows))
    fallback.replaceWith(editor)

    /** @typedef {"idle" | "typing" | "thinking" | "suggesting" | "accepted" | "dismissed"} State */
    /** @type {State} */
    let state = "idle"
    let typed = ""
    let choice = 0

    const render = () => {
      editor.dataset.state = state
      code.replaceChildren()
      if (state === "typing" || state === "idle") {
        code.append(highlight(typed), make("span", "copilot-caret"))
      } else {
        code.append(highlight(prompt + "\n"))
        if (state === "accepted") {
          const accepted = make("span", "copilot-accepted")
          accepted.append(highlight(suggestions[choice]))
          code.append(accepted, make("span", "copilot-caret"))
        } else {
          code.append(make("span", "copilot-caret"))
          if (state === "suggesting") code.append(make("span", "copilot-ghost", suggestions[choice]))
        }
      }
      const showing = state === "suggesting"
      count.textContent = showing && suggestions.length > 1 ? `${choice + 1}/${suggestions.length}` : ""
      status.textContent = state === "thinking" ? "Copilot …" : "Copilot"
      accept.hidden = next.hidden = !(showing || state === "dismissed")
      accept.disabled = !showing
      next.disabled = suggestions.length < 2 && showing
      replay.hidden = !(state === "accepted" || state === "dismissed")
    }

    /** @param {string} message */
    const say = (message) => {
      live.textContent = message
    }

    const suggest = () => {
      state = "suggesting"
      render()
      say(`Suggestion ${choice + 1} of ${suggestions.length}. Tab accepts it.`)
    }

    const play = async () => {
      this.#run?.abort()
      const run = new AbortController()
      this.#run = run
      choice = 0
      typed = ""
      try {
        if (reducedMotion.matches) {
          typed = prompt
        } else {
          state = "typing"
          for (const character of prompt) {
            typed += character
            render()
            await sleep(TYPE_MS + Math.random() * 50, run.signal)
          }
          state = "thinking"
          render()
          await sleep(THINK_MS, run.signal)
        }
        suggest()
      } catch {
        // Replayed or disconnected mid-run; the next run renders afresh.
      }
    }

    const doAccept = () => {
      if (state !== "suggesting") return
      state = "accepted"
      render()
      say("Accepted.")
    }
    /** @param {number} step */
    const cycle = (step) => {
      if (state !== "suggesting" && state !== "dismissed") return
      if (state === "suggesting") choice = (choice + step + suggestions.length) % suggestions.length
      suggest()
    }

    surface.addEventListener("keydown", (event) => {
      if (event.key === "Tab" && !event.shiftKey && state === "suggesting") {
        event.preventDefault()
        doAccept()
      } else if (event.altKey && (event.code === "BracketRight" || event.code === "BracketLeft")) {
        event.preventDefault()
        cycle(event.code === "BracketRight" ? 1 : -1)
      } else if (event.key === "Escape" && state === "suggesting") {
        state = "dismissed"
        render()
        say("Suggestion dismissed.")
      }
    })
    accept.addEventListener("click", () => {
      doAccept()
      surface.focus()
    })
    next.addEventListener("click", () => cycle(1))
    replay.addEventListener("click", () => {
      play()
      surface.focus()
    })

    render()
    // Start when the editor is mostly in view, once.
    this.#watch = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return
        this.#watch?.disconnect()
        play()
      },
      { threshold: 0.6 },
    )
    this.#watch.observe(editor)
  }

  disconnectedCallback() {
    this.#run?.abort()
    this.#watch?.disconnect()
  }
}

customElements.define("wlls-copilot", Copilot)
