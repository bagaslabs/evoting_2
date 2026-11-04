import { useState } from "react";
import type { VerifiedVoter } from "../../types/election";
import { formatDate } from "../../utils/format";
import { Button } from "../ui/Button";

interface VoterBiodataProps {
  voter: VerifiedVoter;
  onContinue: () => Promise<void>;
}

export function VoterBiodata({ voter, onContinue }: VoterBiodataProps) {
  const [busy, setBusy] = useState(false);

  async function handleContinue() {
    setBusy(true);
    try {
      await onContinue();
    } finally {
      setBusy(false);
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
      <Button onClick={handleContinue} disabled={busy}>
        {busy ? "Memuat kandidat…" : "Lanjut ke halaman voting"}
      </Button>
    </div>
  );
}
