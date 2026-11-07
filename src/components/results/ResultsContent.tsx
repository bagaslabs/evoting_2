import type { PublicResults } from "../../types/election";
import { safeImageUrl } from "../../utils/format";
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

  const sortedCandidates = [...results.candidates].sort(
    (first, second) => second.votes - first.votes,
  );

  return (
    <div className="results-layout">
      <aside className="results-aside" aria-label="Analisis statistik">
        <h1 className="results-summary-title">Voting Results</h1>
        <div className="results-total">
          <span>Total suara</span>
          <strong>{results.total_votes.toLocaleString("id-ID")}</strong>
        </div>
        {"participation_percentage" in results && (
          <div className="results-total">
            <span>Partisipasi</span>
            <strong className="results-participation-value">
              {results.participation_voted !== undefined &&
              results.participation_eligible !== undefined ? (
                <>
                  <span>
                    {results.participation_voted.toLocaleString("id-ID")} dari{" "}
                    {results.participation_eligible.toLocaleString("id-ID")} pemilih
                  </span>
                  <small>{results.participation_percentage}%</small>
                </>
              ) : (
                `${results.participation_percentage}%`
              )}
            </strong>
          </div>
        )}
      </aside>

      <div className="results-main">
        <h1>{results.title}</h1>
        <div className="results-list">
          {sortedCandidates.length === 0 && (
            <p className="muted">Belum ada hasil untuk ditampilkan.</p>
          )}
          {sortedCandidates.map((candidate) => {
            const imageUrl = safeImageUrl(candidate.image_url);
            const initials = candidate.name
              .trim()
              .split(/\s+/)
              .slice(0, 2)
              .map((part) => part[0] ?? "")
              .join("")
              .toLocaleUpperCase();

            return (
              <article className="result-row" key={candidate.name}>
                <div className="result-label">
                  <div className="result-candidate">
                    <div className="result-avatar">
                      <span className="result-avatar-fallback" aria-hidden="true">
                        {initials}
                      </span>
                      {imageUrl && (
                        <img
                          src={imageUrl}
                          alt={`Foto ${candidate.name}`}
                          loading="lazy"
                          decoding="async"
                          onError={(event) => {
                            event.currentTarget.style.display = "none";
                          }}
                        />
                      )}
                    </div>
                    <strong>{candidate.name}</strong>
                  </div>
                  <span className="result-vote-summary">
                    <strong>{candidate.votes.toLocaleString("id-ID")}</strong>
                    <span>suara · {candidate.percentage}%</span>
                  </span>
                </div>
                <ProgressBar
                  percentage={candidate.percentage}
                  label={candidate.name}
                />
              </article>
            );
          })}
        </div>
      </div>
    </div>
  );
}
