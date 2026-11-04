interface LoadingScreenProps {
  message?: string;
}

export function LoadingScreen({ message = "Memuat data pemilihan…" }: LoadingScreenProps) {
  return (
    <div className="loading-screen" role="status">
      <span className="spinner" aria-hidden="true" />
      <p>{message}</p>
    </div>
  );
}
