import type { ReactNode } from "react";

export function SiteFooter({ children }: { children: ReactNode }) {
  return <footer className="site-footer">{children}</footer>;
}
