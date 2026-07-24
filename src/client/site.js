const navigationApi = globalThis.navigation;
const documentCache = new Map();
const documentCacheTtl = 30_000;
const documentCacheLimit = 20;
let cleanupPage = () => {};
let navigationSequence = 0;

document.documentElement.dataset.navigation = navigationApi ? "enhanced" : "native";
mountPage();

document.addEventListener("click", (event) => {
  const button = event.target instanceof Element ? event.target.closest("[data-print]") : null;
  if (button) globalThis.print();
});

if (navigationApi) {
  for (const type of ["pointerover", "focusin", "touchstart"]) {
    document.addEventListener(type, prefetchIntent, { passive: true });
  }

  navigationApi.addEventListener("navigate", (event) => {
    const sequence = ++navigationSequence;
    const url = new URL(event.destination.url);
    const currentUrl = new URL(navigationApi.currentEntry.url);
    const source = event.sourceElement;
    if (
      !event.canIntercept ||
      event.hashChange ||
      event.formData ||
      event.downloadRequest !== null ||
      event.navigationType === "reload" ||
      url.origin !== location.origin ||
      source instanceof Element && source.closest("[data-native-navigation]")
    ) {
      return;
    }

    event.intercept({
      focusReset: "manual",
      scroll: "manual",
      handler: async () => {
        try {
          const nextPage = await loadDocument(url);
          if (event.signal.aborted || sequence !== navigationSequence) return;
          const canonicalUrl = new URL(nextPage.url);
          canonicalUrl.hash = url.hash;
          if (canonicalUrl.origin === location.origin && canonicalUrl.href !== url.href) {
            history.replaceState(history.state, "", canonicalUrl);
          }
          const update = () => {
            if (!event.signal.aborted && sequence === navigationSequence) {
              swapDocument(nextPage.document);
              if (event.navigationType === "traverse" || url.hash) {
                event.scroll();
              } else {
                globalThis.scrollTo(0, 0);
              }
              if (event.navigationType !== "traverse") focusMain();
            }
          };
          const cleanupAccentEntry = prepareAccentEntry(
            source,
            nextPage.document,
            currentUrl,
            url,
            event.navigationType,
          );
          if (
            cleanupAccentEntry &&
            document.startViewTransition &&
            !matchMedia("(prefers-reduced-motion: reduce)").matches
          ) {
            const transition = document.startViewTransition(update);
            void transition.finished.then(cleanupAccentEntry, cleanupAccentEntry);
            await transition.updateCallbackDone;
          } else {
            update();
            cleanupAccentEntry?.();
          }
          if (event.signal.aborted || sequence !== navigationSequence) return;
        } catch (error) {
          if (
            !event.signal.aborted && sequence === navigationSequence && error?.name !== "AbortError"
          ) {
            location.assign(url);
          }
        }
      },
    });
  });
} else if (HTMLScriptElement.supports?.("speculationrules")) {
  const rules = document.createElement("script");
  rules.type = "speculationrules";
  rules.textContent = JSON.stringify({
    prefetch: [{
      source: "document",
      where: {
        and: [
          { href_matches: "/*" },
          { not: { selector_matches: '[href$=".xml"], [download], [data-native-navigation]' } },
        ],
      },
      eagerness: "moderate",
    }],
  });
  document.head.append(rules);
} else {
  for (const type of ["pointerover", "focusin", "touchstart"]) {
    document.addEventListener(type, prefetchLink, { passive: true });
  }
}

function prefetchIntent(event) {
  const anchor = findEligibleAnchor(event.target);
  if (anchor) void loadDocument(new URL(anchor.href)).catch(() => {});
}

function prefetchLink(event) {
  const anchor = findEligibleAnchor(event.target);
  if (
    !anchor ||
    document.head.querySelector(`link[rel="prefetch"][href="${CSS.escape(anchor.href)}"]`)
  ) {
    return;
  }
  const link = document.createElement("link");
  link.rel = "prefetch";
  link.href = anchor.href;
  document.head.append(link);
}

function findEligibleAnchor(target) {
  const anchor = target instanceof Element ? target.closest("a[href]") : null;
  if (!(anchor instanceof HTMLAnchorElement)) return null;
  const url = new URL(anchor.href);
  if (
    url.origin !== location.origin ||
    url.protocol !== "http:" && url.protocol !== "https:" ||
    anchor.hasAttribute("download") ||
    anchor.target && anchor.target !== "_self" ||
    anchor.hasAttribute("data-native-navigation") ||
    anchor.relList.contains("external") ||
    url.pathname.endsWith(".xml") ||
    url.pathname === location.pathname && url.hash
  ) {
    return null;
  }
  return anchor;
}

