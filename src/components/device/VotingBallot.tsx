import type { DeviceCandidate, VerifiedVoter } from "../../types/election";
import { safeImageUrl } from "../../utils/format";
import { Button } from "../ui/Button";

interface VotingBallotProps {
  candidates: DeviceCandidate[];
  voter: Pick<VerifiedVoter, "nama" | "nim">;
  onSelect: (candidate: DeviceCandidate) => void;
}

export function VotingBallot({
  candidates,
  voter,
  onSelect,
}: VotingBallotProps) {
  return (
    <div className="voting-ballot">
      <aside className="voter-identity-overlay" aria-label="Identitas pemilih">
        <strong>{voter.nama}</strong>
        <span>NIM: {voter.nim}</span>
      </aside>
      <p className="section-marker">Pilih satu kandidat</p>
      <h2>Pilihan Anda bersifat rahasia.</h2>
      <p className="muted">
        Perhatikan informasi setiap kandidat. Suara tidak dapat diubah setelah dikirim.
      </p>

      <div className="ballot-list">
        {candidates.length === 0 && (
          <p className="muted">Belum ada kandidat aktif. Hubungi admin.</p>
        )}
        {candidates.map((candidate, index) => {
          const image = safeImageUrl(candidate.image_url);
          return (
            <article className="candidate-card" key={candidate.id}>
              <div className="candidate-photo">
                {image ? (
                  <img
                    className="candidate-image"
                    src={image}
                    alt={`Foto ${candidate.name}`}
                  />
                ) : (
                  <div className="candidate-placeholder" aria-hidden="true">
                    ?
                  </div>
                )}
                <span className="candidate-number">{index + 1}</span>
              </div>
              <div className="candidate-copy">
                <h3>{candidate.name}</h3>
                {candidate.show_vision_mission && (
                  <>
                    <strong>Visi</strong>
                    <p>{candidate.vision || "-"}</p>
                    <strong>Misi</strong>
                    <p>{candidate.mission || "-"}</p>
                  </>
                )}
              </div>
              <Button
                className="vote-button"
                onClick={() => onSelect(candidate)}
              >
                Pilih kandidat ini
              </Button>
            </article>
          );
        })}
      </div>
    </div>
  );
}
