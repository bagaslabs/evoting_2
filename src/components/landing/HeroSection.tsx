import { Link } from "react-router";

export function HeroSection() {
  return (
    <div className="hero-copy">
      <p className="hero-kicker">Pemilihan Ketua Angkatan 2026</p>
      <h1>Suara Anda menentukan arah angkatan.</h1>
      <p className="hero-lead">
        Pemungutan suara dilakukan melalui perangkat yang telah didaftarkan
        panitia. Setiap suara tercatat rahasia, dan hanya hasil agregat yang
        dipublikasikan.
      </p>
      <div className="hero-actions">
        <Link className="btn btn-primary btn-lg" to="/device">
          Buka perangkat voting
        </Link>
        <Link className="btn btn-secondary btn-lg" to="/results">
          Lihat hasil pemilihan
        </Link>
      </div>
      <p className="hero-footnote">Universitas Jember, Teknik Elektro</p>
    </div>
  );
}
