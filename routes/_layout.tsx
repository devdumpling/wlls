import { SiteNav } from "@/components/SiteNav.tsx";
import { define } from "@/utils.ts";

export default define.layout(({ Component, url }) => (
  <>
    <a class="skip-link" href="#main-content">Skip to content</a>
    <SiteNav path={url.pathname} />
    <main id="main-content">
      <Component />
    </main>
    <footer class="site-footer">
      <p>Written and built by Devon Wells.</p>
      <a href="/rss.xml">RSS</a>
    </footer>
  </>
));
