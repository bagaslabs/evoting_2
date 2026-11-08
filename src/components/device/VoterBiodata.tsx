import { useState } from "react";
import type { VerifiedVoter } from "../../types/election";
import { formatDate } from "../../utils/format";
import { Button } from "../ui/Button";

interface VoterBiodataProps {
  voter: VerifiedVoter;
  onContinue: () => Promise<void>;
  onBack: () => Promise<void>;
}

export function VoterBiodata({ voter, onContinue, onBack }: VoterBiodataProps) {
  const [busyAction, setBusyAction] = useState<"continue" | "back" | null>(
    null,
  );

  async function handleContinue() {
    setBusyAction("continue");
    try {
      await onContinue();
    } finally {
      setBusyAction(null);
    }
  }

  async function handleBack() {
    setBusyAction("back");
    try {
      await onBack();
    } finally {
      setBusyAction(null);
    }
  }

  return (
    <div className="voter-biodata">
      <p className="section-marker">Identitas terverifikasi</p>
      <h2>{voter.nama}</h2>
      <dl className="biodata-list">
        <div>
          <dt>NIM</dt>
          <dd>{voter.nim}</dd>
        </div>
        <div>
          <dt>Jenis kelamin</dt>
          <dd>{voter.jenis_kelamin || "-"}</dd>
        </div>
        <div>
          <dt>Tanggal masuk</dt>
          <dd>{formatDate(voter.tanggal_masuk)}</dd>
        </div>
        <div>
          <dt>Status saat ini</dt>
          <dd>{voter.status_saat_ini || "-"}</dd>
        </div>
      </dl>
      <Button onClick={() => void handleContinue()} disabled={busyAction !== null}>
        {busyAction === "continue"
          ? "Memuat kandidat…"
          : "Lanjut ke halaman voting"}
      </Button>
      <Button
        variant="ghost"
        onClick={() => void handleBack()}
        disabled={busyAction !== null}
      >
        {busyAction === "back" ? "Mengembalikan…" : "Salah biodata? Kembali"}
      </Button>
    </div>
  );
}
