"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/scan", label: "Scan" },
  { href: "/battle", label: "Battle" },
  { href: "/classement", label: "Classement" },
  { href: "/trends", label: "Trends" },
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
              {l.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
