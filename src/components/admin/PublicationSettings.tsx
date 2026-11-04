import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import type { ElectionSettings } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Checkbox";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";

interface PublicationSettingsProps {
  election: ElectionSettings;
  onSave: (published: boolean, showParticipation: boolean) => Promise<void>;
}

export function PublicationSettings({ election, onSave }: PublicationSettingsProps) {
  const [published, setPublished] = useState(election.results_published);
  const [participation, setParticipation] = useState(
    election.show_public_participation,
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setPublished(election.results_published);
    setParticipation(election.show_public_participation);
  }, [election.results_published, election.show_public_participation]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await onSave(published, participation);
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title="Publikasi hasil"
      description="Publikasi tidak berubah otomatis saat pemilihan ditutup."
    >
      <form className="publication-control" onSubmit={handleSubmit}>
        <Checkbox
          label="Publikasikan hasil pemilihan"
          checked={published}
          onChange={(event) => setPublished(event.currentTarget.checked)}
        />
        <Checkbox
          label="Tampilkan persentase partisipasi pada hasil publik"
          checked={participation}
          onChange={(event) => setParticipation(event.currentTarget.checked)}
        />
        <Notice kind="error">{error}</Notice>
        <Button type="submit" variant="secondary" disabled={busy}>
          {busy ? "Menyimpan…" : "Simpan pengaturan hasil"}
        </Button>
      </form>
    </Panel>
  );
}
