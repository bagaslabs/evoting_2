import { useEffect, useState } from "react";
import { Brand } from "../components/Brand";
import { DeviceHeader } from "../components/device/DeviceHeader";
import { DeviceSetupForm } from "../components/device/DeviceSetupForm";
import {
  DeviceStageMessage,
  type DeviceIdleStage,
} from "../components/device/DeviceStageMessage";
import { ThankYouStage } from "../components/device/ThankYouStage";
import { VoterBiodata } from "../components/device/VoterBiodata";
import { VotingBallot } from "../components/device/VotingBallot";
import { ConfirmDialog } from "../components/ui/ConfirmDialog";
import { Notice } from "../components/ui/Notice";
import type { NoticeKind } from "../components/ui/Notice";
import {
  castVote,
  getCandidatesForDevice,
  pollVotingDevice,
  verifyVoterForDevice,
} from "../services/election";
import type {
  DeviceCandidate,
  DeviceStage,
  VerifiedVoter,
} from "../types/election";
import { DEVICE_TOKEN_KEY } from "../utils/constants";
import { getErrorMessage } from "../utils/errors";

interface DeviceNotice {
  kind: NoticeKind;
  message: string;
}

const VERIFY_MESSAGES: Record<string, string> = {
  nim_not_found:
    "Tidak ada pemilih dengan tiga digit terakhir NIM tersebut. Periksa kembali.",
  invalid_nim_suffix: "Masukkan tepat tiga angka terakhir NIM.",
  not_eligible: "NIM ini tidak memenuhi syarat untuk memilih.",
  already_voted: "NIM ini tercatat sudah memilih.",
  election_not_open: "Pemilihan sedang tidak dibuka.",
  device_inactive: "Perangkat dinonaktifkan admin.",
};

const POLLABLE_STAGES: DeviceStage[] = [
  "idle",
  "assigned",
  "waiting",
  "paused",
  "closed",
  "inactive",
];

