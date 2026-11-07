export function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;

  if (typeof error === "object" && error !== null) {
    const record = error as Record<string, unknown>;
    const parts = ["message", "details", "hint"]
      .map((key) => record[key])
      .filter((value): value is string => typeof value === "string" && value.length > 0);

    if (parts.length > 0) return [...new Set(parts)].join(" ");
  }

  return "Terjadi kesalahan. Silakan coba kembali.";
}

export function isDeviceBoundError(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "55000"
  );
}
