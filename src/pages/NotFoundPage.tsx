import { Link } from "react-router";

export default function NotFoundPage() {
  return (
    <main className="page not-found">
      <p className="section-marker">404</p>
      <h1>Halaman tidak ditemukan.</h1>
      <p className="muted">
        Alamat yang Anda buka tidak tersedia atau sudah dipindahkan.
      </p>
      <Link className="btn btn-primary" to="/">
        Kembali ke beranda
      </Link>
    </main>
  );
}
