interface SiteNavProps {
  path: string;
}

export function SiteNav({ path }: SiteNavProps) {
  return (
    <header class="site-header">
      <nav aria-label="Primary navigation">
        <a href="/about" aria-current={path === "/about" ? "page" : "false"}>About</a>
        <a
          class="site-mark"
          href="/"
          aria-label="wlls.dev home"
          aria-current={path === "/" ? "page" : "false"}
        >
          wlls.dev
        </a>
        <a href="/rss.xml">RSS</a>
      </nav>
    </header>
  );
}
