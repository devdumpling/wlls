import { expect, test } from "@playwright/test";

const slugs = [
  "ai-reflections-fatigue",
  "devex",
  "snowglobe",
  "on-tailwind",
  "rethinking",
  "ai-reflections",
  "improving-mediums-stories-page",
  "save-spaces-in-games",
  "gaming-recluse-is-dead",
  "6000-hours-dota-2",
];

test("prerenders every public page and article", async ({ page }) => {
  for (const path of ["/", "/about", "/resume", ...slugs.map((slug) => `/blog/${slug}`)]) {
    const response = await page.goto(path);
    expect(response?.status(), path).toBe(200);
    await expect(page.locator("main")).toBeVisible();
  }
});

test("preloads article data and navigates without replacing the document", async ({ page }) => {
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.navigation)).toBe(
    "enhanced",
  );
  await page.evaluate(() =>
    document.documentElement.setAttribute("data-navigation-marker", "kept")
  );
  await page.evaluate(() => {
    const startViewTransition = document.startViewTransition.bind(document);
    document.startViewTransition = (update) => {
      document.body.dataset.transitionCount = String(
        Number(document.body.dataset.transitionCount ?? 0) + 1,
      );
      document.body.dataset.transitionSource = document.querySelector("[data-accent-enter]")
        ?.className ?? "";
      return startViewTransition(async () => {
        await update();
        document.body.dataset.transitionDestination = document.querySelector("[data-accent-enter]")
          ?.className ?? "";
      });
    };
  });

  const link = page.getByRole("link", { name: "On Tailwind" });
  const preload = page.waitForResponse((response) =>
    response.url().endsWith("/blog/on-tailwind") && response.ok()
  );
  await link.hover();
  await preload;
  await link.click();

  await expect(page).toHaveURL(/\/blog\/on-tailwind$/);
  await expect(page.locator("h1")).toHaveText("On Tailwind");
  expect(await page.evaluate(() => document.documentElement.dataset.navigationMarker)).toBe("kept");
  await expect(page.locator("main")).toBeFocused();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://wlls.dev/blog/on-tailwind",
  );
  await expect(page.locator('script[type="application/ld+json"]')).toHaveCount(1);
  await expect(page.locator("body")).toHaveAttribute("data-transition-source", "");
  await expect(page.locator("body")).toHaveAttribute(
    "data-transition-destination",
    "post-transition-mark",
  );
  await expect(page.locator("[data-accent-enter]")).toHaveCount(0);

  await page.evaluate(() => history.back());
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("heading", { name: "Writing" })).toBeAttached();
  await expect(page.locator("body")).toHaveAttribute("data-transition-count", "2");
  expect(await page.evaluate(() => document.documentElement.dataset.navigationMarker)).toBe("kept");
});

test("renders book content without horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 1512, height: 982 });
  await page.goto("/blog/on-tailwind");
  await expect(page.locator("[data-book-spread]")).not.toHaveCount(0);
  await page.waitForTimeout(100);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);

  await page.setViewportSize({ width: 320, height: 800 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test("does not commit content from an abandoned navigation", async ({ page }) => {
  await page.route("**/about", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 250));
    await route.continue();
  });
  await page.goto("/");
  await page.evaluate(() => {
    location.assign("/about");
    setTimeout(() => location.assign("/resume"), 10);
  });

  await expect(page).toHaveURL(/\/resume$/);
  await expect(page.locator("h1")).toHaveText("Devon Wells");
  await page.waitForTimeout(300);
  await expect(page.locator("h1")).toHaveText("Devon Wells");
});

test("keeps enhanced navigation on canonical URLs", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => location.assign("/about/"));
  await expect(page).toHaveURL(/\/about$/);
  await expect(page.locator("h1")).toHaveText("Roots");
});

