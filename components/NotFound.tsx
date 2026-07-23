import { PageMeta } from "./PageMeta.tsx";

export function NotFound({ path }: { path: string }) {
  return (
    <div class="page-shell error-page">
      <PageMeta title="Page not found" path={path} noIndex />
      <p class="eyebrow">404</p>
      <h1>This page has wandered off.</h1>
      <p>The address may be wrong, or the page may no longer exist.</p>
      <a href="/">Return home</a>
    </div>
  );
}
