import { Brand } from "../Brand";

export function DeviceHeader({ connection }: { connection: string }) {
  return (
    <header className="device-header">
      <Brand />
      <span className="muted small">{connection}</span>
    </header>
  );
}
