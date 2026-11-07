import type { RefObject } from "react";
import { Brand } from "../Brand";
import { Button } from "../ui/Button";
import { FullscreenButton } from "../ui/FullscreenButton";

interface DeviceHeaderProps {
  connection: string;
  onChangeToken: () => void;
  fullscreenTarget: RefObject<HTMLElement | null>;
}

export function DeviceHeader({
  connection,
  onChangeToken,
  fullscreenTarget,
}: DeviceHeaderProps) {
  return (
    <header className="device-header">
      <Brand />
      <div className="device-header-actions">
        <span className="muted small">{connection}</span>
        <FullscreenButton targetRef={fullscreenTarget} />
        <Button size="sm" variant="secondary" onClick={onChangeToken}>
          Ganti token
        </Button>
      </div>
    </header>
  );
}
