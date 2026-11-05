import { useCallback, useEffect, useRef, useState } from "react";
import { Link } from "react-router";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { Button } from "../components/ui/Button";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import { getPublicCurrentQueue } from "../services/election";
import type { PublicQueueEntry } from "../types/election";
import { getErrorMessage } from "../utils/errors";

export default function PublicQueuePage() {
  const [entries, setEntries] = useState<PublicQueueEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const requestInFlight = useRef(false);

  const refresh = useCallback(async () => {
    if (requestInFlight.current) return;
    requestInFlight.current = true;
    try {
      setEntries(await getPublicCurrentQueue());
      setError(null);
    } catch (loadError) {
      setError(getErrorMessage(loadError));
    } finally {
      requestInFlight.current = false;
    }
  }, []);

  useEffect(() => {
    void refresh();
    if (error) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") void refresh();
    }, 5000);
    return () => window.clearInterval(timer);
  }, [error, refresh]);

  return (
    <main className="page public-queue-shell">
      <SiteHeader
        suffix="Antrean"
        nav={[
          { label: "Beranda", to: "/" },
          { label: "Hasil pemilihan", to: "/results" },
        ]}
      />

      <section className="public-queue-heading">
        <p className="section-marker">Informasi pemilihan</p>
        <h1>Antrean saat ini</h1>
        <p className="muted">
          Nomor yang sedang dilayani di setiap perangkat. Data pemilih tetap
          dirahasiakan.
        </p>
      </section>

      <Notice kind="error">{error}</Notice>
      {entries === null && !error ? (
        <LoadingScreen message="Memuat antrean saat ini…" />
      ) : entries === null ? (
        <section className="panel public-queue-empty">
          <h2>Antrean belum dapat dimuat</h2>
          <p className="muted">
            Periksa koneksi atau pastikan migrasi antrean publik sudah diterapkan.
          </p>
          <Button variant="secondary" onClick={() => void refresh()}>
            Coba lagi
          </Button>
        </section>
      ) : entries.length === 0 ? (
        <section className="panel public-queue-empty">
          <span className="status-dot" aria-hidden="true" />
          <h2>Belum ada antrean yang dipanggil</h2>
          <p className="muted">
            Informasi akan diperbarui otomatis saat perangkat mulai melayani
            peserta.
          </p>
        </section>
      ) : (
        <section className="public-queue-list" aria-label="Antrean yang sedang dilayani">
          {entries.map((entry) => (
            <article
              className="public-queue-card"
              key={`${entry.device_name}-${entry.queue_number}`}
            >
              <span className="public-queue-label">Sedang dilayani di</span>
              <h2>{entry.device_name}</h2>
              <strong className="public-queue-number">
                No. {entry.queue_number}
              </strong>
            </article>
          ))}
        </section>
      )}

      <p className="public-queue-refresh-note">
        Diperbarui otomatis setiap 5 detik ·{" "}
        <Link to="/admin">Dashboard admin</Link>
      </p>
      <SiteFooter>
        Halaman ini hanya menampilkan nomor antrean dan perangkat, tanpa nama
        atau NIM pemilih.
      </SiteFooter>
    </main>
  );
}
