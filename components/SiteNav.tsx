interface SiteNavProps {
  path: string;
}

const links = [
  { href: "/", label: "Home" },
  { href: "/blog", label: "Writing" },
  { href: "/about", label: "About" },
  { href: "/resume", label: "Resume" },
];

export function SiteNav({ path }: SiteNavProps) {
  return (
    <header class="site-header">
      <a
        class="site-mark"
        href="/"
        aria-label="wlls.dev home"
        aria-current={path === "/" ? "page" : "false"}
      >
        wlls.dev
      </a>
      <nav aria-label="Primary navigation">
        {links.map((link) => {
          const current = path === link.href
            ? "page"
            : link.href !== "/" && path.startsWith(`${link.href}/`)
            ? "true"
            : "false";
          return (
            <a href={link.href} aria-current={current}>
              {link.label}
            </a>
          );
        })}
      </nav>
    </header>
  );
}
