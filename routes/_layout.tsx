import { SiteNav } from "@/components/SiteNav.tsx";
import { define } from "@/utils.ts";

export default define.layout(({ Component, url }) => (
  <>
    <a class="skip-link" href="#main-content">Skip to content</a>
    <SiteNav path={url.pathname} />
    <main id="main-content">
      <Component />
    </main>
  </>
));
