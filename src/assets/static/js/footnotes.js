// @ts-check
// Footnotes, enhanced. Where the margin has room, each note is already set
// beside its reference as a sidenote (CSS does that without this script);
// here hovering or focusing a reference highlights its sidenote, and notes
// that would collide are nudged apart. Elsewhere, hovering or focusing a
// reference shows its note in a popover beside it, so reading never has to
// jump to the bottom of the page. Without this script (or on touch) the
// reference is still a plain link. Embeds that hang in the margin
// (css/embeds.css) are laid out with the sidenotes, so neither covers the
// other.

const GAP = 8;
const HIDE_DELAY = 180;
const BREAKOUTS =
  ':scope > :is(pre, table, .plates, .plate[data-size="wide"], .plate[data-size="full"])';
const MARGIN_EMBEDS = ":scope > .embed[data-margin] > *";

const preview = document.createElement("aside");
preview.className = "footnote-preview";
preview.id = "footnote-preview";
preview.popover = "manual";
preview.setAttribute("role", "note");

/** Sidenotes by their note's hash; only a note's first reference has one. */
/** @type {Map<string, HTMLElement>} */
const sidenotes = new Map();

/**
 * The reference whose note is in the preview.
 * @type {HTMLAnchorElement | null}
 */
let previewed = null;
/** @type {HTMLElement | null} */
let activeSidenote = null;
/** @type {number | undefined} */
let hideTimer;

/**
 * The reference's sidenote, if the layout is showing sidenotes.
 * @param {HTMLAnchorElement} reference
 */
function sidenoteOf(reference) {
  const sidenote = sidenotes.get(reference.hash);
  return sidenote?.checkVisibility() ? sidenote : null;
}

/** @param {HTMLAnchorElement} reference */
function show(reference) {
  clearTimeout(hideTimer);
  const sidenote = sidenoteOf(reference);
  if (sidenote) {
    closePreview();
    activeSidenote?.classList.remove("is-active");
    activeSidenote = sidenote;
    sidenote.classList.add("is-active");
    return;
  }
  if (previewed === reference) return;
  const note = document.getElementById(decodeURIComponent(reference.hash.slice(1)));
  if (!note) return;

  const content = /** @type {HTMLElement} */ (note.cloneNode(true));
  content.querySelectorAll(".footnote-backref").forEach((link) => link.remove());
  content.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"));
  preview.replaceChildren(...content.childNodes);

  previewed?.removeAttribute("aria-describedby");
  previewed = reference;
  reference.setAttribute("aria-describedby", preview.id);
  if (!preview.matches(":popover-open")) preview.showPopover();
  place(reference);
}

/**
 * Center under the reference, flip above near the bottom, stay on screen.
 * @param {HTMLElement} reference
 */
function place(reference) {
  const anchor = reference.getBoundingClientRect();
  const box = preview.getBoundingClientRect();
  const left = Math.min(
    Math.max(anchor.left + anchor.width / 2 - box.width / 2, GAP),
    innerWidth - box.width - GAP,
  );
  const below = anchor.bottom + GAP;
  const top = below + box.height > innerHeight - GAP ? anchor.top - box.height - GAP : below;
  preview.style.left = `${left}px`;
  preview.style.top = `${top}px`;
}

function closePreview() {
  previewed?.removeAttribute("aria-describedby");
  previewed = null;
  if (preview.matches(":popover-open")) preview.hidePopover();
}

function hide() {
  clearTimeout(hideTimer);
  closePreview();
  activeSidenote?.classList.remove("is-active");
  activeSidenote = null;
}

function hideSoon() {
  clearTimeout(hideTimer);
  hideTimer = setTimeout(hide, HIDE_DELAY);
}

/** @param {Event} event */
function referenceFrom(event) {
  const target = /** @type {Element | null} */ (event.target);
  return (
    /** @type {HTMLAnchorElement | null} */ (target?.closest?.("a[data-footnote-ref]") ?? null)
  );
}

/**
 * Each sidenote sits level with its reference, and each margin embed where
 * it falls in the text. Walk them in reading order and move each one down
 * just enough to clear the one above it and any code, table, or plate that
 * reaches into the margin.
 * @param {Element} body
 */
function layout(body) {
  /** @type {HTMLElement[]} */
  const embeds = [...body.querySelectorAll(MARGIN_EMBEDS)];
  for (const item of [...sidenotes.values(), ...embeds]) item.style.translate = "";
  const items = [
    ...[...sidenotes.values()].filter((note) => note.checkVisibility()),
    ...embeds.filter((embed) => getComputedStyle(embed).position === "absolute"),
  ].sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top);
  if (items.length === 0) return;

  const breakouts = [...body.querySelectorAll(BREAKOUTS)].map((element) =>
    element.getBoundingClientRect(),
  );
  let floor = -Infinity;
  for (const item of items) {
    const box = item.getBoundingClientRect();
    let top = Math.max(box.top, floor);
    for (const breakout of breakouts) {
      const overlaps =
        breakout.left < box.right &&
        breakout.right > box.left &&
        breakout.top < top + box.height &&
        breakout.bottom > top;
      if (overlaps) top = breakout.bottom + GAP * 2;
    }
    if (top !== box.top) item.style.translate = `0 ${top - box.top}px`;
    floor = top + box.height + GAP * 2;
  }
}

const references = /** @type {NodeListOf<HTMLAnchorElement>} */ (
  document.querySelectorAll("a[data-footnote-ref]")
);
for (const reference of references) {
  const sibling = reference.parentElement?.nextElementSibling;
  if (sibling instanceof HTMLElement && sibling.classList.contains("sidenote")) {
    sidenotes.set(reference.hash, sibling);
  }
}

// Fonts, images, and the viewport all move notes; each resizes the body.
// Margin embeds take no room in it, so they're watched on their own, and
// laid out again once their component (a later script) defines them.
const article = document.querySelector(".article-body");
const marginEmbeds = article ? [...article.querySelectorAll(MARGIN_EMBEDS)] : [];
if (article && (sidenotes.size > 0 || marginEmbeds.length > 0)) {
  const watch = new ResizeObserver(() => layout(article));
  watch.observe(article);
  for (const embed of marginEmbeds) {
    watch.observe(embed);
    customElements.whenDefined(embed.localName).then(() => layout(article));
  }
}

if (references.length > 0) {
  document.body.append(preview);

  document.addEventListener("pointerover", (event) => {
    if (/** @type {PointerEvent} */ (event).pointerType !== "mouse") return;
    const reference = referenceFrom(event);
    if (reference) show(reference);
  });
  document.addEventListener("pointerout", (event) => {
    if (referenceFrom(event)) hideSoon();
  });
  document.addEventListener("focusin", (event) => {
    const reference = referenceFrom(event);
    if (reference) show(reference);
  });
  document.addEventListener("focusout", (event) => {
    if (referenceFrom(event)) hideSoon();
  });
  // The notes section is hidden while sidenotes show, so a reference's link
  // has nowhere to go: bring its sidenote into view instead.
  document.addEventListener("click", (event) => {
    const reference = referenceFrom(event);
    const sidenote = reference && sidenoteOf(reference);
    if (!sidenote) return;
    event.preventDefault();
    sidenote.scrollIntoView({ block: "nearest" });
    show(reference);
  });
  preview.addEventListener("pointerenter", () => clearTimeout(hideTimer));
  preview.addEventListener("pointerleave", hideSoon);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") hide();
  });
  addEventListener("scroll", closePreview, { passive: true });
  addEventListener("resize", closePreview);
}
