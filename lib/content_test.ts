import { parsePage, parsePost } from "./markdown.ts";

Deno.test("parsePost validates metadata and renders Markdown", () => {
  const post = parsePost(
    `---
title: A small test
description: Test description
date: "2026-07-22"
topic: Engineering
---

## A heading

Text with a footnote.[^1]

[^1]: The note.
`,
    "small-test",
  );

  assertEquals(post.title, "A small test");
  assert(post.content.kind === "flow");
  assert(post.content.html.includes('id="a-heading"'));
  assert(post.content.html.includes("footnotes"));
  assertEquals(post.minutes, 1);
});

Deno.test("parsePost renders explicit book spreads and plates", () => {
  const post = parsePost(
    `---
title: A book test
description: Test description
date: "2026-07-22"
layout: book
---

<!-- spread -->

## First page

Text with a footnote.[^1]

<!-- page -->

## Second page

More text.

<!-- plate -->

\`\`\`html title="Marker example"
<!-- page -->
\`\`\`

<!-- spread -->

## Final page

[^1]: The note.
`,
    "book-test",
  );

  assert(post.content.kind === "book");
  assertEquals(post.content.blocks.length, 3);
  const [first, plate, last] = post.content.blocks;
  assert(first.kind === "spread" && first.pages.length === 2);
  assert(first.pages[0].includes('id="first-page"'));
  assert(first.pages[1].includes('id="second-page"'));
  assert(plate.kind === "plate" && plate.html.includes("&lt;!-- page --&gt;"));
  assert(plate.html.includes('class="markdown-code-title">Marker example'));
  assert(last.kind === "spread" && last.pages.length === 1);
  assert(last.pages[0].includes("footnotes"));
});

Deno.test("parsePost rejects book markers without the book layout", () => {
  assertThrows(() =>
    parsePost(
      `---
title: Invalid marker
description: Test description
date: "2026-07-22"
---

<!-- spread -->

Text
`,
      "invalid-marker",
    )
  );
});

Deno.test("parsePost rejects empty book pages", () => {
  assertThrows(() =>
    parsePost(
      `---
title: Empty page
description: Test description
date: "2026-07-22"
layout: book
---

<!-- spread -->

Text

<!-- page -->

<!-- spread -->

More text
`,
      "empty-page",
    )
  );
});

Deno.test("parsePost rejects a book that begins with a plate", () => {
  assertThrows(() =>
    parsePost(
      `---
title: Invalid first block
description: Test description
date: "2026-07-22"
layout: book
---

<!-- plate -->

\`\`\`
Code
\`\`\`
`,
      "invalid-first-block",
    )
  );
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
  assert(page.content.kind === "flow");
  assert(page.content.html.includes("<strong>Markdown</strong>"));
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
