// @ts-check
// <wlls-terminal>: client behavior for the server-driven terminal. The server
// renders the log and prompt and answers each command with SSE patches; this
// component only adds what a browser must own: focus, command history on ↑/↓
// (kept across pages), keeping the newest output in view, and the `/` shortcut.
// It lives in a <dialog> sheet that the breadcrumb row's trigger opens. The
// sheet follows a local `open` signal, so `exit` closes it without a round trip.
// Same fingerprinted directory as this file, so this resolves to the exact URL
// the page already loaded: one module instance, and no inline import map.
import { rocket } from "./datastar-rocket.js"

const HISTORY_KEY = "wlls:terminal-history"
const HISTORY_LIMIT = 50

// For whoever opens the console: the Doors of Durin, and a hint that this
// site has a door of its own. The answer is a hidden terminal command
// (src/app/route_terminal.odin).
console.log(
  "%cSpeak, friend, and enter.%c\n\nThere's a terminal behind / on every page.\nThe password is the one Gandalf took far too long to find.",
  "font: 600 16px/1.6 Georgia, serif; color: #8c6bff",
  "font: 12px/1.6 ui-monospace, Menlo, monospace; color: inherit",
)

/** @returns {string[]} */
const loadHistory = () => {
  try {
    const saved = JSON.parse(localStorage.getItem(HISTORY_KEY) ?? "[]")
    return Array.isArray(saved) ? saved.filter((entry) => typeof entry === "string") : []
  } catch {
    return []
  }
}

/** @param {string[]} history */
const saveHistory = (history) => {
  try {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(-HISTORY_LIMIT)))
  } catch {
    // Storage can be full or blocked; history then lasts for this page only.
  }
}

/** `/` is a shortcut only when it would not otherwise type a character. */
/** @param {KeyboardEvent} event */
const isShortcut = (event) => {
  if (event.key !== "/" || event.ctrlKey || event.metaKey || event.altKey || event.isComposing) return false
  const target = /** @type {HTMLElement} */ (event.target)
  return !target.closest?.("input, textarea, select, [contenteditable]:not([contenteditable='false'])")
}

