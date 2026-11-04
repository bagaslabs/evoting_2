import type { ReactNode } from "react";

interface PanelProps {
  title?: string;
  description?: string;
  aside?: ReactNode;
  className?: string;
  children: ReactNode;
}

export function Panel({
  title,
  description,
  aside,
  className = "",
  children,
}: PanelProps) {
  return (
    <section className={`panel ${className}`.trim()}>
      {(title || aside) && (
        <header className="panel-header">
          <div>
            {title && <h2 className="panel-title">{title}</h2>}
            {description && <p className="panel-description">{description}</p>}
          </div>
          {aside && <div className="panel-aside">{aside}</div>}
        </header>
      )}
      {children}
    </section>
  );
}
