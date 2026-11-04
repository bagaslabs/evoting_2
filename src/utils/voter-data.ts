export interface VoterImportRecord {
  nim: string;
  nama: string;
  jenis_kelamin: string;
  tanggal_masuk: string;
  status_saat_ini: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function normalizeVoterImport(input: unknown): VoterImportRecord[] {
  let records: unknown = input;

  if (!Array.isArray(records) && isRecord(records) && records.status === "success") {
    records = records.data;
  }

  const list: unknown[] = Array.isArray(records) ? records : [records];

  if (list.length === 0) {
    throw new Error("File JSON tidak berisi data pemilih.");
  }

  const voters = list.map((item, index) => {
    const record = isRecord(item) && isRecord(item.data) ? item.data : item;

    if (!isRecord(record)) {
      throw new Error(`Data pemilih ke-${index + 1} tidak valid.`);
    }

    const nim = record.nim == null ? "" : String(record.nim).trim();
    const nama = typeof record.nama === "string" ? record.nama.trim() : "";

    if (!nim || !nama) {
      throw new Error(`Data pemilih ke-${index + 1} harus memiliki NIM dan nama.`);
    }

    return {
      nim,
      nama,
      jenis_kelamin:
        typeof record.jenis_kelamin === "string" ? record.jenis_kelamin.trim() : "",
      tanggal_masuk:
        typeof record.tanggal_masuk === "string" ? record.tanggal_masuk.trim() : "",
      status_saat_ini:
        typeof record.status_saat_ini === "string" ? record.status_saat_ini.trim() : "",
    };
  });

  const seen = new Set<string>();
  for (const voter of voters) {
    if (seen.has(voter.nim)) {
      throw new Error(`NIM ${voter.nim} muncul lebih dari satu kali.`);
    }
    seen.add(voter.nim);
  }

  return voters;
}

export function parseQueueOrder(value: string) {
  const nims = value
    .split(/\r?\n/)
    .map((nim) => nim.trim())
    .filter(Boolean);

  if (new Set(nims).size !== nims.length) {
    throw new Error("Urutan antrean tidak boleh memuat NIM yang sama lebih dari sekali.");
  }

  return nims;
}
