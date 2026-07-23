import { extractYaml } from "@std/front-matter";

export type ContentLayout = "flow" | "book";

interface PostFrontmatter {
  title: string;
  description: string;
  date: string;
  topic?: string;
  layout?: ContentLayout;
}

export interface PostSummary extends PostFrontmatter {
  slug: string;
}

export interface PostSource extends PostSummary {
  body: string;
}

export interface PageSource {
  title: string;
  description: string;
  layout?: ContentLayout;
  body: string;
}

export function parsePostSource(source: string, slug: string): PostSource {
  const { attrs, body } = extractYaml<Record<string, unknown>>(source);
  const title = requiredString(attrs, "title", slug);
  const description = requiredString(attrs, "description", slug);
  const date = requiredString(attrs, "date", slug);
  const topic = optionalString(attrs, "topic", slug);
  const layout = optionalLayout(attrs, slug);

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

  return { slug, title, description, date, topic, layout, body };
}

export function parsePageSource(source: string, name: string): PageSource {
  const { attrs, body } = extractYaml<Record<string, unknown>>(source);

  return {
    title: requiredString(attrs, "title", name),
    description: requiredString(attrs, "description", name),
    layout: optionalLayout(attrs, name),
    body,
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

function optionalLayout(
  attrs: Record<string, unknown>,
  name: string,
): ContentLayout | undefined {
  const value = attrs.layout;
  if (value === undefined) return undefined;
  if (value !== "flow" && value !== "book") {
    throw new Error(`Content "${name}" has an invalid layout`);
  }
  return value;
}
