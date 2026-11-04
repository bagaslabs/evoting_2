import { useState } from "react";
import type { FormEvent } from "react";
import { Link } from "react-router";
import { Brand } from "../Brand";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { isSupabaseConfigured } from "../../lib/supabase";
import { getErrorMessage } from "../../utils/errors";

interface LoginPanelProps {
  onSubmit: (email: string, password: string) => Promise<void>;
  initialError?: string | null;
}

export function LoginPanel({ onSubmit, initialError }: LoginPanelProps) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setBusy(true);
    setError(null);

    try {
      await onSubmit(
        String(data.get("email") ?? "").trim(),
        String(data.get("password") ?? ""),
      );
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="auth-layout">
      <div className="auth-brand">
        <Brand suffix="Admin" />
      </div>
      <section className="auth-panel card">
        <p className="section-marker">Area terbatas</p>
        <h1>Masuk sebagai superadmin</h1>
        <p className="muted">
          Gunakan email dan kata sandi akun admin yang telah diprovisikan.
        </p>

        {!isSupabaseConfigured && (
          <Notice kind="error">
            Konfigurasi Supabase belum tersedia. Isi file <code>.env</code> lalu
            muat ulang halaman.
          </Notice>
        )}
        <Notice kind="error">{error ?? initialError}</Notice>

        <form className="stack" onSubmit={handleSubmit}>
          <Field label="Email admin" htmlFor="admin-email">
            <Input
              id="admin-email"
              name="email"
              type="email"
              autoComplete="username"
              required
            />
          </Field>
          <Field label="Kata sandi" htmlFor="admin-password">
            <Input
              id="admin-password"
              name="password"
              type="password"
              autoComplete="current-password"
              required
            />
          </Field>
          <Button type="submit" disabled={busy || !isSupabaseConfigured}>
            {busy ? "Memeriksa akun…" : "Masuk"}
          </Button>
        </form>

        <Link className="back-link" to="/">
          Kembali ke beranda
        </Link>
      </section>
    </main>
  );
}
