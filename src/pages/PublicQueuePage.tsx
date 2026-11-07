import { useCallback, useEffect, useRef, useState } from "react";
import { Link } from "react-router";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { Button } from "../components/ui/Button";
import { FullscreenButton } from "../components/ui/FullscreenButton";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import { getPublicCurrentQueue } from "../services/election";
import type { PublicQueueEntry } from "../types/election";
import { getErrorMessage } from "../utils/errors";

function formatElapsedTime(assignedAt: string, now: number) {
  const start = Date.parse(assignedAt);
  if (!Number.isFinite(start)) return null;

  const totalSeconds = Math.floor(Math.max(0, now - start) / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const formatPart = (value: number) => String(value).padStart(2, "0");

  return hours > 0
    ? `${formatPart(hours)}:${formatPart(minutes)}:${formatPart(seconds)}`
    : `${formatPart(Math.floor(totalSeconds / 60))}:${formatPart(seconds)}`;
}

export default function PublicQueuePage() {
  const pageRef = useRef<HTMLElement>(null);
  const [entries, setEntries] = useState<
    (PublicQueueEntry & { numberChanged: boolean })[] | null
  >(null);
  const [now, setNow] = useState(() => Date.now());
  const [error, setError] = useState<string | null>(null);
  const requestInFlight = useRef(false);
  const previousAssignments = useRef(new Map<string, string | null>());

  const refresh = useCallback(async () => {
    if (requestInFlight.current) return;
    requestInFlight.current = true;
    try {
      const currentEntries = await getPublicCurrentQueue();
      const displayEntries = currentEntries.map((entry) => ({
        ...entry,
        numberChanged:
          previousAssignments.current.has(entry.device_name) &&
          previousAssignments.current.get(entry.device_name) !==
            entry.assigned_at,
      }));
      previousAssignments.current = new Map(
        currentEntries.map(({ device_name, assigned_at }) => [
          device_name,
          assigned_at,
        ]),
      );
      setEntries(displayEntries);
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
    }, 2000);
    return () => window.clearInterval(timer);
  }, [error, refresh]);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <main className="page public-queue-shell" ref={pageRef}>
      <SiteHeader
        suffix="Antrean"
        nav={[
          { label: "Beranda", to: "/" },
          { label: "Hasil pemilihan", to: "/results" },
        ]}
      />
      <div className="public-queue-toolbar">
        <FullscreenButton targetRef={pageRef} />
      </div>

      <section className="public-queue-heading">
        <p className="section-marker">Informasi pemilihan</p>
        <h1>Antrean saat ini</h1>
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
          {entries.map((entry, index) => (
            <article
              className={
                entry.numberChanged
                  ? "public-queue-card public-queue-card-blink"
                  : "public-queue-card"
              }
              key={`${entry.device_name}-${index}`}
            >
              <h2>{entry.device_name}</h2>
              {entry.waiting_for_voter ? (
                <p className="public-queue-waiting">
                  Menunggu pemilih berikutnya
                </p>
              ) : (
                <>
                  <strong className="public-queue-number">
                    <span
                      className={
                        entry.numberChanged
                          ? "public-queue-number-blink"
                          : undefined
                      }
                    >
                      {entry.voter_suffix}
                    </span>
                  </strong>
                  <span className="public-queue-voter-name">
                    {entry.voter_name}
                  </span>
                  {entry.assigned_at && (
                    <span className="public-queue-elapsed">
                      Berjalan{" "}
                      {formatElapsedTime(entry.assigned_at, now) ?? "--:--"}
                    </span>
                  )}
                </>
              )}
            </article>
          ))}
        </section>
      )}

      <p className="public-queue-refresh-note">
        Diperbarui otomatis setiap 2 detik ·{" "}
        <Link to="/admin">Dashboard admin</Link>
      </p>
      <SiteFooter>
        Halaman ini menampilkan nama pemilih dan tiga digit terakhir NIM, tanpa
        NIM lengkap.
      </SiteFooter>
    </main>
  );
}
