import { useState } from "react";
import type { ElectionState } from "../../types/election";
import { Button } from "../ui/Button";
import { Panel } from "../ui/Panel";

interface ElectionControlsProps {
  state: ElectionState;
  onChange: (state: ElectionState) => Promise<void>;
}

export function ElectionControls({ state, onChange }: ElectionControlsProps) {
  const [busy, setBusy] = useState<ElectionState | null>(null);

  async function handleChange(next: ElectionState) {
    setBusy(next);
    try {
      await onChange(next);
    } finally {
      setBusy(null);
    }
  }

  return (
    <Panel
      title="Status pemilihan"
      description="Buka, jeda, lanjutkan, atau tutup pemilihan. Perubahan berlaku seketika untuk semua perangkat."
    >
      <div className="button-row">
        <Button
          disabled={state !== "closed" || busy !== null}
          onClick={() => handleChange("open")}
        >
          {busy === "open" ? "Membuka…" : "Buka pemilihan"}
        </Button>
        <Button
          variant="secondary"
          disabled={state !== "open" || busy !== null}
          onClick={() => handleChange("paused")}
        >
          {busy === "paused" ? "Menjeda…" : "Jeda"}
        </Button>
        <Button
          variant="secondary"
          disabled={state !== "paused" || busy !== null}
          onClick={() => handleChange("open")}
        >
          Lanjutkan
        </Button>
        <Button
          variant="danger"
          disabled={state === "closed" || busy !== null}
          onClick={() => handleChange("closed")}
        >
          {busy === "closed" ? "Menutup…" : "Tutup pemilihan"}
        </Button>
      </div>
    </Panel>
  );
}
