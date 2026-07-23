import { parsePage, parsePost } from "./markdown.ts";

Deno.test("parsePost validates metadata and renders Markdown", () => {
  const post = parsePost(
    `---
title: A small test
description: Test description
date: "2026-07-22"
topic: Engineering
archive: true
---

## A heading

Text with a footnote.[^1]

[^1]: The note.
`,
    "small-test",
  );

  assertEquals(post.title, "A small test");
  assertEquals(post.archive, true);
  assert(post.html.includes('id="a-heading"'));
  assert(post.html.includes("footnotes"));
  assertEquals(post.minutes, 1);
});

Deno.test("parsePost rejects non-ISO dates", () => {
  assertThrows(() =>
    parsePost(
      `---
title: Invalid date
description: Test description
date: July 22, 2026
---
Body
`,
      "invalid-date",
    )
  );
});

Deno.test("parsePost rejects impossible calendar dates", () => {
  assertThrows(() =>
    parsePost(
      `---
title: Invalid calendar date
description: Test description
date: "2026-02-30"
---
Body
`,
      "invalid-calendar-date",
    )
  );
});

Deno.test("parsePage renders standalone Markdown", () => {
  const page = parsePage(
    `---
title: About
description: About this site
---

Plain **Markdown**.
`,
    "about",
  );

  assertEquals(page.title, "About");
  assert(page.html.includes("<strong>Markdown</strong>"));
});

function assert(condition: unknown): asserts condition {
  if (!condition) throw new Error("Assertion failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
  }
}

function assertThrows(fn: () => void): void {
  try {
    fn();
  } catch {
    return;
  }
  throw new Error("Expected function to throw");
}
