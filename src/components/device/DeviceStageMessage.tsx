import { useState } from "react";
import type { FormEvent } from "react";
import type { VerifiedVoter } from "../../types/election";
import { Button } from "../ui/Button";
import { Input } from "../ui/Input";

export type DeviceIdleStage =
  | "idle"
  | "assigned"
  | "waiting"
  | "empty"
  | "paused"
  | "closed"
  | "inactive";

interface DeviceStageMessageProps {
  stage: DeviceIdleStage;
  onVerify: (nim: string) => Promise<void>;
  voterMatches: VerifiedVoter[];
  onSelectVoter: (voter: VerifiedVoter) => void;
  onClearVoterMatches: () => void;
}

const STAGE_COPY: Record<
  Exclude<DeviceIdleStage, "assigned">,
  { title: string; description: string }
> = {
  idle: {
    title: "Siap melayani pemilih.",
    description:
      "Masukkan tiga digit terakhir NIM pemilih yang eligible dan belum memilih.",
  },
  waiting: {
    title: "Siap melayani pemilih.",
    description:
      "Masukkan tiga digit terakhir NIM pemilih yang eligible dan belum memilih.",
  },
  empty: {
    title: "Belum ada antrean yang dipanggil.",
    description:
      "Masukkan tiga digit terakhir NIM pemilih yang eligible dan belum memilih. Antrean hanya informasi.",
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

export function DeviceStageMessage({
  stage,
  onVerify,
  voterMatches,
  onSelectVoter,
  onClearVoterMatches,
}: DeviceStageMessageProps) {
  const [nim, setNim] = useState("");
  const [busy, setBusy] = useState(false);

  const copy =
    stage === "assigned"
      ? {
          title: "Masukkan tiga digit terakhir NIM.",
          description:
            "Perangkat ini dapat melayani pemilih eligible mana pun yang belum memilih; antrean hanya informasi.",
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

      {["assigned", "waiting", "empty", "idle"].includes(stage) && (
        <form className="inline-form voter-entry" onSubmit={handleSubmit}>
          <label htmlFor="voter-nim">Tiga digit terakhir NIM</label>
          <Input
            id="voter-nim"
            value={nim}
            onChange={(event) => {
              setNim(event.currentTarget.value.replace(/\D/g, "").slice(0, 3));
              onClearVoterMatches();
            }}
            autoComplete="off"
            inputMode="numeric"
            pattern="[0-9]{3}"
            maxLength={3}
            placeholder="000"
            title="Masukkan tepat tiga angka."
            required
          />
          <Button type="submit" disabled={busy}>
            {busy ? "Memeriksa…" : "Cek biodata"}
          </Button>
        </form>
      )}
      {voterMatches.length > 0 && (
        <div className="voter-match-list" aria-live="polite">
          <p>Beberapa pemilih memiliki tiga digit terakhir yang sama. Pilih nama Anda:</p>
          {voterMatches.map((voter) => (
            <Button
              key={voter.nim}
              variant="secondary"
              onClick={() => onSelectVoter(voter)}
            >
              {voter.nama}
            </Button>
          ))}
        </div>
      )}
    </div>
  );
}
