// deno-lint-ignore-file react-no-danger -- Speculation rules are fixed JSON generated below.
import { define } from "@/utils.ts";

const prefetchRules = JSON.stringify({
  prefetch: [{
    source: "document",
    where: {
      and: [
        { href_matches: "/*" },
        { not: { selector_matches: '[href$=".xml"], [download]' } },
      ],
    },
    eagerness: "moderate",
  }],
});

export default define.page(function App({ Component }) {
  return (
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="light" />
        <link
          rel="preload"
          href="/fonts/literata-latin.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
        <link rel="icon" href="/favicon.svg" />
        <link rel="alternate" type="application/rss+xml" title="wlls.dev" href="/rss.xml" />
        <script type="speculationrules" dangerouslySetInnerHTML={{ __html: prefetchRules }} />
      </head>
      <body>
        <Component />
      </body>
    </html>
  );
});
