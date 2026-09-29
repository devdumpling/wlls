// @ts-check
// Footnote previews: hovering or focusing a reference shows its note in a
// popover beside it, so reading never has to jump to the bottom of the page.
// Without this script (or on touch) the reference is still a plain link.

const GAP = 8
const HIDE_DELAY = 180

const preview = document.createElement("aside")
preview.className = "footnote-preview"
preview.id = "footnote-preview"
preview.popover = "manual"
preview.setAttribute("role", "note")

/** @type {HTMLAnchorElement | null} */
let current = null
/** @type {number | undefined} */
let hideTimer

/** @param {HTMLAnchorElement} reference */
function show(reference) {
  clearTimeout(hideTimer)
  if (current === reference) return
  const note = document.getElementById(decodeURIComponent(reference.hash.slice(1)))
  if (!note) return

  const content = /** @type {HTMLElement} */ (note.cloneNode(true))
  content.querySelectorAll(".footnote-backref").forEach((link) => link.remove())
  content.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"))
  preview.replaceChildren(...content.childNodes)

  current?.removeAttribute("aria-describedby")
  current = reference
  reference.setAttribute("aria-describedby", preview.id)
  if (!preview.matches(":popover-open")) preview.showPopover()
  place(reference)
}

/** Center under the reference, flip above near the bottom, stay on screen. */
/** @param {HTMLElement} reference */
function place(reference) {
  const anchor = reference.getBoundingClientRect()
  const box = preview.getBoundingClientRect()
  const left = Math.min(
    Math.max(anchor.left + anchor.width / 2 - box.width / 2, GAP),
    innerWidth - box.width - GAP,
  )
  const below = anchor.bottom + GAP
  const top = below + box.height > innerHeight - GAP ? anchor.top - box.height - GAP : below
  preview.style.left = `${left}px`
  preview.style.top = `${top}px`
}

function hide() {
  clearTimeout(hideTimer)
  current?.removeAttribute("aria-describedby")
  current = null
  if (preview.matches(":popover-open")) preview.hidePopover()
}

function hideSoon() {
  clearTimeout(hideTimer)
  hideTimer = setTimeout(hide, HIDE_DELAY)
}

/** @param {Event} event */
function referenceFrom(event) {
  const target = /** @type {Element | null} */ (event.target)
  return /** @type {HTMLAnchorElement | null} */ (target?.closest?.("a[data-footnote-ref]") ?? null)
}

const references = document.querySelectorAll("a[data-footnote-ref]")
if (references.length > 0) {
  document.body.append(preview)

  document.addEventListener("pointerover", (event) => {
    if (/** @type {PointerEvent} */ (event).pointerType !== "mouse") return
    const reference = referenceFrom(event)
    if (reference) show(reference)
  })
  document.addEventListener("pointerout", (event) => {
    if (referenceFrom(event)) hideSoon()
  })
  document.addEventListener("focusin", (event) => {
    const reference = referenceFrom(event)
    if (reference) show(reference)
  })
  document.addEventListener("focusout", (event) => {
    if (referenceFrom(event)) hideSoon()
  })
  preview.addEventListener("pointerenter", () => clearTimeout(hideTimer))
  preview.addEventListener("pointerleave", hideSoon)
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") hide()
  })
  addEventListener("scroll", hide, { passive: true })
  addEventListener("resize", hide)
}