function loadDocument(url) {
  const requestUrl = new URL(url);
  requestUrl.hash = "";
  const key = requestUrl.href;
  const now = performance.now();
  let cached = documentCache.get(key);
  if (cached && now - cached.created > documentCacheTtl) {
    documentCache.delete(key);
    cached = null;
  }
  if (!cached) {
    const request = fetch(key, { headers: { Accept: "text/html" } })
      .then(async (response) => {
        const contentType = response.headers.get("content-type") ?? "";
        if (!response.ok || !contentType.includes("text/html")) throw new Error("Not an HTML page");
        return {
          document: new DOMParser().parseFromString(await response.text(), "text/html"),
          url: response.url,
        };
      })
      .catch((error) => {
        documentCache.delete(key);
        throw error;
      });
    cached = { created: now, request };
    documentCache.set(key, cached);
    if (documentCache.size > documentCacheLimit) {
      documentCache.delete(documentCache.keys().next().value);
    }
  }
  return cached.request;
}

function swapDocument(nextDocument) {
  const nextMain = nextDocument.querySelector("main#main-content");
  const nextHeader = nextDocument.querySelector("header.site-header");
  const currentMain = document.querySelector("main#main-content");
  const currentHeader = document.querySelector("header.site-header");
  if (!nextMain || !nextHeader || !currentMain || !currentHeader) {
    throw new Error("Invalid page shell");
  }

  cleanupPage();
  for (const element of document.head.querySelectorAll("[data-page-head]")) element.remove();
  for (const element of nextDocument.head.querySelectorAll("[data-page-head]")) {
    document.head.append(document.importNode(element, true));
  }
  currentHeader.replaceWith(document.importNode(nextHeader, true));
  currentMain.replaceWith(document.importNode(nextMain, true));
  mountPage();
}

function prepareAccentEntry(source, nextDocument, currentUrl, destinationUrl, navigationType) {
  let nextAccent = null;

  const sourceLink = source instanceof Element ? source.closest(".post-list__link[href]") : null;
  if (
    sourceLink instanceof HTMLAnchorElement &&
    new URL(sourceLink.href).pathname === destinationUrl.pathname
  ) {
    nextAccent = nextDocument.querySelector(".article-header > .post-transition-mark");
  } else if (
    navigationType === "traverse" &&
    currentUrl.pathname.startsWith("/blog/") &&
    destinationUrl.pathname === "/"
  ) {
    const nextPost = findPost(nextDocument, currentUrl.pathname);
    nextAccent = nextPost?.querySelector(".post-transition-mark") ?? null;
  }

  if (!(nextAccent instanceof HTMLElement)) return null;
  nextAccent.setAttribute("data-accent-enter", "");

  return () => {
    nextAccent.removeAttribute("data-accent-enter");
    for (const element of document.querySelectorAll("[data-accent-enter]")) {
      element.removeAttribute("data-accent-enter");
    }
  };
}

function findPost(root, pathname) {
  for (const link of root.querySelectorAll(".post-list__link[href]")) {
    const href = link.getAttribute("href");
    if (href && new URL(href, location.origin).pathname === pathname) return link;
  }
  return null;
}

function focusMain() {
  const main = document.querySelector("main#main-content");
  if (!(main instanceof HTMLElement)) return;
  main.tabIndex = -1;
  main.focus({ preventScroll: true });
  main.addEventListener("blur", () => main.removeAttribute("tabindex"), { once: true });
}

function mountPage() {
  cleanupPage = mountBookLayout(document.querySelector("[data-book-layout]"));
}

function mountBookLayout(root) {
  if (!(root instanceof HTMLElement)) return () => {};

  const media = matchMedia("(min-width: 70rem) and (min-height: 44rem)");
  const viewport = globalThis.visualViewport;
  let frame = 0;
  let measureFrame = 0;
  let active = true;

  const measure = () => {
    if (!active) return;
    cancelAnimationFrame(frame);
    cancelAnimationFrame(measureFrame);
    frame = requestAnimationFrame(() => {
      const spreads = root.querySelectorAll("[data-book-spread]");
      for (const spread of spreads) spread.removeAttribute("data-overflow");
      if (!media.matches) return;

      measureFrame = requestAnimationFrame(() => {
        const rem = Number.parseFloat(getComputedStyle(document.documentElement).fontSize);
        const pageLimit = (viewport?.height ?? innerHeight) - 6 * rem;
        for (const spread of spreads) {
          const pages = spread.querySelectorAll("[data-book-page]");
          const overflows = [...pages].some((page) =>
            page.getBoundingClientRect().height > pageLimit
          );
          spread.toggleAttribute("data-overflow", overflows);
        }
      });
    });
  };

  document.fonts?.ready.then(() => active && measure());
  media.addEventListener("change", measure);
  globalThis.addEventListener("resize", measure);
  viewport?.addEventListener("resize", measure);
  root.addEventListener("load", measure, true);

  return () => {
    active = false;
    cancelAnimationFrame(frame);
    cancelAnimationFrame(measureFrame);
    media.removeEventListener("change", measure);
    globalThis.removeEventListener("resize", measure);
    viewport?.removeEventListener("resize", measure);
    root.removeEventListener("load", measure, true);
  };
}
