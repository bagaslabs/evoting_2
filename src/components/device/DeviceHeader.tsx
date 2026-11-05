import { Brand } from "../Brand";
import { Button } from "../ui/Button";

interface DeviceHeaderProps {
  connection: string;
  onChangeToken: () => void;
}

export function DeviceHeader({ connection, onChangeToken }: DeviceHeaderProps) {
  return (
    <header className="device-header">
      <Brand />
      <div className="device-header-actions">
        <span className="muted small">{connection}</span>
        <Button size="sm" variant="secondary" onClick={onChangeToken}>
          Ganti token
        </Button>
      </div>
    </header>
  );
}
