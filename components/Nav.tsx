"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/scan", label: "Scan", icon: "🔮" },
  { href: "/battle", label: "Battle", icon: "⚔️" },
  { href: "/classement", label: "Classement", icon: "🏆" },
  { href: "/trends", label: "Trends", icon: "📈" },
];

export function Nav() {
  const pathname = usePathname();
  return (
    <nav className="nav">
      <div className="nav-inner">
        <Link href="/" className="logo">
          AuraMaxxing
        </Link>
        <div className="nav-links">
          {LINKS.map((l) => (
            <Link key={l.href} href={l.href} className={`nav-link ${pathname.startsWith(l.href) ? "active" : ""}`}>
              <span className="nav-icon">{l.icon}</span>
              {l.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
