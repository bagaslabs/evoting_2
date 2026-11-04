import { Link } from "react-router";
import { Brand } from "../Brand";
import { Button } from "../ui/Button";

export function AdminHeader({ onLogout }: { onLogout: () => void }) {
  return (
    <header className="site-header admin-header">
      <Brand suffix="Admin" />
      <div className="header-actions">
        <Link to="/results" target="_blank" rel="noreferrer">
          Pratinjau hasil
        </Link>
        <Button size="sm" variant="secondary" onClick={onLogout}>
          Keluar
        </Button>
      </div>
    </header>
  );
}
