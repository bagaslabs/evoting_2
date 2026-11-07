import { useCallback, useEffect, useRef, useState } from "react";
import { Link, Navigate } from "react-router";
import { AdminHeader } from "../components/admin/AdminHeader";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import { Panel } from "../components/ui/Panel";
import type { AdminQueueDevice, AdminQueueVoter } from "../types/election";
import { getErrorMessage } from "../utils/errors";
import {
  fetchAdminQueueData,
  getCurrentSession,
  isPermissionError,
  signOutAdmin,
} from "../services/election";

type QueueSnapshot = Awaited<ReturnType<typeof fetchAdminQueueData>>;
type PageStatus = "loading" | "authenticated" | "unauthenticated";

export default function AdminQueuePage() {
  const [status, setStatus] = useState<PageStatus>("loading");
  const [data, setData] = useState<QueueSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const refreshing = useRef(false);

  const refresh = useCallback(async () => {
    if (refreshing.current) return;
    refreshing.current = true;
    try {
      setData(await fetchAdminQueueData());
      setError(null);
    } catch (refreshError) {
      if (isPermissionError(refreshError)) {
        setStatus("unauthenticated");
      } else {
        setError(getErrorMessage(refreshError));
      }
    } finally {
      refreshing.current = false;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const session = await getCurrentSession();
        if (cancelled) return;
        if (!session) {
          setStatus("unauthenticated");
          return;
        }

        const next = await fetchAdminQueueData();
        if (cancelled) return;
        setData(next);
        setStatus("authenticated");
      } catch (loadError) {
        if (cancelled) return;
        if (isPermissionError(loadError)) {
          setStatus("unauthenticated");
        } else {
          setError(getErrorMessage(loadError));
          setStatus("authenticated");
        }
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (status !== "authenticated") return;
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") void refresh();
    }, 5000);
    return () => window.clearInterval(timer);
  }, [status, refresh]);

  async function handleLogout() {
    try {
      await signOutAdmin();
      setStatus("unauthenticated");
    } catch (logoutError) {
      setError(getErrorMessage(logoutError));
    }
  }

  if (status === "loading") {
    return (
      <main className="page admin-loading">
        <LoadingScreen message="Memuat papan antrean…" />
      </main>
    );
  }

  if (status === "unauthenticated") {
    return <Navigate to="/admin" replace />;
  }

  return (
    <main className="page admin-shell queue-board-page">
      <AdminHeader onLogout={handleLogout} activePage="queue" />
      <section className="dashboard-heading">
        <div>
          <p className="section-marker">Pemantauan perangkat</p>
          <h1>Papan antrean</h1>
          <p className="muted">
            Semua pemilih menunggu dalam satu antrean. Bilik yang siap mengambil
            nomor teratas berikutnya.
          </p>
        </div>
        <span className="muted small">Diperbarui otomatis tiap 5 detik</span>
      </section>

      <Notice kind="error">{error}</Notice>
      {data ? (
        <QueueBoard devices={data.devices} voters={data.voters} />
      ) : (
        <Panel title="Antrean belum dapat dimuat">
          <p className="muted">
            Periksa koneksi, lalu muat ulang halaman untuk mencoba kembali.
          </p>
          <Link to="/admin">Kembali ke dashboard</Link>
        </Panel>
      )}
    </main>
  );
}

function QueueBoard({
  devices,
  voters,
}: {
  devices: AdminQueueDevice[];
  voters: AdminQueueVoter[];
}) {
  const activeDevices = devices.filter((device) => device.active);
  const queuedVoters = voters.filter(
    (voter) =>
      voter.eligible &&
      !voter.has_voted &&
      (voter.queue_state === "waiting" || voter.queue_state === "assigned"),
  );
  const waitingVoters = queuedVoters
    .filter((voter) => voter.queue_state === "waiting")
    .sort((a, b) => a.queue_position - b.queue_position);
  const calledByDevice = new Map(
    queuedVoters
      .filter(
        (voter) =>
          voter.queue_state === "assigned" && voter.queue_device_id !== null,
      )
      .map((voter) => [voter.queue_device_id, voter]),
  );

  return (
    <>
      {activeDevices.length === 0 ? (
        <Panel title="Belum ada perangkat aktif">
          <p className="muted">
            Aktifkan perangkat di dashboard agar pemilih dapat dipanggil dari
            antrean bersama.
          </p>
        </Panel>
      ) : (
        <div className="queue-board-grid">
          {activeDevices.map((device) => (
            <QueueLane
              key={device.id}
              device={device}
              voter={calledByDevice.get(device.id)}
            />
          ))}
        </div>
      )}
      <Panel
        className="queue-global-panel"
        title="Antrean global"
        description={`${waitingVoters.length} pemilih menunggu`}
      >
        {waitingVoters.length === 0 ? (
          <p className="muted small">Tidak ada pemilih yang menunggu.</p>
        ) : (
          <div className="queue-global-list">
            {waitingVoters.map((voter) => (
              <QueueTicket key={voter.nim} voter={voter} />
            ))}
          </div>
        )}
      </Panel>
    </>
  );
}

function QueueLane({
  device,
  voter,
}: {
  device: AdminQueueDevice;
  voter: AdminQueueVoter | undefined;
}) {
  return (
    <Panel
      className="queue-lane"
      title={device.name}
      description={device.connected ? "Perangkat terhubung" : "Perangkat offline"}
      aside={
        <span className={`pill ${device.connected ? "pill-active" : "pill-inactive"}`}>
          {voter ? "Sedang melayani" : "Siap memanggil"}
        </span>
      }
    >
      {voter ? (
        <QueueTicket voter={voter} called />
      ) : (
        <p className="muted small">Belum ada nomor yang dipanggil.</p>
      )}
    </Panel>
  );
}

function QueueTicket({
  voter,
  called = false,
}: {
  voter: AdminQueueVoter;
  called?: boolean;
}) {
  return (
    <article className={`queue-ticket${called ? " queue-ticket-called" : ""}`}>
      <strong className="queue-ticket-number">No. {voter.queue_position}</strong>
      <span className="queue-ticket-name">{voter.nama}</span>
      <code>{voter.nim}</code>
      {called && (
        <span className="queue-ticket-status">
          Sedang dilayani{voter.device_name ? ` · ${voter.device_name}` : ""}
        </span>
      )}
    </article>
  );
}
