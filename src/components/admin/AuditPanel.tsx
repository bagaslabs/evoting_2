import { useState } from "react";
import type { FormEvent } from "react";
import type { AuditLogItem } from "../../types/election";
import { formatDateTime } from "../../utils/format";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface AuditPanelProps {
  auditLog: AuditLogItem[];
  realtimeStatus: string;
  onChangePassword: (
    currentPassword: string,
    nextPassword: string,
    confirmation: string,
  ) => Promise<void>;
}

export function AuditPanel({
  auditLog,
  realtimeStatus,
  onChangePassword,
}: AuditPanelProps) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    const next = String(data.get("next") ?? "");
    const confirmation = String(data.get("confirm") ?? "");

    if (next.length < 12 || next !== confirmation) {
      setError("Kata sandi baru harus minimal 12 karakter dan kedua isian harus sama.");
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await onChangePassword(
        String(data.get("current") ?? ""),
        next,
        confirmation,
      );
      form.reset();
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title="Audit dan keamanan"
      description="Aktivitas admin terakhir dan pengaturan kata sandi akun."
      aside={<span className="muted small">{realtimeStatus}</span>}
    >
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Waktu</th>
              <th>Aksi</th>
              <th>Detail</th>
            </tr>
          </thead>
          <tbody>
            {auditLog.length === 0 && (
              <tr>
                <td colSpan={3} className="muted">
                  Belum ada catatan.
                </td>
              </tr>
            )}
            {auditLog.map((item) => (
              <tr key={`${item.created_at}-${item.action}`}>
                <td>{formatDateTime(item.created_at)}</td>
                <td>{item.action}</td>
                <td>
                  <code>{JSON.stringify(item.details)}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <details className="disclosure password-section">
        <summary>Ubah kata sandi admin</summary>
        <form className="stack password-form" onSubmit={handleSubmit}>
          <Field label="Kata sandi saat ini" htmlFor="password-current">
            <Input
              id="password-current"
              name="current"
              type="password"
              autoComplete="current-password"
              required
            />
          </Field>
          <Field label="Kata sandi baru" htmlFor="password-next">
            <Input
              id="password-next"
              name="next"
              type="password"
              autoComplete="new-password"
              minLength={12}
              required
            />
          </Field>
          <Field label="Ulangi kata sandi baru" htmlFor="password-confirm">
            <Input
              id="password-confirm"
              name="confirm"
              type="password"
              autoComplete="new-password"
              minLength={12}
              required
            />
          </Field>
          <Notice kind="error">{error}</Notice>
          <Button type="submit" variant="secondary" disabled={busy}>
            {busy ? "Mengubah…" : "Ubah kata sandi"}
          </Button>
        </form>
      </details>
    </Panel>
  );
}
