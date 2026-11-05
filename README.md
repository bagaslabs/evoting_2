# E-Voting Ketua Angkatan Teknik Elektro

Aplikasi pemilihan Ketua Angkatan Teknik Elektro Universitas Jember. Frontend
React 19 + Vite + TypeScript dengan Supabase sebagai backend autentikasi, RPC,
realtime, dan penyimpanan foto kandidat.

## Fitur

- Landing page publik dan halaman hasil pemilihan.
- Login superadmin dan dashboard pemilihan.
- Kontrol status pemilihan: buka, jeda, lanjutkan, dan tutup.
- Pengaturan publikasi hasil serta persentase partisipasi.
- Manajemen perangkat voting: daftar, aktif/nonaktif, rotasi token, salin token,
  assign pemilih berikutnya, dan paksa lepas assignment.
- Pengelolaan antrean ada di dashboard `/admin`, pada panel "Assignment aktif"
  dan "Impor data dan antrean". Papan antrean khusus tersedia di
  `/admin/queue`, dengan jalur otomatis per perangkat aktif. Assignment
  antrean menjadi informasi; perangkat aktif dapat melayani NIM eligible yang
  belum memilih. Publik dapat melihat tiga digit akhir NIM yang sedang dilayani
  dan nama perangkat di `/antrian`.
- Roster pemilih: pencarian, tambah, hapus satu atau semua peserta, impor JSON,
  pengaturan urutan antrean, serta pengaturan status eligible. Penghapusan
  massal mempertahankan surat suara anonim, tetapi menghapus catatan partisipasi
  per pemilih. Status eligible yang diatur manual tetap berlaku saat roster
  diimpor ulang.
- Manajemen kandidat: tambah, ubah, aktif/nonaktif, unggah/hapus foto.
- Audit log, pembaruan realtime dengan fallback polling 15 detik, dan ubah kata
  sandi admin.
- Alur perangkat: token, verifikasi NIM, biodata, pemilihan kandidat, konfirmasi,
  hitung mundur 5 detik, dan pemutusan perangkat.

## Rute

| Rute           | Halaman                       |
| -------------- | ----------------------------- |
| `/`            | Landing page                  |
| `/admin`       | Login atau dashboard admin    |
| `/admin/login` | Login admin                   |
| `/admin/queue` | Papan antrean admin per perangkat |
| `/device`      | Perangkat voting              |
| `/antrian`     | Tiga digit akhir NIM yang sedang dilayani per perangkat |
| `/results`     | Hasil pemilihan publik        |
| `/results/babak-1` | Hasil babak tertentu       |
| `*`            | Halaman tidak ditemukan       |

## Persiapan

1. Install dependency:

   ```bash
   bun install
   ```

2. Salin `.env.example` menjadi `.env`, lalu isi:

   ```env
   SUPABASE_URL=https://project.supabase.co
   SUPABASE_PUBLISHABLE_KEY=...

   SUPABASE_SECRET_KEY=
   SUPABASE_JWKS_URL=
   ```

   Hanya `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` yang dipetakan ke
   browser. `SUPABASE_SECRET_KEY` hanya untuk tooling/server-side dan tidak
   boleh diekspos ke frontend atau ke variabel `VITE_*`.

3. Terapkan migrasi di folder `supabase/migrations` ke project Supabase.
   Setiap babak menyimpan suara dan hasil secara terpisah; admin dapat memberi
   nama babak sendiri, mengubah namanya, dan memilih kandidat dari dashboard.
   Hasil tersedia melalui URL internal seperti `/results/babak-1`.

4. Jalankan aplikasi:

   ```bash
   bun run dev
   ```

## Perintah

| Perintah       | Keterangan                        |
| -------------- | --------------------------------- |
| `bun run dev`  | Menjalankan development server    |
| `bun run build`| Typecheck dan build produksi      |
| `bun run test` | Menjalankan unit test             |
| `bun run lint` | Menjalankan ESLint                |
| `bun run preview` | Pratinjau hasil build          |

## Struktur Singkat

```text
src/
  app/          Konfigurasi router
  components/
    ui/         Komponen umum (button, input, modal, dll.)
    admin/      Komponen khusus dashboard admin
    device/     Komponen khusus perangkat voting
    landing/    Komponen landing page
    results/    Komponen halaman hasil
  lib/          Klien Supabase
  pages/        Halaman aplikasi
  services/     Operasi auth, RPC, dan storage
  types/        Tipe domain
  utils/        Utilitas bersama
supabase/
  migrations/   Skema dan fungsi database
  tests/        SQL test kontrak transaksi
tests/          Unit test frontend
```