export default function DevicePage() {
  const [token, setToken] = useState(
    () => localStorage.getItem(DEVICE_TOKEN_KEY) ?? "",
  );
  const [stage, setStage] = useState<DeviceStage>("idle");
  const [verifiedVoter, setVerifiedVoter] = useState<VerifiedVoter | null>(null);
  const [voterMatches, setVoterMatches] = useState<VerifiedVoter[]>([]);
  const [candidates, setCandidates] = useState<DeviceCandidate[]>([]);
  const [notice, setNotice] = useState<DeviceNotice | null>(null);
  const [connection, setConnection] = useState("Menghubungkan…");
  const [countdown, setCountdown] = useState(5);
  const [pendingCandidate, setPendingCandidate] = useState<DeviceCandidate | null>(
    null,
  );
  const [voteBusy, setVoteBusy] = useState(false);
  const [voteError, setVoteError] = useState<string | null>(null);

  useEffect(() => {
    if (!token || !POLLABLE_STAGES.includes(stage)) return;

    let cancelled = false;

    const poll = async () => {
      try {
        const result = await pollVotingDevice(token);
        if (cancelled) return;

        setConnection("Terhubung · antrean diperbarui");
        const next: DeviceStage =
          result.status === "empty"
            ? "empty"
            : result.status === "open"
              ? "idle"
              : result.status;
        setStage((current) => (current === next ? current : next));
      } catch {
        if (!cancelled) {
          setConnection("Koneksi terputus · assignment tetap tersimpan");
        }
      }
    };

    void poll();
    const timer = window.setInterval(() => void poll(), 2500);

    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [token, stage]);

  useEffect(() => {
    setNotice(null);
  }, [stage]);

  useEffect(() => {
    if (stage !== "thanks") return;

    setCountdown(5);
    let remaining = 5;
    const timer = window.setInterval(() => {
      remaining -= 1;
      setCountdown(remaining);

      if (remaining <= 0) {
        window.clearInterval(timer);
        setVerifiedVoter(null);
        setVoterMatches([]);
        setCandidates([]);
        setPendingCandidate(null);
        setNotice(null);
        setStage("idle");
      }
    }, 1000);

    return () => window.clearInterval(timer);
  }, [stage]);

  async function handleConnect(nextToken: string) {
    const result = await pollVotingDevice(nextToken);
    localStorage.setItem(DEVICE_TOKEN_KEY, nextToken);
    setToken(nextToken);
    setVoterMatches([]);
    setConnection("Perangkat terdaftar");
    setNotice(null);
    setStage(
      result.status === "assigned"
        ? "assigned"
        : result.status === "empty"
          ? "empty"
          : "idle",
    );
  }

  async function handleVerify(nim: string) {
    setNotice(null);
    setVoterMatches([]);
    try {
      const result = await verifyVoterForDevice(token, nim);
      if (result.code === "nim_ambiguous" && result.voters?.length) {
        setVoterMatches(result.voters);
        return;
      }
      if (!result.ok || !result.voter) {
        throw new Error(
          VERIFY_MESSAGES[result.code ?? ""] ??
            "Verifikasi tidak dapat dilanjutkan.",
        );
      }

      setVerifiedVoter(result.voter);
      setStage("verified");
    } catch (error) {
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  function handleSelectVoter(voter: VerifiedVoter) {
    setVoterMatches([]);
    setVerifiedVoter(voter);
    setStage("verified");
  }

  function clearVoterMatches() {
    setVoterMatches([]);
  }

  async function handleContinue() {
    if (!verifiedVoter) return;
    setNotice(null);

    try {
      setCandidates(await getCandidatesForDevice(token, verifiedVoter.nim));
      setStage("voting");
    } catch (error) {
      setNotice({ kind: "error", message: getErrorMessage(error) });
    }
  }

  function handleSelectCandidate(candidate: DeviceCandidate) {
    setVoteError(null);
    setPendingCandidate(candidate);
  }

  async function handleCastVote() {
    if (!pendingCandidate || !verifiedVoter) return;

    setVoteBusy(true);
    setVoteError(null);
    try {
      const result = await castVote(token, verifiedVoter.nim, pendingCandidate.id);
      if (!result.ok) {
        throw new Error(
          "Pemilihan tidak dapat diselesaikan. Verifikasi sesi dan hubungi admin.",
        );
      }

      setPendingCandidate(null);
      setCountdown(5);
      setStage("thanks");
    } catch (error) {
      setVoteError(getErrorMessage(error));
    } finally {
      setVoteBusy(false);
    }
  }

  function handleDisconnect() {
    localStorage.removeItem(DEVICE_TOKEN_KEY);
    setToken("");
    setStage("idle");
    setVerifiedVoter(null);
    setVoterMatches([]);
    setCandidates([]);
    setPendingCandidate(null);
    setVoteBusy(false);
    setVoteError(null);
    setNotice(null);
    setConnection("Menghubungkan…");
  }

  function renderStage() {
    const renderEntry = (entryStage: DeviceIdleStage) => (
      <DeviceStageMessage
        stage={entryStage}
        onVerify={handleVerify}
        voterMatches={voterMatches}
        onSelectVoter={handleSelectVoter}
        onClearVoterMatches={clearVoterMatches}
      />
    );

    if (stage === "verified") {
      return verifiedVoter ? (
        <VoterBiodata voter={verifiedVoter} onContinue={handleContinue} />
      ) : (
        renderEntry("idle")
      );
    }
    if (stage === "voting") {
      return verifiedVoter ? (
        <VotingBallot
          candidates={candidates}
          voter={verifiedVoter}
          onSelect={handleSelectCandidate}
        />
      ) : (
        renderEntry("idle")
      );
    }
    if (stage === "thanks") {
      return (
        <ThankYouStage
          voterName={verifiedVoter?.nama ?? ""}
          countdown={countdown}
        />
      );
    }
    if (stage === "empty") {
      return renderEntry("empty");
    }
    return renderEntry(stage);
  }

  if (!token) {
    return (
      <main className="auth-layout device-setup-layout">
        <div className="auth-brand">
          <Brand suffix="Perangkat" />
        </div>
        <DeviceSetupForm onSubmit={handleConnect} />
      </main>
    );
  }

  return (
    <main className="device-layout">
      <DeviceHeader connection={connection} onChangeToken={handleDisconnect} />

      <section className="device-card">
        <div className="device-copy">
          <p className="section-marker">Pemilihan Ketua Angkatan 2026</p>
          <h1>Suara Anda, masa depan angkatan.</h1>
          <p className="muted">
            Ikuti antrean perangkat dan verifikasi pemilih dengan tiga digit
            terakhir NIM sebelum memilih.
          </p>
        </div>

        <div className="device-action">
          {renderStage()}
          <Notice kind={notice?.kind}>{notice?.message}</Notice>
        </div>
      </section>

      <footer className="site-footer">
        <button type="button" className="text-button" onClick={handleDisconnect}>
          Ganti token perangkat
        </button>
      </footer>

      <ConfirmDialog
        open={pendingCandidate !== null}
        title="Konfirmasi pilihan"
        description={`${verifiedVoter?.nama ?? "Pemilih"} memilih ${
          pendingCandidate?.name ?? ""
        }. Suara tidak dapat diubah setelah dikirim.`}
        confirmLabel="Kirim suara"
        busy={voteBusy}
        error={voteError}
        onConfirm={() => void handleCastVote()}
        onCancel={() => {
          if (!voteBusy) setPendingCandidate(null);
        }}
      />
    </main>
  );
}
