import { Button } from "../ui/Button";

interface ThankYouStageProps {
  voterName: string;
  countdown: number;
  onBack: () => void;
}

export function ThankYouStage({
  voterName,
  countdown,
  onBack,
}: ThankYouStageProps) {
  return (
    <div className="thankyou">
      <div className="thankyou-icon" aria-hidden="true">
        ✓
      </div>
      <p className="section-marker">Suara tercatat</p>
      <h2>Terima kasih, {voterName}.</h2>
      <p className="muted">Suara Anda telah tercatat secara rahasia.</p>
      <p className="countdown">
        {countdown > 0
          ? `Kembali ke antrean dalam ${countdown} detik…`
          : "Memuat antrean berikutnya…"}
      </p>
      <Button variant="secondary" onClick={onBack}>
        Kembali ke antrean
      </Button>
    </div>
  );
}
