import type { PublicResults } from "../../types/election";
import { ProgressBar } from "../ui/ProgressBar";

export function ResultsContent({ results }: { results: PublicResults }) {
  if (!results.published) {
    return (
      <div className="unpublished">
        <div className="lock-icon" aria-hidden="true">
          ◌
        </div>
        <h1>Hasil belum dipublikasikan</h1>
        <p className="muted">{results.message}</p>
      </div>
    );
  }

  return (
    <div>
      <h1>{results.title}</h1>
      <div className="results-total">
        <span>Total suara</span>
        <strong>{results.total_votes}</strong>
      </div>
      {"participation_percentage" in results && (
        <div className="results-total">
          <span>Partisipasi</span>
          <strong>{results.participation_percentage}%</strong>
        </div>
      )}

      <div className="results-list">
        {results.candidates.length === 0 && (
          <p className="muted">Belum ada hasil untuk ditampilkan.</p>
        )}
        {results.candidates.map((candidate) => (
          <article className="result-row" key={candidate.name}>
            <div className="result-label">
              <strong>{candidate.name}</strong>
              <span>
                {candidate.votes} suara · {candidate.percentage}%
              </span>
            </div>
            <ProgressBar
              percentage={candidate.percentage}
              label={candidate.name}
            />
          </article>
        ))}
      </div>
    </div>
  );
}
