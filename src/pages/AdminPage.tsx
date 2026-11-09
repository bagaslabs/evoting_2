import { useCallback, useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { Link } from "react-router";
import { ActionDialog } from "../components/admin/ActionDialog";
import type { ActionDialogConfig } from "../components/admin/ActionDialog";
import { AdminHeader } from "../components/admin/AdminHeader";
import { SiteFooter } from "../components/SiteFooter";
import { AssignmentPanel } from "../components/admin/AssignmentPanel";
import { AuditPanel } from "../components/admin/AuditPanel";
import { CandidatePanel } from "../components/admin/CandidatePanel";
import { DashboardSummary } from "../components/admin/DashboardSummary";
import { DevicePanel } from "../components/admin/DevicePanel";
import { ElectionRoundsPanel } from "../components/admin/ElectionRoundsPanel";
import { ElectionControls } from "../components/admin/ElectionControls";
import { ImportPanel } from "../components/admin/ImportPanel";
import { LoginPanel } from "../components/admin/LoginPanel";
import { PublicationSettings } from "../components/admin/PublicationSettings";
import { VoterPanel } from "../components/admin/VoterPanel";
import { ElectionBadge } from "../components/ui/Badge";
import { LoadingScreen } from "../components/ui/LoadingScreen";
import { Notice } from "../components/ui/Notice";
import type { NoticeKind } from "../components/ui/Notice";
import { supabase } from "../lib/supabase";
import {
  addVoter,
  assignNextVoterToDevice,
  cancelQueueAssignment,
  changeAdminPassword,
  createElectionRound,
  createVotingDevice,
  deleteAllVoters,
  deleteCandidate,
  deleteElectionRound,
  deleteVotingDevice,
  deleteVoter,
  forceReleaseDevice,
  fetchRoundArchive,
  getCurrentSession,
  importVoters,
  isPermissionError,
  loadAdminData,
  renameElectionRound,
  rotateVotingDeviceToken,
  saveCandidate,
  setDeviceActive,
  selectElectionRound,
  setElectionState,
  setQueueOrder,
  setResultsPublication,
  setVoterEligibility,
  signInAdmin,
  signOutAdmin,
} from "../services/election";
import type {
  AdminData,
  AdminVoter,
  Candidate,
  CandidateInput,
  ElectionRound,
  ElectionState,
  QueueAssignment,
  VotingDevice,
} from "../types/election";
import { getErrorMessage } from "../utils/errors";
import { normalizeVoterImport } from "../utils/voter-data";

type AuthStatus = "loading" | "unauthenticated" | "authenticated";

interface NoticeState {
  kind: NoticeKind;
  message: string;
}

interface DialogRequest {
  config: ActionDialogConfig;
  action: (value: string) => Promise<void>;
}

export default function AdminPage() {
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [data, setData] = useState<AdminData | null>(null);
  const [notice, setNotice] = useState<NoticeState | null>(null);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [dialog, setDialog] = useState<DialogRequest | null>(null);
  const [realtimeStatus, setRealtimeStatus] = useState("Menghubungkan realtime…");
  const channelRef = useRef<RealtimeChannel | null>(null);

  const refresh = useCallback(async (force = false) => {
    const active = document.activeElement;
    if (
      !force &&
      active instanceof HTMLElement &&
      ["INPUT", "TEXTAREA"].includes(active.tagName) &&
      active.closest(".admin-shell")
    ) {
      return;
    }

    setData(await loadAdminData());
    setNotice(null);
  }, []);

  const endSession = useCallback(async () => {
    await signOutAdmin().catch(() => {});
    setData(null);
    setStatus("unauthenticated");
    setNotice(null);
    setDialog(null);
  }, []);

  const refreshSafely = useCallback(
    async (force = false) => {
      try {
        await refresh(force);
      } catch (error) {
        if (isPermissionError(error)) {
          await endSession();
          return;
        }
        setNotice({ kind: "error", message: getErrorMessage(error) });
      }
    },
    [refresh, endSession],
  );

  const refreshAfterAction = useCallback(async () => {
    try {
      await refresh(true);
      return true;
    } catch (error) {
      if (isPermissionError(error)) {
        await endSession();
        return false;
      }
      setNotice({ kind: "error", message: getErrorMessage(error) });
      return false;
    }
  }, [refresh, endSession]);

  useEffect(() => {
    let cancelled = false;

    async function boot() {
      try {
        const session = await getCurrentSession();
        if (!session) {
          if (!cancelled) setStatus("unauthenticated");
          return;
        }

        const next = await loadAdminData();
        if (cancelled) return;
        setData(next);
        setStatus("authenticated");
      } catch (error) {
        await signOutAdmin().catch(() => {});
        if (cancelled) return;
        setStatus("unauthenticated");
        setDialog(null);
        setLoginError(getErrorMessage(error));
      }
    }

    void boot();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (status !== "authenticated" || !supabase) return;

    const client = supabase;
    const channel = client
      .channel("admin-election-updates")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "audit_log" },
        () => void refreshSafely(false),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "queue_assignments" },
        () => void refreshSafely(false),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "voting_devices" },
        () => void refreshSafely(false),
      )
      .subscribe((channelStatus) => {
        setRealtimeStatus(
          channelStatus === "SUBSCRIBED"
            ? "Pembaruan langsung aktif"
            : `Realtime: ${channelStatus}`,
        );
      });

    channelRef.current = channel;
    const timer = window.setInterval(() => void refreshSafely(false), 15000);

    return () => {
      window.clearInterval(timer);
      channelRef.current = null;
      void client.removeChannel(channel);
    };
  }, [status, refreshSafely]);

  async function handleLogin(email: string, password: string) {
    setLoginError(null);
    await signInAdmin(email, password);

    try {
      const next = await loadAdminData();
      setData(next);
      setStatus("authenticated");
      setNotice(null);
    } catch (error) {
      await signOutAdmin().catch(() => {});
      throw error;
    }
  }

  async function handleLogout() {
    if (channelRef.current) {
      await supabase?.removeChannel(channelRef.current);
      channelRef.current = null;
    }
    await endSession();
  }

  async function handleElectionState(next: ElectionState) {
    try {
      await setElectionState(next);
      if (await refreshAfterAction()) {
        setNotice({ kind: "success", message: "Status pemilihan diperbarui." });
      }
    } catch (error) {
      if (isPermissionError(error)) {
        await endSession();
        return;
      }
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  async function handleCreateRound(title: string, candidateIds: string[]) {
    const round = await createElectionRound(title, candidateIds);
    if (await refreshAfterAction()) {
      setNotice({
        kind: "success",
        message: `${round.title} dibuat dan sekarang aktif.`,
      });
    }
  }

  async function handleSelectRound(roundId: string) {
    await selectElectionRound(roundId);
    if (await refreshAfterAction()) {
      setNotice({ kind: "success", message: "Babak aktif berhasil diganti." });
    }
  }

  async function handleSavePublication(published: boolean, participation: boolean) {
    await setResultsPublication(published, participation);
    if (await refreshAfterAction()) {
      setNotice({
        kind: "success",
        message: "Pengaturan hasil publik berhasil disimpan.",
      });
    }
  }

  async function handleCreateDevice(name: string) {
    await createVotingDevice(name);
    if (await refreshAfterAction()) {
      setNotice({
        kind: "success",
        message: "Perangkat dibuat. Kode token ditampilkan pada baris perangkat.",
      });
    }
  }

  async function handleToggleDevice(device: VotingDevice) {
    try {
      await setDeviceActive(device.id, !device.active);
      if (await refreshAfterAction()) {
        setNotice({ kind: "success", message: "Status perangkat diperbarui." });
      }
    } catch (error) {
      if (isPermissionError(error)) {
        await endSession();
        return;
      }
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  async function handleAssignNext(device: VotingDevice) {
    try {
      const result = await assignNextVoterToDevice(device.id);
      if (await refreshAfterAction()) {
        const message =
          result.status === "assigned"
            ? `Antrean global berikutnya diberikan ke ${device.name}.`
            : result.status === "waiting"
              ? "Belum ada pemilih berikutnya; perangkat menunggu."
              : "Tidak ada antrean berikutnya.";
        setNotice({ kind: "success", message });
      }
    } catch (error) {
      if (isPermissionError(error)) {
        await endSession();
        return;
      }
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  async function handleCopyToken(device: VotingDevice) {
    try {
      if (!device.token) throw new Error("Kode token perangkat tidak tersedia.");
      await navigator.clipboard.writeText(device.token);
      setNotice({
        kind: "success",
        message: "Kode perangkat disalin. Simpan kode tersebut secara aman.",
      });
    } catch (error) {
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  function openForceRelease(device: VotingDevice) {
    setDialog({
      config: {
        title: "Paksa lepas assignment",
        description: `Assignment aktif pada ${device.name} akan dilepas dan pemilih kembali ke antrean. Tindakan ini tercatat di audit log.`,
        confirmLabel: "Paksa lepas",
        tone: "danger",
        mode: "prompt",
        inputLabel: "Alasan",
        inputPlaceholder: "Contoh: perangkat macet",
      },
      action: async (reason) => {
        await forceReleaseDevice(device.id, reason);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({ kind: "success", message: "Assignment berhasil dilepas." });
        }
      },
    });
  }

  function openDeleteDevice(device: VotingDevice) {
    setDialog({
      config: {
        title: `Hapus perangkat ${device.name}?`,
        description:
          "Perangkat dan seluruh riwayat assignment-nya akan dihapus permanen. Pemilih dan suara tidak terhapus; antrean menunggu akan dibagikan ulang ke perangkat aktif yang tersisa. Pemilihan harus ditutup dan perangkat tidak boleh memiliki assignment aktif.",
        confirmLabel: "Hapus perangkat",
        tone: "danger",
        mode: "confirm",
      },
      action: async () => {
        await deleteVotingDevice(device.id);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `Perangkat ${device.name} berhasil dihapus.`,
          });
        }
      },
    });
  }

  function openCancelAssignment(assignment: QueueAssignment) {
    setDialog({
      config: {
        title: "Batalkan assignment",
        description: `${assignment.device_name} · ${assignment.nim} akan kembali ke antrean. Tindakan ini tercatat di audit log.`,
        confirmLabel: "Batalkan assignment",
        tone: "danger",
        mode: "prompt",
        inputLabel: "Alasan",
        inputPlaceholder: "Contoh: pemilih salah loket",
      },
      action: async (reason) => {
        await cancelQueueAssignment(assignment.id, reason);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({ kind: "success", message: "Assignment berhasil dibatalkan." });
        }
      },
    });
  }

  function openDeleteVoter(voter: AdminVoter) {
    setDialog({
      config: {
        title: `Hapus data pemilih ${voter.nim}?`,
        description: "Tindakan ini permanen dan tidak dapat dibatalkan.",
        confirmLabel: "Hapus pemilih",
        tone: "danger",
        mode: "confirm",
      },
      action: async () => {
        await deleteVoter(voter.nim);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({ kind: "success", message: "Data pemilih berhasil dihapus." });
        }
      },
    });
  }

  function openDeleteAllVoters() {
    const voterCount = data?.voters.length ?? 0;
    if (voterCount === 0) return;

    setDialog({
      config: {
        title: `Hapus semua ${voterCount} data pemilih?`,
        description:
          "Tindakan permanen ini menghapus roster pemilih, riwayat antrean, dan catatan partisipasi per pemilih di semua babak. Surat suara anonim dan perolehan suara tetap dipertahankan, tetapi persentase partisipasi dapat berubah. Pastikan pemilihan sudah ditutup.",
        confirmLabel: "Hapus semua pemilih",
        tone: "danger",
        mode: "confirm",
      },
      action: async () => {
        const deletedCount = await deleteAllVoters();
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `${deletedCount} data pemilih berhasil dihapus. Surat suara dan hasil tetap dipertahankan.`,
          });
        }
      },
    });
  }

  function openChangeVoterEligibility(voter: AdminVoter) {
    const nextEligible = !voter.eligible;
    setDialog({
      config: {
        title: nextEligible
          ? `Jadikan ${voter.nama} eligible?`
          : `Jadikan ${voter.nama} non-eligible?`,
        description: nextEligible
          ? voter.has_voted
            ? "Status eligible akan diaktifkan, tetapi peserta yang sudah memilih pada babak ini tetap tidak dapat memilih lagi."
            : "Peserta akan dimasukkan kembali ke antrean perangkat aktif."
          : voter.device_name
            ? `Assignment aktif pada ${voter.device_name} akan dicabut dan nomor antreannya dihapus. Peserta dapat dimasukkan kembali ke antrean dengan menjadikannya eligible.`
            : "Nomor peserta akan dihapus dari antrean. Peserta dapat dimasukkan kembali ke antrean dengan menjadikannya eligible.",
        confirmLabel: nextEligible ? "Jadikan eligible" : "Jadikan non-eligible",
        tone: nextEligible ? "primary" : "danger",
        mode: "confirm",
      },
      action: async () => {
        await setVoterEligibility(voter.nim, nextEligible);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `${voter.nama} sekarang ${nextEligible ? "eligible" : "non-eligible"}.`,
          });
        }
      },
    });
  }

  function openDeleteRound(round: ElectionRound) {
    setDialog({
      config: {
        title: `Hapus ${round.title}?`,
        description: `${
          round.id === data?.election.active_round_id
            ? "Babak ini sedang aktif. Babak lain yang tersisa akan otomatis diaktifkan, atau tidak ada babak aktif jika ini satu-satunya babak. "
            : ""
        }Semua suara dan hasil babak ini, konfigurasi kandidat, serta catatan partisipasinya akan dihapus permanen. Tindakan ini tidak dapat dibatalkan. Pemilihan harus ditutup terlebih dahulu. Ketik HAPUS untuk melanjutkan.`,
        confirmLabel: "Hapus babak",
        tone: "danger",
        mode: "prompt",
        inputLabel: 'Ketik "HAPUS" untuk mengonfirmasi',
        inputPlaceholder: "HAPUS",
        confirmationText: "HAPUS",
      },
      action: async () => {
        await deleteElectionRound(round.id);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `${round.title} berhasil dihapus.`,
          });
        }
      },
    });
  }

  function openRenameRound(round: ElectionRound) {
    setDialog({
      config: {
        title: `Ubah nama ${round.title}`,
        description: "Masukkan nama baru untuk babak ini.",
        confirmLabel: "Simpan nama",
        tone: "primary",
        mode: "prompt",
        inputLabel: "Nama babak",
        inputPlaceholder: round.title,
      },
      action: async (title) => {
        await renameElectionRound(round.id, title);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `Nama babak diperbarui menjadi ${title}.`,
          });
        }
      },
    });
  }

  function openRotateToken(device: VotingDevice) {
    setDialog({
      config: {
        title: `Buat kode baru untuk ${device.name}?`,
        description:
          "Kode lama tidak akan bisa digunakan lagi. Perangkat dan assignment antrean tidak terhapus.",
        confirmLabel: "Buat kode baru",
        mode: "confirm",
      },
      action: async () => {
        await rotateVotingDeviceToken(device.id);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: "success",
            message: `Kode baru untuk ${device.name} berhasil dibuat.`,
          });
        }
      },
    });
  }

  async function handleReorderVoter(nim: string, position: number) {
    if (!data) return;
    const nims = data.voters.map((voter) => voter.nim);
    const oldIndex = nims.indexOf(nim);
    if (oldIndex < 0) {
      throw new Error("Pemilih tidak ditemukan dalam urutan antrean.");
    }

    nims.splice(oldIndex, 1);
    nims.splice(position - 1, 0, nim);
    await setQueueOrder(nims);
    if (await refreshAfterAction()) {
      setNotice({ kind: "success", message: "Urutan antrean berhasil diperbarui." });
    }
  }

  async function handleAddVoter(input: {
    nim: string;
    nama: string;
    jenisKelamin: string;
    tanggalMasuk: string;
    statusSaatIni: string;
  }) {
    await addVoter(input);
    if (await refreshAfterAction()) {
      setNotice({ kind: "success", message: "Pemilih berhasil ditambahkan." });
    }
  }

  async function handleImport(file: File) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(await file.text());
    } catch {
      throw new Error("File JSON tidak valid.");
    }

    const voters = normalizeVoterImport(parsed);
    const count = await importVoters(voters);
    if (await refreshAfterAction()) {
      setNotice({
        kind: "success",
        message: `${count} data pemilih berhasil diimpor.`,
      });
    }
  }

  async function handleSaveQueue(nims: string[]) {
    await setQueueOrder(nims);
    if (await refreshAfterAction()) {
      setNotice({
        kind: "success",
        message: "Urutan antrean global berhasil disimpan.",
      });
    }
  }

  async function handleSaveCandidate(input: CandidateInput, existing: Candidate | null) {
    const result = await saveCandidate(input, existing?.image_url ?? "");
    if (await refreshAfterAction()) {
      setNotice(
        result.warning
          ? {
              kind: "warning",
              message: `Data kandidat berhasil disimpan.${result.warning}`,
            }
          : { kind: "success", message: "Data kandidat berhasil disimpan." },
      );
    }
  }

  function openDeleteCandidate(candidate: Candidate) {
    setDialog({
      config: {
        title: `Hapus kandidat ${candidate.name}?`,
        description:
          "Kandidat yang belum pernah masuk babak pemilihan dapat dihapus permanen. Kandidat yang sudah dipakai dalam babak atau memiliki suara harus dinonaktifkan agar hasil historis tetap utuh. Pemilihan harus ditutup.",
        confirmLabel: "Hapus kandidat",
        tone: "danger",
        mode: "confirm",
      },
      action: async () => {
        const warning = await deleteCandidate(candidate.id, candidate.image_url);
        const refreshed = await refreshAfterAction();
        setDialog(null);
        if (refreshed) {
          setNotice({
            kind: warning ? "warning" : "success",
            message: warning
              ? `Kandidat ${candidate.name} berhasil dihapus.${warning}`
              : `Kandidat ${candidate.name} berhasil dihapus.`,
          });
        }
      },
    });
  }

  async function handleChangePassword(currentPassword: string, nextPassword: string) {
    await changeAdminPassword(currentPassword, nextPassword);
    if (await refreshAfterAction()) {
      setNotice({ kind: "success", message: "Kata sandi berhasil diubah." });
    }
  }

  if (status === "loading") {
    return (
      <main className="page admin-loading">
        <LoadingScreen />
      </main>
    );
  }

  if (status === "unauthenticated" || !data) {
    return <LoginPanel onSubmit={handleLogin} initialError={loginError} />;
  }

  const canReorderVoters =
    data.election.election_state === "closed" &&
    !data.voters.some((voter) => voter.has_voted) &&
    data.assignments.length === 0;

  return (
    <main className="page admin-shell">
      <AdminHeader onLogout={handleLogout} />

      <section className="dashboard-heading">
        <div>
          <p className="section-marker">Dashboard superadmin</p>
          <h1>{data.election.title}</h1>
        </div>
        <ElectionBadge state={data.election.election_state} />
      </section>

      <Notice kind={notice?.kind}>{notice?.message}</Notice>
      <DashboardSummary statistics={data.statistics} />

      <ElectionRoundsPanel
        election={data.election}
        rounds={data.rounds}
        candidates={data.candidates}
        onCreate={handleCreateRound}
        onSelect={handleSelectRound}
        onDelete={openDeleteRound}
        onRename={openRenameRound}
        onExport={fetchRoundArchive}
      />

      <div className="admin-grid">
        <ElectionControls
          state={data.election.election_state}
          onChange={handleElectionState}
        />
        <PublicationSettings
          election={data.election}
          onSave={handleSavePublication}
        />
      </div>

      <div className="admin-grid">
        <DevicePanel
          election={data.election}
          devices={data.devices}
          onCreate={handleCreateDevice}
          onToggle={handleToggleDevice}
          onAssignNext={handleAssignNext}
          onForceRelease={openForceRelease}
          onDelete={openDeleteDevice}
          onRotateToken={openRotateToken}
          onCopyToken={handleCopyToken}
        />
        <AssignmentPanel
          assignments={data.assignments}
          onCancel={openCancelAssignment}
        />
      </div>

      <VoterPanel
        election={data.election}
        voters={data.voters}
        canReorder={canReorderVoters}
        onAdd={handleAddVoter}
        onDelete={openDeleteVoter}
        onDeleteAll={openDeleteAllVoters}
        onChangeEligibility={openChangeVoterEligibility}
        onReorder={handleReorderVoter}
      />

      <ImportPanel
        queueOrder={data.queue_order}
        onImport={handleImport}
        onSaveQueue={handleSaveQueue}
      />

      <CandidatePanel
        candidates={data.candidates}
        totalBallots={data.statistics.total_ballots}
        onSave={handleSaveCandidate}
        onDelete={openDeleteCandidate}
      />

      <AuditPanel
        auditLog={data.audit_log}
        realtimeStatus={realtimeStatus}
        onChangePassword={handleChangePassword}
      />

      <SiteFooter>
        <Link to="/">Beranda</Link> · Data ballot individual tidak ditampilkan.
      </SiteFooter>

      {dialog && (
        <ActionDialog
          config={dialog.config}
          onCancel={() => setDialog(null)}
          onSubmit={dialog.action}
        />
      )}
    </main>
  );
}
