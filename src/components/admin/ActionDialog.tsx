import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "../ui/Button";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Modal } from "../ui/Modal";
import { Notice } from "../ui/Notice";

export interface ActionDialogConfig {
  title: string;
  description: string;
  confirmLabel: string;
  mode: "confirm" | "prompt";
  tone?: "primary" | "danger";
  inputLabel?: string;
  inputPlaceholder?: string;
  confirmationText?: string;
}

interface ActionDialogProps {
  config: ActionDialogConfig;
  onCancel: () => void;
  onSubmit: (value: string) => Promise<void>;
}

export function ActionDialog({ config, onCancel, onSubmit }: ActionDialogProps) {
  const [value, setValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setValue("");
    setError(null);
  }, [config]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (config.mode === "prompt" && !value.trim()) {
      setError("Isian ini wajib diisi.");
      return;
    }
    if (
      config.confirmationText &&
      value.trim() !== config.confirmationText
    ) {
      setError(`Ketik "${config.confirmationText}" untuk mengonfirmasi.`);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await onSubmit(value.trim());
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open
      title={config.title}
      description={config.description}
      onClose={() => {
        if (!busy) onCancel();
      }}
    >
      <form className="stack" onSubmit={handleSubmit}>
        {config.mode === "prompt" && (
          <Field
            label={config.inputLabel ?? "Alasan"}
            htmlFor="action-dialog-input"
          >
            <Input
              id="action-dialog-input"
              value={value}
              onChange={(event) => setValue(event.currentTarget.value)}
              placeholder={config.inputPlaceholder}
              data-autofocus
              required
            />
          </Field>
        )}
        <Notice kind="error">{error}</Notice>
        <div className="modal-actions">
          <Button
            type="button"
            variant="secondary"
            onClick={onCancel}
            disabled={busy}
          >
            Batal
          </Button>
          <Button
            type="submit"
            variant={config.tone ?? "primary"}
            disabled={busy}
          >
            {busy ? "Memproses…" : config.confirmLabel}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
