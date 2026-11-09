import { useState } from "react";
import { Link } from "react-router";
import type { Candidate, ElectionRound, ElectionSettings, RoundArchive } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Checkbox";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface ElectionRoundsPanelProps {
  election: ElectionSettings;
  rounds: ElectionRound[];
  candidates: Candidate[];
  onCreate: (title: string, candidateIds: string[]) => Promise<void>;
  onSelect: (roundId: string) => Promise<void>;
  onDelete: (round: ElectionRound) => void;
  onRename: (round: ElectionRound) => void;
  onExport: (roundNumber: number) => Promise<RoundArchive>;
}

export function ElectionRoundsPanel({
  election,
  rounds,
  candidates,
  onCreate,
  onSelect,
  onDelete,
  onRename,
  onExport,
}: ElectionRoundsPanelProps) {
  const [selectedIds, setSelectedIds] = useState<string[]>(() =>
    candidates.filter((candidate) => candidate.active).map(({ id }) => id),
  );
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [exportingRound, setExportingRound] = useState<number | null>(null);

  const canChangeRound =
    election.election_state === "closed" && busy === false;

  async function handleCreate() {
    setBusy(true);
    setError(null);
    try {
      await onCreate(title.trim(), selectedIds);
      setTitle("");
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

  async function handleExport(round: ElectionRound) {
    setExportingRound(round.round_number);
    setError(null);
    try {
      const archive = await onExport(round.round_number);
      const blob = new Blob([JSON.stringify(archive, null, 2)], {
        type: "application/json;charset=utf-8",
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `arsip-babak-${round.round_number}.json`;
      link.click();
      URL.revokeObjectURL(url);
    } catch (exportError) {
      setError(getErrorMessage(exportError));
    } finally {
      setExportingRound(null);
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
        <p className="muted small">Belum ada babak. Buat babak baru di bawah.</p>
      ) : (
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
                    variant="secondary"
                    disabled={exportingRound !== null}
                    onClick={() => void handleExport(round)}
                  >
                    {exportingRound === round.round_number
                      ? "Menyiapkan…"
                      : "Unduh arsip"}
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={!canChangeRound}
                    onClick={() => onRename(round)}
                  >
                    Ubah nama
                  </Button>
                  <Button
                    size="sm"
                    variant="danger"
                    disabled={!canChangeRound}
                    title={
                      isActive
                        ? "Babak lain akan otomatis diaktifkan. Jika ini satu-satunya babak, tidak ada babak aktif setelah dihapus."
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
      )}

      <details className="disclosure" open={rounds.length === 0}>
        <summary>Buat babak</summary>
        <p className="muted small">
          Tentukan nama babak dan pilih kandidat. Nama dan informasi kandidat
          disimpan sebagai salinan agar hasil babak sebelumnya tidak berubah.
        </p>
        <Field label="Nama babak" htmlFor="election-round-title">
          <Input
            id="election-round-title"
            value={title}
            onChange={(event) => setTitle(event.currentTarget.value)}
            placeholder="Contoh: Penyisihan"
            maxLength={80}
            required
            disabled={!canChangeRound}
          />
        </Field>
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
          disabled={!canChangeRound || !title.trim() || selectedIds.length === 0}
          onClick={() => void handleCreate()}
        >
          {busy ? "Membuat…" : "Buat dan aktifkan"}
        </Button>
      </details>
      {election.election_state !== "closed" && (
        <p className="muted small">
          Tutup pemilihan sebelum membuat atau mengganti babak.
        </p>
      )}
      <Notice kind="error">{error}</Notice>
    </Panel>
  );
}
