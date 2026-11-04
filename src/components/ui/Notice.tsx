import type { ReactNode } from "react";

export type NoticeKind = "info" | "success" | "warning" | "error";

interface NoticeProps {
  kind?: NoticeKind;
  children?: ReactNode;
}

export function Notice({ kind = "info", children }: NoticeProps) {
  if (!children) return null;

  return (
    <div
      className={`notice notice-${kind}`}
      role={kind === "error" ? "alert" : "status"}
    >
      {children}
    </div>
  );
}