rocket("wlls-terminal", {
  mode: "light",
  renderOnPropChange: false,
  setup: ({ host, $$, effect, cleanup }) => {
    const sheet = host.closest("dialog")
    if (!sheet) return
    const trigger = /** @type {HTMLButtonElement | null} */ (
      document.querySelector(`[aria-controls="${sheet.id}"]`)
    )

    const history = loadHistory()
    let cursor = history.length
    let submitted = false

    const input = () => /** @type {HTMLInputElement | null} */ (host.querySelector("#terminal-input"))
    const output = () => /** @type {HTMLElement | null} */ (host.querySelector("#terminal-output"))

    const followLog = () => {
      const log = output()
      if (log) log.scrollTop = log.scrollHeight
    }

    // #lobby follows new lines too, unless you've scrolled up to read: it
    // stays put until you scroll back to the bottom.
    let chatPinned = true
    const chat = () => /** @type {HTMLElement | null} */ (host.querySelector("#terminal-chat"))
    const followChat = () => {
      const room = chat()
      if (room && chatPinned) room.scrollTop = room.scrollHeight
    }
    /** @param {Event} event */
    const onScroll = (event) => {
      const room = /** @type {HTMLElement} */ (event.target)
      if (room.id !== "terminal-chat") return
      chatPinned = room.scrollHeight - room.scrollTop - room.clientHeight < 24
    }

    // Below 60rem the sheet takes the whole screen (site.css). iOS doesn't
    // shrink the layout viewport for the on-screen keyboard; the visible part
    // (the visual viewport) shrinks instead, and can be dragged around within
    // it. So the sheet covers the whole layout viewport, and anything a drag
    // reveals is the sheet's own paper, never the page; its padding keeps the
    // terminal inside the visible part, the prompt just above the keyboard.
    // The page is pinned in place behind it (iOS scrolls past overflow:
    // hidden), and the reader's position restored when the sheet closes.
    const fullScreen = matchMedia("(max-width: 59.99rem)")
    const viewport = window.visualViewport
    const root = document.documentElement
    let pinnedAt = 0
    const fit = () => {
      if (!viewport) return
      const below = window.innerHeight - viewport.offsetTop - viewport.height
      sheet.style.setProperty("--sheet-above", `${viewport.offsetTop}px`)
      sheet.style.setProperty("--sheet-below", `${Math.max(0, below)}px`)
    }
    const pin = () => {
      if (!fullScreen.matches) return
      pinnedAt = window.scrollY
      root.style.setProperty("--pinned-top", `${-pinnedAt}px`)
      root.classList.add("terminal-pinned")
      fit()
      viewport?.addEventListener("resize", fit)
      viewport?.addEventListener("scroll", fit)
    }
    const unpin = () => {
      viewport?.removeEventListener("resize", fit)
      viewport?.removeEventListener("scroll", fit)
      sheet.style.removeProperty("--sheet-above")
      sheet.style.removeProperty("--sheet-below")
      if (!root.classList.contains("terminal-pinned")) return
      root.classList.remove("terminal-pinned")
      root.style.removeProperty("--pinned-top")
      window.scrollTo({ top: pinnedAt, behavior: "instant" })
    }

    // The dialog mirrors $$.open. Esc, the backdrop, and the close button
    // close it natively or from here, and its close event writes the signal
    // back.
    $$.open = false
    effect(() => {
      if ($$.open && !sheet.open) {
        pin()
        sheet.showModal()
        followLog()
        chatPinned = true
        followChat()
        input()?.focus()
      } else if (!$$.open && sheet.open) {
        sheet.close()
      }
    })
    const open = () => {
      $$.open = true
    }
    const close = () => {
      $$.open = false
    }
    // Every way of closing (Esc, the close button, exit, /) ends here.
    const onClose = () => {
      $$.open = false
      unpin()
    }

    // `/` opens the terminal, and closes the sheet from an empty prompt.
    /** @param {KeyboardEvent} event */
    const onShortcut = (event) => {
      const field = input()
      if (sheet.open && event.key === "/" && event.target === field && field?.value === "") {
        event.preventDefault()
        close()
        return
      }
      if (!isShortcut(event)) return
      event.preventDefault()
      open()
    }

    // A click that lands on the dialog itself is on its backdrop. Full
    // screen there is no backdrop, only the sheet's padding, so it's ignored.
    /** @param {MouseEvent} event */
    const closeFromBackdrop = (event) => {
      if (event.target === sheet && !fullScreen.matches) close()
    }

    // Clicking the terminal's own lines focuses the prompt.
    /** @param {MouseEvent} event */
    const focusPrompt = (event) => {
      const target = /** @type {Element} */ (event.target)
      if (target.closest("a, button, input") || getSelection()?.toString()) return
      if (!target.closest(".terminal-output, .terminal-bar")) return
      input()?.focus()
    }

    // Capture phase: read the command before the server replaces the prompt.
    // exit is answered here, and stopping the event keeps it from the form's
    // Datastar submit handler, so it never reaches the server.
    /** @param {SubmitEvent} event */
    const remember = (event) => {
      const field = input()
      // sudo's password prompt: never kept in history.
      if (field?.type === "password") {
        submitted = true
        return
      }
      const command = field?.value.trim()
      if (command && command !== history.at(-1)) {
        history.push(command)
        saveHistory(history)
      }
      cursor = history.length
      if (command === "exit" && field) {
        event.preventDefault()
        event.stopPropagation()
        field.value = ""
        close()
        return
      }
      submitted = true
    }

    /** @param {KeyboardEvent} event */
    const recall = (event) => {
      const field = input()
      if (event.target !== field || !field || field.type === "password" || history.length === 0) return
      if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
      event.preventDefault()
      cursor = Math.min(Math.max(cursor + (event.key === "ArrowUp" ? -1 : 1), 0), history.length)
      field.value = history[cursor] ?? ""
      field.setSelectionRange(field.value.length, field.value.length)
    }

    // Patches arrive as DOM mutations: follow the log and keep the prompt live.
    // The prompt is aria-busy while its request is in flight, which is what
    // data-indicator would do. It can't here: Rocket rescopes the signals of
    // a prompt patched into this component when the next patch lands inside
    // it, and in #lobby that is often your own message's frame arriving
    // mid-request, which resets an indicator. So listen to the same
    // datastar-fetch events the indicator plugin uses.
    // Commands aren't retried (see views.TERMINAL_POST), so a request that
    // fails on the network ends in retries-failed at once. No reply will
    // come to say so, so say it here: in the log, or above the #lobby prompt.
    // The command stays in the input to send again.
    /** @param {Event} event */
    const onFetch = (event) => {
      const { type, el } = /** @type {CustomEvent} */ (event).detail ?? {}
      if (!(el instanceof HTMLFormElement) || el.id !== "terminal-prompt") return
      if (type === "started") el.setAttribute("aria-busy", "true")
      else if (type === "finished" || type === "error" || type === "retries-failed") {
        el.removeAttribute("aria-busy")
      }
      if (type === "retries-failed") unreachable(el)
    }

    /** @param {HTMLFormElement} prompt */
    const unreachable = (prompt) => {
      const line = document.createElement("p")
      line.className = "terminal-line terminal-error"
      line.textContent = "couldn't reach wlls.dev. check your connection and try again."
      if (prompt.dataset.chat) {
        line.classList.add("terminal-notice")
        prompt.querySelector(".terminal-notice")?.remove()
        prompt.prepend(line)
      } else {
        output()?.append(line)
      }
      input()?.focus()
    }

    // After cd, the prompt stays busy until the next page loads. Going back
    // can restore this page as it was left, so let it rest again.
    /** @param {PageTransitionEvent} event */
    const onPageShow = (event) => {
      if (event.persisted) host.querySelector("#terminal-prompt")?.removeAttribute("aria-busy")
    }

    // Datastar patches arrive as DOM changes, not signal changes, so watch
    // the DOM: every patch (a reply, or a new #lobby frame) follows the newest line.
    const follow = new MutationObserver(() => {
      followLog()
      followChat()
      if (submitted && document.activeElement === document.body) input()?.focus()
    })
    follow.observe(host, { childList: true, characterData: true, subtree: true })

    document.addEventListener("keydown", onShortcut)
    trigger?.addEventListener("click", open)
    sheet.addEventListener("click", closeFromBackdrop)
    sheet.addEventListener("close", onClose)
    host.addEventListener("click", focusPrompt)
    host.addEventListener("submit", remember, true)
    host.addEventListener("keydown", recall)
    host.addEventListener("scroll", onScroll, true) // scroll doesn't bubble
    document.addEventListener("datastar-fetch", onFetch)
    window.addEventListener("pageshow", onPageShow)
    cleanup(() => {
      unpin()
      follow.disconnect()
      document.removeEventListener("keydown", onShortcut)
      trigger?.removeEventListener("click", open)
      sheet.removeEventListener("click", closeFromBackdrop)
      sheet.removeEventListener("close", onClose)
      host.removeEventListener("click", focusPrompt)
      host.removeEventListener("submit", remember, true)
      host.removeEventListener("keydown", recall)
      host.removeEventListener("scroll", onScroll, true)
      document.removeEventListener("datastar-fetch", onFetch)
      window.removeEventListener("pageshow", onPageShow)
    })
  },
})
