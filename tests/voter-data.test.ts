import { describe, expect, test } from "bun:test";
import { normalizeVoterImport, parseQueueOrder } from "../src/utils/voter-data";

describe("voter data helpers", () => {
  test("normalizes the provided API envelope and retains NIM as a string", () => {
    const voters = normalizeVoterImport({
      status: "success",
      data: {
        nim: "001",
        nama: "Bagas Wicaksono",
        jenis_kelamin: "L",
        tanggal_masuk: "2026-08-18",
        status_saat_ini: "Aktif-2026/2027 Ganjil",
      },
    });

    expect(voters[0].nim).toBe("001");
    expect(Object.keys(voters[0])).toEqual([
      "nim",
      "nama",
      "jenis_kelamin",
      "tanggal_masuk",
      "status_saat_ini",
    ]);
  });

  test("normalizes arrays and rejects duplicate NIM values", () => {
    const records = normalizeVoterImport([
      { nim: "01", nama: "First" },
      { nim: "02", nama: "Second" },
    ]);

    expect(records.map(({ nim }) => nim)).toEqual(["01", "02"]);
    expect(() =>
      normalizeVoterImport([
        { nim: "1", nama: "A" },
        { nim: "1", nama: "B" },
      ]),
    ).toThrow(/lebih dari satu kali/);
  });

  test("parses a configured global queue without changing its order", () => {
    expect(parseQueueOrder("001\r\n002\n003")).toEqual(["001", "002", "003"]);
    expect(() => parseQueueOrder("001\n001")).toThrow(
      /tidak boleh memuat NIM yang sama/,
    );
  });
});
