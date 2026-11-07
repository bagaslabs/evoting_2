import { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "react-router";
import { ResultsContent } from "../components/results/ResultsContent";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { Button } from "../components/ui/Button";
import { FullscreenButton } from "../components/ui/FullscreenButton";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import { getPublicResults } from "../services/election";
import type { PublicResults } from "../types/election";
import { getErrorMessage } from "../utils/errors";

export default function ResultsPage() {
  const { roundSlug } = useParams();
  const pageRef = useRef<HTMLElement>(null);
  const [results, setResults] = useState<PublicResults | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      if (roundSlug === undefined) {
        setResults(await getPublicResults());
      } else {
        const match = /^babak-(\d+)$/.exec(roundSlug);
        if (!match) throw new Error("Alamat hasil babak tidak valid.");
        setResults(await getPublicResults(Number(match[1])));
      }
    } catch (loadError) {
      setError(getErrorMessage(loadError));
    } finally {
      setLoading(false);
    }
  }, [roundSlug]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <main className="page results-shell" ref={pageRef}>
      <SiteHeader suffix="Hasil publik" nav={[{ label: "Beranda", to: "/" }]} />
      <section className="panel results-panel">
        <div className="results-toolbar">
          <p className="section-marker">Hasil pemilihan</p>
          <div className="results-toolbar-actions">
            <FullscreenButton targetRef={pageRef} />
            <Button
              variant="secondary"
              size="sm"
              onClick={() => void load()}
              disabled={loading}
            >
              {loading ? "Memuat…" : "Muat ulang"}
            </Button>
          </div>
        </div>
        <Notice kind="error">{error}</Notice>
        {loading && !results ? (
          <LoadingScreen message="Memuat informasi hasil…" />
        ) : results ? (
          <ResultsContent results={results} />
        ) : null}
      </section>
      <SiteFooter>
        Hasil agregat. Tidak menampilkan identitas pemilih atau ballot individual.
      </SiteFooter>
    </main>
  );
}
