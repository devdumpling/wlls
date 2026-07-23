import { Marked, render, Renderer, strip } from "@deno/gfm";
import {
  type ContentLayout,
  parsePageSource,
  parsePostSource,
  type PostSource,
  type PostSummary,
} from "./frontmatter.ts";

export interface Post extends PostSummary {
  body: string;
  content: RenderedContent;
  minutes: number;
}

export interface PageContent {
  title: string;
  description: string;
  content: RenderedContent;
}

export type RenderedContent =
  | { kind: "flow"; html: string }
  | { kind: "book"; blocks: BookBlock[] };

export type BookBlock =
  | { kind: "spread"; pages: [string] | [string, string] }
  | { kind: "plate"; html: string };

const BOOK_BREAK = /<wlls-break data-kind="(spread|page|plate)"><\/wlls-break>/;

class ContentRenderer extends Renderer {
  override code(token: Marked.Tokens.Code): string {
    const html = super.code(token);
    const title = token.lang?.match(/\stitle="(.+)"/)?.[1];
    if (!title || html.includes("markdown-code-title")) return html;
    return `<div class="markdown-code-title">${escapeHtml(title)}</div>${html}`;
  }

  override html(token: Marked.Tokens.HTML): string {
    const marker = token.text.trim().match(/^<!-- (spread|page|plate) -->$/)?.[1];
    if (marker) return `<wlls-break data-kind="${marker}"></wlls-break>`;
    return super.html(token);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function parsePost(source: string, slug: string): Post {
  return renderPost(parsePostSource(source, slug));
}

export function renderPost(source: PostSource): Post {
  const { body, ...summary } = source;
  const wordCount = strip(body).trim().split(/\s+/).filter(Boolean).length;

  return {
    ...summary,
    body,
    content: renderContent(body, source.layout ?? "flow", source.slug),
    minutes: Math.max(1, Math.ceil(wordCount / 225)),
  };
}

export function parsePage(source: string, name: string): PageContent {
  const { title, description, layout, body } = parsePageSource(source, name);

  return {
    title,
    description,
    content: renderContent(body, layout ?? "flow", name),
  };
}

function renderContent(markdown: string, layout: ContentLayout, name: string): RenderedContent {
  if (/<\/?wlls-break\b/i.test(markdown)) {
    throw new Error(`Content "${name}" uses a reserved layout element`);
  }
  const html = render(markdown, {
    renderer: new ContentRenderer(),
    allowedTags: ["wlls-break"],
    allowedAttributes: { "wlls-break": ["data-kind"] },
  }).replaceAll("<img ", '<img loading="lazy" decoding="async" ');
  const hasMarkers = BOOK_BREAK.test(html);

  if (layout === "flow") {
    if (hasMarkers) throw new Error(`Content "${name}" uses book markers without layout: book`);
    return { kind: "flow", html };
  }
  if (!hasMarkers) throw new Error(`Book content "${name}" requires a spread marker`);

  return { kind: "book", blocks: parseBookBlocks(html, name) };
}

function parseBookBlocks(html: string, name: string): BookBlock[] {
  const parts = html.split(new RegExp(BOOK_BREAK.source, "g"));
  const blocks: BookBlock[] = [];
  let current:
    | { kind: "spread"; left: string; right?: string }
    | { kind: "plate"; html: string }
    | undefined;

  for (let index = 0; index < parts.length; index += 2) {
    const fragment = parts[index].trim();
    if (fragment) {
      if (!current) throw new Error(`Book content "${name}" must begin with a spread marker`);
      if (current.kind === "plate") current.html += fragment;
      else if (current.right === undefined) current.left += fragment;
      else current.right += fragment;
    }

    const marker = parts[index + 1];
    if (!marker) break;

    if (!current && blocks.length === 0 && marker !== "spread") {
      throw new Error(`Book content "${name}" must begin with a spread marker`);
    }

    if (marker === "page") {
      if (current?.kind !== "spread" || current.right !== undefined || !current.left.trim()) {
        throw new Error(`Book content "${name}" has an invalid page marker`);
      }
      current.right = "";
      continue;
    }

    if (current) blocks.push(finishBookBlock(current, name));
    current = marker === "spread" ? { kind: "spread", left: "" } : { kind: "plate", html: "" };
  }

  if (current) blocks.push(finishBookBlock(current, name));
  if (blocks.length === 0) throw new Error(`Book content "${name}" has no content blocks`);
  return blocks;
}

function finishBookBlock(
  block: { kind: "spread"; left: string; right?: string } | { kind: "plate"; html: string },
  name: string,
): BookBlock {
  if (block.kind === "plate") {
    if (!block.html.trim()) throw new Error(`Book content "${name}" has an empty plate`);
    return { kind: "plate", html: block.html.trim() };
  }
  if (!block.left.trim() || block.right !== undefined && !block.right.trim()) {
    throw new Error(`Book content "${name}" has an empty page`);
  }
  const left = block.left.trim();
  return block.right === undefined
    ? { kind: "spread", pages: [left] }
    : { kind: "spread", pages: [left, block.right.trim()] };
}
