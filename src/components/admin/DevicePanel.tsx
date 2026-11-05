import { useState } from "react";
import type { FormEvent } from "react";
import type { ElectionSettings, VotingDevice } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface DevicePanelProps {
  election: ElectionSettings;
  devices: VotingDevice[];
  onCreate: (name: string) => Promise<void>;
  onToggle: (device: VotingDevice) => Promise<void>;
  onAssignNext: (device: VotingDevice) => Promise<void>;
  onForceRelease: (device: VotingDevice) => void;
  onDelete: (device: VotingDevice) => void;
  onRotateToken: (device: VotingDevice) => void;
  onCopyToken: (device: VotingDevice) => Promise<void>;
}

export function DevicePanel({
  election,
  devices,
  onCreate,
  onToggle,
  onAssignNext,
  onForceRelease,
  onDelete,
  onRotateToken,
  onCopyToken,
}: DevicePanelProps) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const name = String(new FormData(form).get("name") ?? "").trim();
    setBusy(true);
    setError(null);

    try {
      await onCreate(name);
      form.reset();
    } catch (createError) {
      setError(getErrorMessage(createError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title="Perangkat voting"
      description="Daftarkan perangkat dan bagikan tokennya kepada petugas."
      aside={<span className="muted small">{devices.length} perangkat</span>}
    >
      <form className="inline-form" onSubmit={handleCreate}>
        <Field label="Nama perangkat" htmlFor="device-name">
          <Input
            id="device-name"
            name="name"
            placeholder="Laptop 1"
            required
          />
        </Field>
        <Button type="submit" disabled={busy}>
          {busy ? "Mendaftarkan…" : "Daftarkan"}
        </Button>
      </form>
      <Notice kind="error">{error}</Notice>

      <div className="list-stack">
        {devices.length === 0 && (
          <p className="muted">Belum ada perangkat terdaftar.</p>
        )}
        {devices.map((device) => (
          <DeviceRow
            key={device.id}
            device={device}
            election={election}
            onToggle={onToggle}
            onAssignNext={onAssignNext}
            onForceRelease={onForceRelease}
            onDelete={onDelete}
            onRotateToken={onRotateToken}
            onCopyToken={onCopyToken}
          />
        ))}
      </div>
    </Panel>
  );
}

interface DeviceRowProps {
  device: VotingDevice;
  election: ElectionSettings;
  onToggle: (device: VotingDevice) => Promise<void>;
  onAssignNext: (device: VotingDevice) => Promise<void>;
  onForceRelease: (device: VotingDevice) => void;
  onDelete: (device: VotingDevice) => void;
  onRotateToken: (device: VotingDevice) => void;
  onCopyToken: (device: VotingDevice) => Promise<void>;
}

function DeviceRow({
  device,
  election,
  onToggle,
  onAssignNext,
  onForceRelease,
  onDelete,
  onRotateToken,
  onCopyToken,
}: DeviceRowProps) {
  const [pending, setPending] = useState(false);

  async function run(action: () => Promise<void>) {
    setPending(true);
    try {
      await action();
    } finally {
      setPending(false);
    }
  }

  const canAssignNext =
    election.election_state === "open" &&
    device.active &&
    device.connected &&
    !device.active_assignment_id;

  return (
    <article className="list-row">
      <div className="device-info">
        <div className="list-row-title">
          <strong>{device.name}</strong>
          <span className={`pill ${device.active ? "pill-active" : "pill-inactive"}`}>
            {device.active ? "Aktif" : "Nonaktif"}
          </span>
        </div>

        <div className="device-token">
          <span className="muted small">Kode token perangkat</span>
          {device.token ? (
            <div className="token-line">
              <code>{device.token}</code>
              <Button
                size="sm"
                variant="secondary"
                onClick={() => run(() => onCopyToken(device))}
                disabled={pending}
              >
                Salin
              </Button>
              <Button
                size="sm"
                variant="secondary"
                onClick={() => onRotateToken(device)}
              >
                Ganti kode
              </Button>
            </div>
          ) : (
            <div className="token-line">
              <span className="muted small">
                Token lama belum tersimpan; buat kode baru untuk menampilkannya.
              </span>
              <Button
                size="sm"
                variant="secondary"
                onClick={() => onRotateToken(device)}
              >
                Buat kode token
              </Button>
            </div>
          )}
        </div>

        <p className="device-meta">
          <span>{device.connected ? "Terhubung" : "Tidak terhubung"}</span>
          <span>{device.active ? "Aktif" : "Nonaktif"}</span>
          {device.active_nim && <span>Antrean {device.active_nim}</span>}
        </p>
      </div>

      <div className="row-actions">
        <Button
          size="sm"
          variant="secondary"
          onClick={() => run(() => onToggle(device))}
          disabled={pending}
        >
          {device.active ? "Nonaktifkan" : "Aktifkan"}
        </Button>
        {canAssignNext && (
          <Button
            size="sm"
            onClick={() => run(() => onAssignNext(device))}
            disabled={pending}
          >
            Assign berikutnya
          </Button>
        )}
        {device.active_assignment_id && (
          <Button
            size="sm"
            variant="danger"
            onClick={() => onForceRelease(device)}
          >
            Paksa lepas
          </Button>
        )}
        <Button
          size="sm"
          variant="danger"
          onClick={() => onDelete(device)}
          disabled={
            pending ||
            election.election_state !== "closed" ||
            Boolean(device.active_assignment_id)
          }
          title={
            election.election_state !== "closed"
              ? "Tutup pemilihan sebelum menghapus perangkat."
              : device.active_assignment_id
                ? "Lepaskan assignment aktif sebelum menghapus perangkat."
                : "Hapus perangkat dan seluruh riwayat assignment-nya."
          }
        >
          Hapus perangkat
        </Button>
      </div>
    </article>
  );
}
