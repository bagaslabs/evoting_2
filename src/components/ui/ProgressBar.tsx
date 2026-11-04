interface ProgressBarProps {
  percentage: number;
  label: string;
}

export function ProgressBar({ percentage, label }: ProgressBarProps) {
  const value = Math.min(100, Math.max(0, Number(percentage) || 0));

  return (
    <div className="progress-track" role="img" aria-label={`${label}: ${value} persen`}>
      <span style={{ width: `${value}%` }} />
    </div>
  );
}
