export function safeImageUrl(value: string | null | undefined) {
  if (!value) return "";
  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) ? url.href : "";
  } catch {
    return "";
  }
}

export function formatDate(value: string | null | undefined) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("id-ID", { dateStyle: "medium" }).format(
    new Date(`${value}T00:00:00`),
  );
}

export function formatDateTime(value: string) {
  return new Date(value).toLocaleString("id-ID");
}

export function getElectionStateLabel(state: string) {
  return { open: "Dibuka", paused: "Dijeda", closed: "Ditutup" }[state] ?? state;
}
