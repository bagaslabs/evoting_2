export function EmptyQueueStage() {
  return (
    <div className="device-message">
      <div className="empty-icon" aria-hidden="true">
        ✓
      </div>
      <h2>Tidak ada antrean berikutnya.</h2>
      <p className="muted">
        Terima kasih, seluruh pemilih dalam antrean telah diproses.
      </p>
    </div>
  );
}
