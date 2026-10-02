// @ts-check
// <wlls-terminal>: client behavior for the server-driven terminal. The server
// renders the log and prompt and answers each command with SSE patches; this
// component only adds what a browser must own: focus, command history on ↑/↓
// (kept across pages), keeping the newest output in view, folding the log, and
// the `/` shortcut. On the landing page the terminal sits inline; elsewhere it
// lives in a <dialog> sheet that the breadcrumb row's trigger opens. The sheet
// follows a local `open` signal, so `exit` closes it without a round trip.
// Same fingerprinted directory as this file, so this resolves to the exact URL
// the page already loaded: one module instance, and no inline import map.
import { rocket } from "./datastar-rocket.js"

const HISTORY_KEY = "wlls:terminal-history"
const HISTORY_LIMIT = 50

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
    const history = loadHistory()
    let cursor = history.length
    let submitted = false

    const input = () => /** @type {HTMLInputElement | null} */ (host.querySelector("#terminal-input"))
    const output = () => /** @type {HTMLElement | null} */ (host.querySelector("#terminal-output"))
    const toggle = /** @type {HTMLButtonElement | null} */ (host.querySelector(".terminal-toggle"))
    const sheet = /** @type {HTMLDialogElement | null} */ (host.closest("dialog"))
    const trigger = /** @type {HTMLButtonElement | null} */ (
      sheet ? document.querySelector(`[aria-controls="${sheet.id}"]`) : null
    )

    const followLog = () => {
      const log = output()
      if (log) log.scrollTop = log.scrollHeight
    }

    // The dialog mirrors $$.open. Esc and the backdrop close it natively or
    // from here, and its close event writes the signal back.
    if (sheet) {
      $$.open = false
      effect(() => {
        if ($$.open && !sheet.open) {
          sheet.showModal()
          followLog()
          input()?.focus()
        } else if (!$$.open && sheet.open) {
          sheet.close()
        }
      })
    }
    const open = () => {
      if (sheet) $$.open = true
      else input()?.focus()
    }
    const close = () => {
      if (sheet) $$.open = false
      else input()?.blur()
    }
    const onClose = () => {
      $$.open = false
    }

    // `/` opens the terminal, and closes the sheet from an empty prompt.
    /** @param {KeyboardEvent} event */
    const onShortcut = (event) => {
      const field = input()
      if (sheet?.open && event.key === "/" && event.target === field && field?.value === "") {
        event.preventDefault()
        close()
        return
      }
      if (!isShortcut(event)) return
      event.preventDefault()
      open()
    }

    // A click that lands on the dialog itself is on its backdrop.
    /** @param {MouseEvent} event */
    const closeFromBackdrop = (event) => {
      if (event.target === sheet) close()
    }

    // Clicking the terminal's own lines focuses the prompt.
    /** @param {MouseEvent} event */
    const focusPrompt = (event) => {
      const target = /** @type {Element} */ (event.target)
      if (target.closest("a, button, input") || getSelection()?.toString()) return
      if (!target.closest(".terminal-output, .terminal-bar")) return
      input()?.focus()
    }

    // The fold toggle only appears once someone has found the prompt.
    const engage = () => {
      host.dataset.engaged = ""
    }

    /** @param {boolean} collapsed */
    const fold = (collapsed) => {
      host.toggleAttribute("data-collapsed", collapsed)
      if (toggle) {
        toggle.textContent = collapsed ? "[+]" : "[-]"
        toggle.setAttribute("aria-expanded", String(!collapsed))
        toggle.setAttribute("aria-label", collapsed ? "Unfold terminal output" : "Fold terminal output")
      }
      followLog()
    }
    const onToggle = () => fold(!host.hasAttribute("data-collapsed"))

    // Capture phase: read the command before the server replaces the prompt.
    // exit is answered here, and stopping the event keeps it from the form's
    // Datastar submit handler, so it never reaches the server.
    /** @param {SubmitEvent} event */
    const remember = (event) => {
      const field = input()
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
      if (event.target !== field || !field || history.length === 0) return
      if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
      event.preventDefault()
      cursor = Math.min(Math.max(cursor + (event.key === "ArrowUp" ? -1 : 1), 0), history.length)
      field.value = history[cursor] ?? ""
      field.setSelectionRange(field.value.length, field.value.length)
    }

    // Patches arrive as DOM mutations: follow the log and keep the prompt live.
    const follow = new MutationObserver(() => {
      followLog()
      if (submitted && document.activeElement === document.body) input()?.focus()
    })
    follow.observe(host, { childList: true, subtree: true })

    document.addEventListener("keydown", onShortcut)
    trigger?.addEventListener("click", open)
    sheet?.addEventListener("click", closeFromBackdrop)
    sheet?.addEventListener("close", onClose)
    host.addEventListener("click", focusPrompt)
    host.addEventListener("focusin", engage)
    host.addEventListener("submit", remember, true)
    host.addEventListener("keydown", recall)
    toggle?.addEventListener("click", onToggle)
    cleanup(() => {
      follow.disconnect()
      document.removeEventListener("keydown", onShortcut)
      trigger?.removeEventListener("click", open)
      sheet?.removeEventListener("click", closeFromBackdrop)
      sheet?.removeEventListener("close", onClose)
      host.removeEventListener("click", focusPrompt)
      host.removeEventListener("focusin", engage)
      host.removeEventListener("submit", remember, true)
      host.removeEventListener("keydown", recall)
      toggle?.removeEventListener("click", onToggle)
    })
  },
})
