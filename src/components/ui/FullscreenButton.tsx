import { useEffect, useState, type RefObject } from "react";
import { getErrorMessage } from "../../utils/errors";
import { Button } from "./Button";

interface FullscreenButtonProps {
  targetRef: RefObject<HTMLElement | null>;
}

export function FullscreenButton({ targetRef }: FullscreenButtonProps) {
  const [fullscreen, setFullscreen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const syncFullscreen = () => {
      setFullscreen(document.fullscreenElement === targetRef.current);
    };

    document.addEventListener("fullscreenchange", syncFullscreen);
    return () => document.removeEventListener("fullscreenchange", syncFullscreen);
  }, [targetRef]);

  const toggleFullscreen = async () => {
    setError(null);
    try {
      if (document.fullscreenElement === targetRef.current) {
        await document.exitFullscreen();
      } else if (targetRef.current?.requestFullscreen) {
        await targetRef.current.requestFullscreen();
      } else {
        throw new Error("Mode layar penuh tidak didukung oleh browser ini.");
      }
    } catch (fullscreenError) {
      setError(getErrorMessage(fullscreenError));
    }
  };

  return (
    <span className="fullscreen-control">
      <Button
        variant="secondary"
        size="sm"
        onClick={() => void toggleFullscreen()}
        aria-pressed={fullscreen}
      >
        {fullscreen ? "Keluar layar penuh" : "Layar penuh"}
      </Button>
      {error && (
        <span className="fullscreen-error" role="alert">
          {error}
        </span>
      )}
    </span>
  );
}
