import { Link } from "react-router";

export function Brand({ suffix = "Teknik Elektro" }: { suffix?: string }) {
  return (
    <Link to="/" className="brand">
      E-Voting <span>{suffix}</span>
    </Link>
  );
}
