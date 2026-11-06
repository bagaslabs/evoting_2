import { Link } from "react-router";

export function Brand({ suffix = "Teknik Elektro" }: { suffix?: string }) {
  return (
    <Link to="/" className="brand">
      <span className="brand-text">
        E-Voting <span>{suffix}</span>
      </span>
    </Link>
  );
}
