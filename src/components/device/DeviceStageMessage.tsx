import { useState } from "react";
import type { FormEvent } from "react";
import { Button } from "../ui/Button";
import { Input } from "../ui/Input";

export type DeviceIdleStage =
  | "idle"
  | "assigned"
  | "waiting"
  | "paused"
  | "closed"
  | "inactive";

interface DeviceStageMessageProps {
  stage: DeviceIdleStage;
  onVerify: (nim: string) => Promise<void>;
}

const STAGE_COPY: Record<
  Exclude<DeviceIdleStage, "assigned">,
  { title: string; description: string }
> = {
  idle: {
    title: "Menyiapkan antrean…",
    description: "Perangkat akan menerima antrean berikutnya saat tersedia.",
  },
  waiting: {
    title: "Menunggu antrean berikutnya.",
    description: "Pemilih berikutnya sedang menggunakan perangkat lain.",
  },
  paused: {
    title: "Pemilihan sedang dijeda.",
    description: "Perangkat akan menerima antrean berikutnya saat pemilihan dilanjutkan.",
  },
  closed: {
    title: "Pemilihan belum dibuka.",
    description: "Tunggu instruksi panitia sebelum pemungutan suara dimulai.",
  },
  inactive: {
    title: "Perangkat dinonaktifkan admin.",
    description: "Hubungi admin untuk mengaktifkan kembali perangkat ini.",
  },
};

export function DeviceStageMessage({ stage, onVerify }: DeviceStageMessageProps) {
  const [nim, setNim] = useState("");
  const [busy, setBusy] = useState(false);

  const copy =
    stage === "assigned"
      ? {
          title: "Silakan masukkan NIM Anda.",
          description: "Masukkan NIM sesuai antrean perangkat ini.",
        }
      : STAGE_COPY[stage];

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    try {
      await onVerify(nim.trim());
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="device-message">
      <span className="status-dot" aria-hidden="true" />
      <h2>{copy.title}</h2>
      <p className="muted">{copy.description}</p>

      {stage === "assigned" && (
        <form className="inline-form voter-entry" onSubmit={handleSubmit}>
          <label htmlFor="voter-nim">NIM</label>
          <Input
            id="voter-nim"
            value={nim}
            onChange={(event) => setNim(event.currentTarget.value)}
            autoComplete="off"
            inputMode="text"
            required
          />
          <Button type="submit" disabled={busy}>
            {busy ? "Memeriksa…" : "Cek biodata"}
          </Button>
        </form>
      )}
    </div>
  );
}