test("resets new navigations and restores traversal scroll", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => scrollTo(0, 700));
  await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(500);
  const homeScroll = await page.evaluate(() => scrollY);

  const scrollAtSwap = page.evaluate(() =>
    new Promise<number>((resolve) => {
      const observer = new MutationObserver(() => {
        if (document.querySelector(".article-header h1")?.textContent === "On Tailwind") {
          observer.disconnect();
          resolve(scrollY);
        }
      });
      observer.observe(document.body, { childList: true, subtree: true });
    })
  );
  await page.evaluate(() => {
    const link = [...document.querySelectorAll("a")].find((anchor) =>
      anchor.getAttribute("href") === "/blog/on-tailwind"
    );
    if (!(link instanceof HTMLAnchorElement)) throw new Error("Article link not found");
    link.click();
  });
  await expect(page).toHaveURL(/\/blog\/on-tailwind$/);
  expect(await scrollAtSwap).toBeLessThan(2);
  await expect.poll(() => page.evaluate(() => scrollY)).toBeLessThan(2);
  await expect(page.locator("[data-accent-enter]")).toHaveCount(0);

  await page.evaluate(() => scrollTo(0, 500));
  await page.evaluate(() => history.back());
  await expect(page).toHaveURL(/\/$/);
  await expect.poll(() => page.evaluate((expected) => Math.abs(scrollY - expected), homeScroll))
    .toBeLessThan(2);
});

test("cleans transition names from cached documents", async ({ page }) => {
  const errors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/");

  for (
    const [slug, title] of [
      ["ai-reflections-fatigue", "AI Reflections: Fatigue"],
      ["devex", "devex: my N=1 Experiment on AI-Assisted Coding"],
    ]
  ) {
    await page.evaluate((path) => {
      const link = document.querySelector(`a[href="/blog/${path}"]`);
      if (!(link instanceof HTMLAnchorElement)) throw new Error("Article link not found");
      link.click();
    }, slug);
    await expect(page).toHaveURL(new RegExp(`/blog/${slug}$`));
    await expect(page.locator("h1")).toHaveText(title);
    await expect.poll(() => page.evaluate(() => scrollY)).toBeLessThan(2);
    await expect(page.locator("[data-accent-enter]")).toHaveCount(0);

    await page.evaluate(() => history.back());
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole("heading", { name: "Writing" })).toBeAttached();
    await expect(page.locator("[data-accent-enter]")).toHaveCount(0);
  }

  expect(errors).toEqual([]);
});

test("keeps articles readable without JavaScript", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const response = await page.goto("/blog/ai-reflections-fatigue");

  expect(response?.status()).toBe(200);
  await expect(page.locator("h1")).toHaveText("AI Reflections: Fatigue");
  await expect(page.locator(".prose p").first()).toBeVisible();
  await context.close();
});

test("serves crawler files and real 404 responses", async ({ page }) => {
  const home = await page.request.get("/");
  expect(home.headers()["cache-control"]).toContain("s-maxage=86400");

  const rss = await page.request.get("/rss.xml");
  expect(rss.status()).toBe(200);
  expect(rss.headers()["content-type"]).toContain("application/rss+xml");
  expect(rss.headers()["cache-control"]).toContain("s-maxage=86400");
  expect((await page.request.get("/sitemap.xml")).status()).toBe(200);

  const html = await home.text();
  const assetPath = html.match(/href="(\/assets\/site-[^"]+\.css)"/)?.[1];
  expect(assetPath).toBeTruthy();
  expect((await page.request.get(assetPath!)).headers()["cache-control"]).toContain("immutable");

  const response = await page.goto("/this-page-does-not-exist");
  expect(response?.status()).toBe(404);
  await expect(page.locator("h1")).toHaveText("This page has wandered off.");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "noindex");
});

test("keeps resume interactions local and native", async ({ page }) => {
  await page.goto("/resume");
  await page.evaluate(() => {
    globalThis.print = () => document.body.setAttribute("data-print-called", "true");
  });
  await page.getByRole("button", { name: "Print or save as PDF" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-print-called", "true");

  const story = page.locator("details").first();
  await story.locator("summary").click();
  await expect(story).toHaveAttribute("open", "");
});
