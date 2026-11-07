import { Link } from "react-router";

export function Brand({ suffix = "Ketua Angkatan" }: { suffix?: string }) {
  return (
    <Link to="/" className="brand">
      <span className="brand-text">
        Evoting <span>{suffix}</span>
      </span>
    </Link>
  );
}
