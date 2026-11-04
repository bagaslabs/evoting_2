import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import type { QueueOrderItem } from "../../types/election";
import { getErrorMessage } from "../../utils/errors";
import { parseQueueOrder } from "../../utils/voter-data";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Panel } from "../ui/Panel";
import { Textarea } from "../ui/Textarea";

interface ImportPanelProps {
  queueOrder: QueueOrderItem[];
  onImport: (file: File) => Promise<void>;
  onSaveQueue: (nims: string[]) => Promise<void>;
}

export function ImportPanel({ queueOrder, onImport, onSaveQueue }: ImportPanelProps) {
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState<string | null>(null);
  const [queueText, setQueueText] = useState(
    queueOrder.map((voter) => voter.nim).join("\n"),
  );
  const [savingQueue, setSavingQueue] = useState(false);
  const [queueError, setQueueError] = useState<string | null>(null);

  useEffect(() => {
    setQueueText(queueOrder.map((voter) => voter.nim).join("\n"));
  }, [queueOrder]);

  async function handleImport(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const file = new FormData(form).get("file");
    if (!(file instanceof File) || file.size === 0) {
      setImportError("Pilih file JSON terlebih dahulu.");
      return;
    }

    setImporting(true);
    setImportError(null);
    try {
      await onImport(file);
      form.reset();
    } catch (submitError) {
      setImportError(getErrorMessage(submitError));
    } finally {
      setImporting(false);
    }
  }

  async function handleSaveQueue(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSavingQueue(true);
    setQueueError(null);
    try {
      await onSaveQueue(parseQueueOrder(queueText));
    } catch (submitError) {
      setQueueError(getErrorMessage(submitError));
    } finally {
      setSavingQueue(false);
    }
  }

  return (
    <Panel
      title="Impor data dan antrean"
      description="Urutan awal pemilih mengikuti urutan array JSON yang diimpor."
    >
      <form className="inline-form" onSubmit={handleImport}>
        <Field label="Impor file JSON" htmlFor="voter-import-file">
          <Input
            id="voter-import-file"
            name="file"
            type="file"
            accept=".json,application/json"
            required
          />
        </Field>
        <Button type="submit" variant="secondary" disabled={importing}>
          {importing ? "Mengimpor…" : "Impor roster"}
        </Button>
      </form>
      <Notice kind="error">{importError}</Notice>

      <details className="disclosure">
        <summary>Atur urutan global sebelum pemilihan dibuka</summary>
        <form className="stack queue-editor" onSubmit={handleSaveQueue}>
          <p className="muted small">
            Satu NIM per baris. NIM harus ditulis sebagai string di file JSON
            agar nol di depan tidak hilang.
          </p>
          <Field label="Urutan antrean" htmlFor="queue-order">
            <Textarea
              id="queue-order"
              rows={8}
              value={queueText}
              onChange={(event) => setQueueText(event.currentTarget.value)}
            />
          </Field>
          <Notice kind="error">{queueError}</Notice>
          <Button type="submit" variant="secondary" disabled={savingQueue}>
            {savingQueue ? "Menyimpan…" : "Simpan urutan"}
          </Button>
        </form>
      </details>
    </Panel>
  );
}
