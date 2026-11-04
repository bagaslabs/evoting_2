import { useState } from "react";
import type { FormEvent } from "react";
import { Link } from "react-router";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";

interface DeviceSetupFormProps {
  onSubmit: (token: string) => Promise<void>;
}

export function DeviceSetupForm({ onSubmit }: DeviceSetupFormProps) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const token = String(new FormData(event.currentTarget).get("token") ?? "").trim();
    setBusy(true);
    setError(null);

    try {
      await onSubmit(token);
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="auth-panel card">
      <p className="section-marker">Identitas perangkat</p>
      <h1>Hubungkan perangkat voting</h1>
      <p className="muted">
        Masukkan token perangkat yang dibuat superadmin. Token disimpan pada
        browser perangkat ini.
      </p>
      <Notice kind="error">{error}</Notice>
      <form className="stack" onSubmit={handleSubmit}>
        <Field label="Token perangkat" htmlFor="device-token">
          <Input
            id="device-token"
            name="token"
            type="password"
            autoComplete="off"
            required
          />
        </Field>
        <Button type="submit" disabled={busy}>
          {busy ? "Menghubungkan…" : "Hubungkan"}
        </Button>
      </form>
      <Link className="back-link" to="/">
        Kembali ke beranda
      </Link>
    </section>
  );
}
