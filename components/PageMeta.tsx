import { Head } from "fresh/runtime";
import { absoluteUrl, site } from "@/lib/site.ts";

interface PageMetaProps {
  title?: string;
  description?: string;
  path: string;
  type?: "website" | "article";
  published?: string;
  noIndex?: boolean;
}

export function PageMeta({
  title,
  description = site.description,
  path,
  type = "website",
  published,
  noIndex = false,
}: PageMetaProps) {
  const pageTitle = title ? `${title} | ${site.name}` : `${site.title} | ${site.name}`;
  const url = absoluteUrl(path);

  return (
    <Head>
      <title>{pageTitle}</title>
      <meta name="description" content={description} />
      <link rel="canonical" href={url} />
      <meta property="og:type" content={type} />
      <meta property="og:title" content={pageTitle} />
      <meta property="og:description" content={description} />
      <meta property="og:url" content={url} />
      <meta property="og:site_name" content={site.name} />
      <meta name="twitter:card" content="summary" />
      <meta name="twitter:title" content={pageTitle} />
      <meta name="twitter:description" content={description} />
      {published && <meta property="article:published_time" content={published} />}
      {noIndex && <meta name="robots" content="noindex" />}
    </Head>
  );
}
