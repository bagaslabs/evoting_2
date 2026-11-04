import type { ElectionStatistics } from "../../types/election";

export function DashboardSummary({ statistics }: { statistics: ElectionStatistics }) {
  const items = [
    { label: "Pemilih eligible", value: statistics.eligible },
    { label: "Sudah memilih", value: statistics.voted },
    { label: "Sisa pemilih", value: statistics.remaining },
    { label: "Partisipasi", value: `${statistics.participation_percentage}%` },
  ];

  return (
    <section className="stats-grid" aria-label="Ringkasan pemilihan">
      {items.map((item) => (
        <article className="stat-card" key={item.label}>
          <span>{item.label}</span>
          <strong>{item.value}</strong>
        </article>
      ))}
    </section>
  );
}
