export const site = {
  name: "wlls.dev",
  title: "Devon Wells",
  description: "Software engineer, tinkerer, writer.",
  url: "https://wlls.dev",
  author: "Devon Wells",
} as const;

export function absoluteUrl(path: string): string {
  return new URL(path, site.url).href;
}

export function serializeJsonLd(value: unknown): string {
  return JSON.stringify(value).replaceAll("<", "\\u003c");
}
