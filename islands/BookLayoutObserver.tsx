import { useEffect } from "preact/hooks";

export default function BookLayoutObserver({ targetId }: { targetId: string }) {
  useEffect(() => {
    const root = document.getElementById(targetId);
    if (!root) return;

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
        const spreads = root.querySelectorAll<HTMLElement>("[data-book-spread]");
        for (const spread of spreads) spread.removeAttribute("data-overflow");
        if (!media.matches) return;

        measureFrame = requestAnimationFrame(() => {
          const rem = Number.parseFloat(getComputedStyle(document.documentElement).fontSize);
          const viewportHeight = viewport?.height ?? innerHeight;
          const pageLimit = viewportHeight - 6 * rem;

          for (const spread of spreads) {
            const pages = spread.querySelectorAll<HTMLElement>("[data-book-page]");
            const overflows = [...pages].some((page) =>
              page.getBoundingClientRect().height > pageLimit
            );
            spread.toggleAttribute("data-overflow", overflows);
          }
        });
      });
    };

    const fontsReady = document.fonts?.ready ?? Promise.resolve();
    fontsReady.then(() => {
      if (active) measure();
    });
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
  }, [targetId]);

  return null;
}
