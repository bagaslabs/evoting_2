import { Link } from "react-router";
import { Brand } from "../Brand";
import { Button } from "../ui/Button";

interface AdminHeaderProps {
  onLogout: () => void;
  activePage?: "dashboard" | "queue";
}

export function AdminHeader({
  onLogout,
  activePage = "dashboard",
}: AdminHeaderProps) {
  return (
    <header className="site-header admin-header">
      <Brand suffix="Admin" />
      <div className="header-actions">
        {activePage === "dashboard" ? (
          <Link to="/admin/queue">Papan antrean</Link>
        ) : (
          <Link to="/admin">Dashboard</Link>
        )}
        <Link to="/antrian" target="_blank" rel="noreferrer">
          Antrean publik
        </Link>
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
