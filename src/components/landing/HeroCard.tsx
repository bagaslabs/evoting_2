import { Link } from "react-router";

export function HeroCard() {
  return (
    <aside className="hero-card" aria-label="Informasi pemilihan">
      <span className="ballot-stub">Pemilihan 2026</span>
      <div className="ballot-body">
        <p className="status-line">
          <span className="status-dot" aria-hidden="true" />
          Informasi pemilih
        </p>
        <h2>Gunakan perangkat resmi panitia.</h2>
        <p>
          Hasil hanya ditampilkan setelah dipublikasikan admin. Pastikan Anda
          memilih di perangkat yang disiapkan panitia dan menjaga kerahasiaan
          suara.
        </p>
        <Link className="ballot-link" to="/results">
          Lihat halaman hasil publik
        </Link>
      </div>
      <span className="ballot-notch ballot-notch-top" aria-hidden="true" />
      <span className="ballot-notch ballot-notch-bottom" aria-hidden="true" />
    </aside>
  );
}
