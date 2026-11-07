import type { Candidate, CandidateInput } from "../../types/election";
import { Panel } from "../ui/Panel";
import { CandidateForm } from "./CandidateForm";

interface CandidatePanelProps {
  candidates: Candidate[];
  totalBallots: number;
  onSave: (input: CandidateInput, existing: Candidate | null) => Promise<void>;
  onDelete: (candidate: Candidate) => void;
}

export function CandidatePanel({
  candidates,
  totalBallots,
  onSave,
  onDelete,
}: CandidatePanelProps) {
  return (
    <Panel
      title="Kandidat"
      description="Tambah, ubah, atau nonaktifkan kandidat. Kandidat yang belum pernah dipakai dapat dihapus."
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
            onDelete={onDelete}
          />
        ))}
        <CandidateForm onSubmit={onSave} />
      </div>
    </Panel>
  );
}
