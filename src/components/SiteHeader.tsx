import type { ReactNode } from "react";
import { Link } from "react-router";
import { Brand } from "./Brand";

interface NavItem {
  label: string;
  to: string;
}

interface SiteHeaderProps {
  suffix?: string;
  nav?: NavItem[];
  children?: ReactNode;
}

export function SiteHeader({ suffix, nav = [], children }: SiteHeaderProps) {
  return (
    <header className="site-header">
      <Brand suffix={suffix} />
      <nav className="site-nav" aria-label="Navigasi utama">
        {nav.map((item) => (
          <Link key={item.to} to={item.to}>
            {item.label}
          </Link>
        ))}
        {children}
      </nav>
    </header>
  );
}
