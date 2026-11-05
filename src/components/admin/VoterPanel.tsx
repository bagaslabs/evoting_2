import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import type { AdminVoter, ElectionSettings } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface VoterPanelProps {
  election: ElectionSettings;
  voters: AdminVoter[];
  canReorder: boolean;
  onAdd: (input: {
    nim: string;
    nama: string;
    jenisKelamin: string;
    tanggalMasuk: string;
    statusSaatIni: string;
  }) => Promise<void>;
  onDelete: (voter: AdminVoter) => void;
  onDeleteAll: () => void;
  onChangeEligibility: (voter: AdminVoter) => void;
  onReorder: (nim: string, position: number) => Promise<void>;
}

function getVoterStatus(voter: AdminVoter) {
  if (!voter.eligible) return "Tidak eligible";
  if (voter.has_voted) return "Sudah memilih · pilihan rahasia";
  if (voter.device_name) return `Antre di ${voter.device_name}`;
  if (voter.queue_state === "waiting") return "Menunggu loket";
  return "Belum diproses";
}

export function VoterPanel({
  election,
  voters,
  canReorder,
  onAdd,
  onDelete,
  onDeleteAll,
  onChangeEligibility,
  onReorder,
}: VoterPanelProps) {
  const [search, setSearch] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const query = search.trim().toLocaleLowerCase("id-ID");
  const filtered = voters.filter((voter) =>
    `${voter.nama} ${voter.nim} ${voter.device_name ?? ""} ${getVoterStatus(voter)}`
      .toLocaleLowerCase("id-ID")
      .includes(query),
  );

  async function handleAdd(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setBusy(true);
    setError(null);

    try {
      await onAdd({
        nim: String(data.get("nim") ?? "").trim(),
        nama: String(data.get("nama") ?? "").trim(),
        jenisKelamin: String(data.get("jenis_kelamin") ?? "").trim(),
        tanggalMasuk: String(data.get("tanggal_masuk") ?? ""),
        statusSaatIni: String(data.get("status_saat_ini") ?? "").trim(),
      });
      form.reset();
    } catch (addError) {
      setError(getErrorMessage(addError));
    } finally {
      setBusy(false);
    }
  }

  const addDisabled = election.election_state !== "closed";

  return (
    <Panel
      title="Roster pemilih"
      description="Pilihan kandidat tetap rahasia. Status eligible tiap peserta dapat diatur dari daftar."
      aside={
        <div className="voter-panel-actions">
          <span className="muted small">{voters.length} pemilih</span>
          <Button
            size="sm"
            variant="danger"
            onClick={onDeleteAll}
            disabled={election.election_state !== "closed" || voters.length === 0}
          >
            Hapus semua pemilih
          </Button>
        </div>
      }
    >
      <details className="disclosure">
        <summary>Tambah pemilih</summary>
        <form className="voter-add-form" onSubmit={handleAdd}>
          <Field label="Nama" htmlFor="voter-nama">
            <Input id="voter-nama" name="nama" required />
          </Field>
          <Field label="NIM" htmlFor="voter-nim-add">
            <Input id="voter-nim-add" name="nim" required />
          </Field>
          <Field label="Jenis kelamin" htmlFor="voter-jenis-kelamin">
            <Input id="voter-jenis-kelamin" name="jenis_kelamin" />
          </Field>
          <Field label="Tanggal masuk" htmlFor="voter-tanggal-masuk">
            <Input id="voter-tanggal-masuk" name="tanggal_masuk" type="date" />
          </Field>
          <Field label="Status saat ini" htmlFor="voter-status">
            <Input
              id="voter-status"
              name="status_saat_ini"
              placeholder="Aktif-2026/2027 Ganjil"
            />
          </Field>
          <Button type="submit" disabled={addDisabled || busy}>
            {busy ? "Menambahkan…" : "Tambah pemilih"}
          </Button>
        </form>
        {addDisabled && (
          <p className="muted small">
            Data hanya dapat ditambah saat pemilihan ditutup.
          </p>
        )}
        <Notice kind="error">{error}</Notice>
      </details>

      <label className="search-field">
        <span>Cari nama, NIM, loket, atau status</span>
        <Input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.currentTarget.value)}
          placeholder="Ketik untuk mencari…"
        />
      </label>

      <div className="table-wrap roster-table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nama</th>
              <th>NIM</th>
              <th>Eligible</th>
              <th>Status antrean / voting</th>
              <th>Loket</th>
              <th>Urutan</th>
              <th>Ubah urutan</th>
              <th>Aksi</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 && (
              <tr>
                <td colSpan={8} className="muted">
                  {voters.length === 0
                    ? "Belum ada data pemilih."
                    : "Tidak ada pemilih yang sesuai pencarian."}
                </td>
              </tr>
            )}
            {filtered.map((voter) => (
              <tr key={voter.nim}>
                <td>{voter.nama}</td>
                <td>
                  <code>{voter.nim}</code>
                </td>
                <td>{voter.eligible ? "Ya" : "Tidak"}</td>
                <td>{getVoterStatus(voter)}</td>
                <td>{voter.device_name ?? "-"}</td>
                <td>{voter.queue_position}</td>
                <td>
                  <QueuePositionForm
                    nim={voter.nim}
                    position={voter.queue_position}
                    max={voters.length}
                    disabled={!canReorder}
                    onSubmit={onReorder}
                  />
                </td>
                <td>
                  <div className="button-row voter-actions">
                    <Button
                      size="sm"
                      variant={voter.eligible ? "danger" : "secondary"}
                      onClick={() => onChangeEligibility(voter)}
                    >
                      {voter.eligible ? "Jadikan non-eligible" : "Jadikan eligible"}
                    </Button>
                    <Button
                      size="sm"
                      variant="danger"
                      onClick={() => onDelete(voter)}
                      disabled={
                        election.election_state !== "closed" ||
                        voter.has_voted ||
                        voter.has_voted_any_round ||
                        voter.has_assignment_history
                      }
                      title="Pemilih yang sudah memilih di babak mana pun atau pernah mendapat assignment tidak dapat dihapus."
                    >
                      Hapus
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Panel>
  );
}

interface QueuePositionFormProps {
  nim: string;
  position: number;
  max: number;
  disabled: boolean;
  onSubmit: (nim: string, position: number) => Promise<void>;
}

function QueuePositionForm({
  nim,
  position,
  max,
  disabled,
  onSubmit,
}: QueuePositionFormProps) {
  const [value, setValue] = useState(position);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setValue(position);
  }, [position]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const next = Number(value);
    if (!Number.isInteger(next) || next < 1 || next > max) {
      setError(`Nomor antrean harus di antara 1 dan ${max}.`);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await onSubmit(nim, next);
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="queue-form" onSubmit={handleSubmit}>
      <Input
        type="number"
        min={1}
        max={max}
        value={value}
        onChange={(event) => setValue(Number(event.currentTarget.value))}
        aria-label={`Nomor antrean ${nim}`}
        disabled={disabled || busy}
      />
      <Button size="sm" variant="secondary" type="submit" disabled={disabled || busy}>
        Atur
      </Button>
      {error && <span className="field-error">{error}</span>}
    </form>
  );
}
