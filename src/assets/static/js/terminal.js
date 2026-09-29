// @ts-check
// <wlls-terminal>: client behavior for the server-driven landing terminal.
// The server renders the log and prompt and answers each command with SSE
// patches; this component only adds what a browser must own: focus, command
// history on ↑/↓, keeping the newest output in view, and folding the log.
import { rocket } from "datastar"

rocket("wlls-terminal", {
  mode: "light",
  renderOnPropChange: false,
  setup: ({ host, cleanup }) => {
    /** @type {string[]} */
    const history = []
    let cursor = 0
    let submitted = false

    const input = () => /** @type {HTMLInputElement | null} */ (host.querySelector("#terminal-input"))
    const output = () => /** @type {HTMLElement | null} */ (host.querySelector("#terminal-output"))
    const toggle = /** @type {HTMLButtonElement | null} */ (host.querySelector(".terminal-toggle"))

    const followLog = () => {
      const log = output()
      if (log) log.scrollTop = log.scrollHeight
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
    const remember = () => {
      const command = input()?.value.trim()
      if (command && command !== history.at(-1)) history.push(command)
      cursor = history.length
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

    host.addEventListener("click", focusPrompt)
    host.addEventListener("focusin", engage)
    host.addEventListener("submit", remember, true)
    host.addEventListener("keydown", recall)
    toggle?.addEventListener("click", onToggle)
    cleanup(() => {
      follow.disconnect()
      host.removeEventListener("click", focusPrompt)
      host.removeEventListener("focusin", engage)
      host.removeEventListener("submit", remember, true)
      host.removeEventListener("keydown", recall)
      toggle?.removeEventListener("click", onToggle)
    })
  },
})
