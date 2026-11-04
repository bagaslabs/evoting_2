import type { Candidate, CandidateInput } from "../../types/election";
import { Panel } from "../ui/Panel";
import { CandidateForm } from "./CandidateForm";

interface CandidatePanelProps {
  candidates: Candidate[];
  totalBallots: number;
  onSave: (input: CandidateInput, existing: Candidate | null) => Promise<void>;
}

export function CandidatePanel({
  candidates,
  totalBallots,
  onSave,
}: CandidatePanelProps) {
  return (
    <Panel
      title="Kandidat"
      description="Tambah, ubah, atau nonaktifkan kandidat. Kandidat tidak dihapus agar hasil agregat tetap utuh."
      aside={
        <span className="muted small">
          {candidates.length} kandidat · {totalBallots} suara tercatat
        </span>
      }
    >
      <div className="candidate-grid">
        {candidates.length === 0 && (
          <p className="muted">Belum ada kandidat.</p>
        )}
        {candidates.map((candidate) => (
          <CandidateForm
            key={`${candidate.id}-${candidate.image_url}`}
            candidate={candidate}
            onSubmit={onSave}
          />
        ))}
        <CandidateForm onSubmit={onSave} />
      </div>
    </Panel>
  );
}
