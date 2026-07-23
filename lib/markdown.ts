import { render, strip } from "@deno/gfm";
import { extractYaml } from "@std/front-matter";

interface PostFrontmatter {
  title: string;
  description: string;
  date: string;
  topic?: string;
  archive?: boolean;
}

export interface Post extends PostFrontmatter {
  slug: string;
  body: string;
  html: string;
  minutes: number;
}

export interface PageContent {
  title: string;
  description: string;
  html: string;
}

export function parsePost(source: string, slug: string): Post {
  const { attrs, body } = extractYaml<Record<string, unknown>>(source);
  const title = requiredString(attrs, "title", slug);
  const description = requiredString(attrs, "description", slug);
  const date = requiredString(attrs, "date", slug);
  const topic = optionalString(attrs, "topic", slug);
  const archive = optionalBoolean(attrs, "archive", slug);

  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
    throw new Error(`Post "${slug}" must use a lowercase kebab-case filename`);
  }

  const parsedDate = new Date(`${date}T00:00:00Z`);
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    Number.isNaN(parsedDate.getTime()) ||
    parsedDate.toISOString().slice(0, 10) !== date
  ) {
    throw new Error(`Post "${slug}" has an invalid ISO date: ${date}`);
  }

  const wordCount = strip(body).trim().split(/\s+/).filter(Boolean).length;

  return {
    slug,
    title,
    description,
    date,
    topic,
    archive,
    body,
    html: renderMarkdown(body),
    minutes: Math.max(1, Math.ceil(wordCount / 225)),
  };
}

export function parsePage(source: string, name: string): PageContent {
  const { attrs, body } = extractYaml<Record<string, unknown>>(source);

  return {
    title: requiredString(attrs, "title", name),
    description: requiredString(attrs, "description", name),
    html: renderMarkdown(body),
  };
}

export function formatDate(date: string, style: "full" | "short" = "full"): string {
  return new Intl.DateTimeFormat("en-US", {
    day: style === "full" ? "numeric" : undefined,
    month: "long",
    timeZone: "UTC",
    year: "numeric",
  }).format(new Date(`${date}T00:00:00Z`));
}

function renderMarkdown(markdown: string): string {
  return render(markdown).replaceAll("<img ", '<img loading="lazy" decoding="async" ');
}

function requiredString(attrs: Record<string, unknown>, key: string, name: string): string {
  const value = attrs[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`Content "${name}" requires a non-empty ${key}`);
  }
  return value.trim();
}

function optionalString(
  attrs: Record<string, unknown>,
  key: string,
  name: string,
): string | undefined {
  const value = attrs[key];
  if (value === undefined) return undefined;
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`Content "${name}" has an invalid ${key}`);
  }
  return value.trim();
}

function optionalBoolean(
  attrs: Record<string, unknown>,
  key: string,
  name: string,
): boolean | undefined {
  const value = attrs[key];
  if (value === undefined) return undefined;
  if (typeof value !== "boolean") {
    throw new Error(`Content "${name}" has an invalid ${key}`);
  }
  return value;
}
