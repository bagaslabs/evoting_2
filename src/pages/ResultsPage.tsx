import { useCallback, useEffect, useState } from "react";
import { ResultsContent } from "../components/results/ResultsContent";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { Button } from "../components/ui/Button";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import { getPublicResults } from "../services/election";
import type { PublicResults } from "../types/election";
import { getErrorMessage } from "../utils/errors";

export default function ResultsPage() {
  const [results, setResults] = useState<PublicResults | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setResults(await getPublicResults());
    } catch (loadError) {
      setError(getErrorMessage(loadError));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <main className="page results-shell">
      <SiteHeader suffix="Hasil publik" nav={[{ label: "Beranda", to: "/" }]} />
      <section className="panel results-panel">
        <div className="results-toolbar">
          <p className="section-marker">Hasil pemilihan</p>
          <Button variant="secondary" size="sm" onClick={() => void load()} disabled={loading}>
            {loading ? "Memuat…" : "Muat ulang"}
          </Button>
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
