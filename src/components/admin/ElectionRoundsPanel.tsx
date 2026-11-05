import { useState } from "react";
import { Link } from "react-router";
import type { Candidate, ElectionRound, ElectionSettings } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Checkbox";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface ElectionRoundsPanelProps {
  election: ElectionSettings;
  rounds: ElectionRound[];
  candidates: Candidate[];
  onCreate: (candidateIds: string[]) => Promise<void>;
  onSelect: (roundId: string) => Promise<void>;
  onDelete: (round: ElectionRound) => void;
}

export function ElectionRoundsPanel({
  election,
  rounds,
  candidates,
  onCreate,
  onSelect,
  onDelete,
}: ElectionRoundsPanelProps) {
  const [selectedIds, setSelectedIds] = useState<string[]>(() =>
    candidates.filter((candidate) => candidate.active).map(({ id }) => id),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canChangeRound =
    election.election_state === "closed" && busy === false;

  async function handleCreate() {
    setBusy(true);
    setError(null);
    try {
      await onCreate(selectedIds);
    } catch (createError) {
      setError(getErrorMessage(createError));
    } finally {
      setBusy(false);
    }
  }

  async function handleSelect(roundId: string) {
    setBusy(true);
    setError(null);
    try {
      await onSelect(roundId);
    } catch (selectError) {
      setError(getErrorMessage(selectError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title="Babak pemilihan"
      description="Setiap babak menyimpan suara dan hasilnya secara terpisah. Pemilih dapat memilih satu kali di setiap babak."
      aside={
        <span className="muted small">
          Aktif: {election.active_round_title ?? "Belum ada"}
        </span>
      }
    >
      {rounds.length === 0 ? (
        <Notice kind="warning">
          Fitur babak belum tersedia di database. Terapkan migrasi
          {" "}20261105000000_election_rounds.sql ke project Supabase, lalu muat
          ulang dashboard.
        </Notice>
      ) : (
        <>
          <div className="round-list">
            {rounds.map((round) => {
              const isActive = round.id === election.active_round_id;
              return (
                <article className="round-item" key={round.id}>
                  <div>
                    <strong>{round.title}</strong>
                    <span className="muted small">
                      {round.candidate_ids.length} kandidat ·{" "}
                      {round.results_published
                        ? "hasil dipublikasikan"
                        : "hasil privat"}
                    </span>
                  </div>
                  <div className="button-row">
                    {isActive ? (
                      <span className="pill pill-active">Babak aktif</span>
                    ) : (
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={!canChangeRound}
                        onClick={() => void handleSelect(round.id)}
                      >
                        {busy ? "Memproses…" : "Jadikan aktif"}
                      </Button>
                    )}
                    <Link
                      className="btn btn-ghost btn-sm"
                      to={`/results/babak-${round.round_number}`}
                    >
                      Lihat hasil
                    </Link>
                    <Button
                      size="sm"
                      variant="danger"
                      disabled={!canChangeRound || isActive}
                      title={
                        isActive
                          ? "Pilih babak lain sebagai aktif sebelum menghapus babak ini."
                          : "Menghapus babak juga menghapus semua suaranya dan hasilnya secara permanen."
                      }
                      onClick={() => onDelete(round)}
                    >
                      Hapus babak
                    </Button>
                  </div>
                </article>
              );
            })}
          </div>

          <details className="disclosure">
            <summary>Buat babak berikutnya</summary>
            <p className="muted small">
              Pilih kandidat untuk babak baru. Nama dan informasi kandidat
              disimpan sebagai salinan agar hasil babak sebelumnya tidak berubah.
            </p>
            <div className="round-candidate-list">
              {candidates
                .filter((candidate) => candidate.active)
                .map((candidate) => (
                  <Checkbox
                    key={candidate.id}
                    label={candidate.name}
                    checked={selectedIds.includes(candidate.id)}
                    disabled={!canChangeRound}
                    onChange={(event) => {
                      const checked = event.currentTarget.checked;
                      setSelectedIds((current) =>
                        checked
                          ? [...current, candidate.id]
                          : current.filter((id) => id !== candidate.id),
                      );
                    }}
                  />
                ))}
            </div>
            {candidates.every((candidate) => !candidate.active) && (
              <p className="muted small">Aktifkan kandidat terlebih dahulu.</p>
            )}
            <Button
              className="round-create-button"
              disabled={!canChangeRound || selectedIds.length === 0}
              onClick={() => void handleCreate()}
            >
              {busy ? "Membuat…" : "Buat dan aktifkan babak"}
            </Button>
          </details>
          {election.election_state !== "closed" && (
            <p className="muted small">
              Tutup pemilihan sebelum membuat atau mengganti babak.
            </p>
          )}
        </>
      )}
      <Notice kind="error">{error}</Notice>
    </Panel>
  );
}
