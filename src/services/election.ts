import { getSupabase, supabaseUrl } from "../lib/supabase";
import type {
  AdminDashboard,
  AdminData,
  AdminQueueSnapshot,
  AdminVoter,
  CandidateInput,
  CastVoteResult,
  DeviceCandidate,
  DevicePollResult,
  DeviceToken,
  ElectionState,
  PublicQueueEntry,
  PublicResults,
  VerifyVoterResult,
} from "../types/election";
import { CANDIDATE_PHOTOS_BUCKET } from "../utils/constants";
import { getCandidateImageExtension, getCandidateStoragePath } from "../utils/candidate-image";
import { getErrorMessage } from "../utils/errors";
import { rpc } from "../utils/rpc";

export function fetchAdminDashboard() {
  return rpc<AdminDashboard>("get_admin_dashboard");
}

export function fetchAdminVoterRoster() {
  return rpc<AdminVoter[]>("get_admin_voter_roster");
}

export async function fetchAdminQueueData() {
  return rpc<AdminQueueSnapshot>("get_admin_queue_board");
}

export function fetchVotingDeviceTokens() {
  return rpc<DeviceToken[]>("get_voting_device_tokens");
}

export async function loadAdminData(): Promise<AdminData> {
  const [dashboard, tokens, voters] = await Promise.all([
    fetchAdminDashboard(),
    fetchVotingDeviceTokens(),
    fetchAdminVoterRoster(),
  ]);

  const tokenByDeviceId = new Map(
    tokens.map(({ device_id, token }) => [device_id, token]),
  );
  const eligibleVoters = voters.filter(({ eligible }) => eligible).length;
  const statistics = dashboard.election.active_round_id
    ? dashboard.statistics
    : {
        eligible: eligibleVoters,
        voted: 0,
        remaining: eligibleVoters,
        participation_percentage: 0,
        total_ballots: 0,
      };

  return {
    ...dashboard,
    statistics,
    rounds: dashboard.rounds ?? [],
    devices: dashboard.devices.map((device) => ({
      ...device,
      token: tokenByDeviceId.get(device.id) ?? null,
    })),
    voters,
  };
}

export async function getCurrentSession() {
  const { data } = await getSupabase().auth.getSession();
  return data.session;
}

export async function signInAdmin(email: string, password: string) {
  const { error } = await getSupabase().auth.signInWithPassword({ email, password });
  if (error) throw error;
}

export async function signOutAdmin() {
  await getSupabase().auth.signOut();
}

export function setElectionState(state: ElectionState) {
  return rpc<void>("set_election_state", { p_state: state });
}

export function setResultsPublication(published: boolean, showParticipation: boolean) {
  return rpc<void>("set_results_publication", {
    p_published: published,
    p_show_participation: showParticipation,
  });
}

export function createElectionRound(title: string, candidateIds: string[]) {
  return rpc<{ id: string; round_number: number; title: string }>(
    "create_election_round",
    { p_title: title, p_candidate_ids: candidateIds },
  );
}

export function renameElectionRound(roundId: string, title: string) {
  return rpc<void>("rename_election_round", {
    p_round_id: roundId,
    p_title: title,
  });
}

export function selectElectionRound(roundId: string) {
  return rpc<void>("select_election_round", { p_round_id: roundId });
}

export function deleteElectionRound(roundId: string) {
  return rpc<void>("delete_election_round", { p_round_id: roundId });
}

export function createVotingDevice(name: string) {
  return rpc<{ device_id: string; name: string }>("create_voting_device", {
    p_name: name,
  });
}

export function deleteVotingDevice(deviceId: string) {
  return rpc<void>("delete_voting_device", { p_device_id: deviceId });
}

export function setDeviceActive(deviceId: string, isActive: boolean) {
  return rpc<void>("set_device_active", {
    p_device_id: deviceId,
    p_is_active: isActive,
  });
}

export function forceReleaseDevice(deviceId: string, reason: string) {
  return rpc<void>("force_release_device", {
    p_device_id: deviceId,
    p_reason: reason,
  });
}

export function cancelQueueAssignment(assignmentId: string, reason: string) {
  return rpc<void>("cancel_queue_assignment", {
    p_assignment_id: assignmentId,
    p_reason: reason,
  });
}

export function deleteVoter(nim: string) {
  return rpc<void>("delete_voter", { p_nim: nim });
}

export function deleteAllVoters() {
  return rpc<number>("delete_all_voters");
}

export function setVoterEligibility(nim: string, eligible: boolean) {
  return rpc<void>("set_voter_eligibility", {
    p_nim: nim,
    p_eligible: eligible,
  });
}

export function assignNextVoterToDevice(deviceId: string) {
  return rpc<{ status: string }>("assign_next_voter_to_device", {
    p_device_id: deviceId,
  });
}

export function rotateVotingDeviceToken(deviceId: string) {
  return rpc<void>("rotate_voting_device_token", { p_device_id: deviceId });
}

export function addVoter(input: {
  nim: string;
  nama: string;
  jenisKelamin: string;
  tanggalMasuk: string;
  statusSaatIni: string;
}) {
  return rpc<void>("add_voter", {
    p_nim: input.nim,
    p_nama: input.nama,
    p_jenis_kelamin: input.jenisKelamin,
    p_tanggal_masuk: input.tanggalMasuk || null,
    p_status_saat_ini: input.statusSaatIni,
  });
}

export function importVoters(voters: unknown) {
  return rpc<number>("import_voters", { p_voters: voters });
}

export function setQueueOrder(nims: string[]) {
  return rpc<void>("set_queue_order", { p_nims: nims });
}

export async function saveCandidate(
  input: CandidateInput,
  oldImageUrl: string,
): Promise<{ candidateId: string; warning: string }> {
  const client = getSupabase();
  const extension = input.photo ? getCandidateImageExtension(input.photo) : null;
  const requestedImageUrl = input.photo
    ? oldImageUrl
    : input.imageUrl || (input.removePhoto ? "" : oldImageUrl);

  const candidatePayload = {
    p_id: input.id,
    p_name: input.name,
    p_vision: input.vision,
    p_mission: input.mission,
    p_show_vision_mission: input.showVisionMission,
    p_image_url: requestedImageUrl,
    p_active: input.active,
  };

  let candidateId = "";
  let uploadedPath: string | null = null;
  let uploadCompleted = false;

  try {
    candidateId = await rpc<string>("save_candidate", candidatePayload);

    if (input.photo) {
      uploadedPath = `${candidateId}/${crypto.randomUUID()}.${extension}`;
      const { error } = await client.storage
        .from(CANDIDATE_PHOTOS_BUCKET)
        .upload(uploadedPath, input.photo, {
          cacheControl: "3600",
          contentType: input.photo.type,
          upsert: false,
        });

      if (error) {
        throw new Error(`Data kandidat tersimpan, tetapi upload foto gagal: ${error.message}`);
      }
      uploadCompleted = true;

      const { data } = client.storage
        .from(CANDIDATE_PHOTOS_BUCKET)
        .getPublicUrl(uploadedPath);

      await rpc<string>("save_candidate", {
        ...candidatePayload,
        p_id: candidateId,
        p_image_url: data.publicUrl,
      });
    }

    const nextImageUrl = uploadedPath
      ? client.storage.from(CANDIDATE_PHOTOS_BUCKET).getPublicUrl(uploadedPath).data.publicUrl
      : requestedImageUrl;
    const oldPhotoPath = getCandidateStoragePath(oldImageUrl, supabaseUrl);
    const newPhotoPath = getCandidateStoragePath(nextImageUrl, supabaseUrl);
    let warning = "";

    if (oldPhotoPath && oldPhotoPath !== newPhotoPath) {
      const { error } = await client.storage
        .from(CANDIDATE_PHOTOS_BUCKET)
        .remove([oldPhotoPath]);
      if (error) warning = ` Foto lama belum terhapus: ${error.message}`;
    }

    return { candidateId, warning };
  } catch (error) {
    if (uploadedPath && uploadCompleted) {
      const { error: cleanupError } = await client.storage
        .from(CANDIDATE_PHOTOS_BUCKET)
        .remove([uploadedPath]);

      if (cleanupError) {
        throw new Error(
          `${getErrorMessage(error)} File foto yang gagal disimpan juga tidak dapat dibersihkan: ${cleanupError.message}`,
        );
      }
      if (candidateId) {
        throw new Error(
          `Data kandidat tersimpan, tetapi foto belum dapat dikaitkan. ${getErrorMessage(error)}`,
        );
      }
    }
    throw error;
  }
}

export async function deleteCandidate(
  candidateId: string,
  imageUrl: string,
): Promise<string> {
  const client = getSupabase();
  await rpc<void>("delete_candidate", { p_candidate_id: candidateId });

  const imagePath = getCandidateStoragePath(imageUrl, supabaseUrl);
  if (!imagePath) return "";

  try {
    const { error } = await client.storage
      .from(CANDIDATE_PHOTOS_BUCKET)
      .remove([imagePath]);
    return error ? ` Foto kandidat belum terhapus: ${error.message}` : "";
  } catch (error) {
    return ` Foto kandidat belum terhapus: ${getErrorMessage(error)}`;
  }
}

export function getPublicResults(roundNumber?: number) {
  return roundNumber === undefined
    ? rpc<PublicResults>("get_public_results")
    : rpc<PublicResults>("get_public_results", {
        p_round_number: roundNumber,
      });
}

export function getPublicCurrentQueue() {
      return rpc<PublicQueueEntry[]>("get_public_current_queue");
}

export async function changeAdminPassword(currentPassword: string, nextPassword: string) {
  const client = getSupabase();
  const { data } = await client.auth.getUser();
  if (!data.user?.email) {
    throw new Error("Email akun admin tidak dapat diverifikasi.");
  }

  const { error: authError } = await client.auth.signInWithPassword({
    email: data.user.email,
    password: currentPassword,
  });
  if (authError) throw authError;

  const { error } = await client.auth.updateUser({ password: nextPassword });
  if (error) throw error;

  await rpc<void>("admin_record_action", { p_action: "admin_password_changed" });
}

export function pollVotingDevice(token: string) {
  return rpc<DevicePollResult>("poll_voting_device", { p_token: token });
}

export function verifyVoterForDevice(token: string, nim: string) {
  return rpc<VerifyVoterResult>("verify_voter_for_device", {
    p_token: token,
    p_nim: nim,
  });
}

export function getCandidatesForDevice(token: string, nim: string) {
  return rpc<DeviceCandidate[]>("get_candidates_for_device", {
    p_token: token,
    p_nim: nim,
  });
}

export function castVote(token: string, nim: string, candidateId: string) {
  return rpc<CastVoteResult>("cast_vote", {
    p_token: token,
    p_nim: nim,
    p_candidate_id: candidateId,
  });
}

export function isPermissionError(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "42501"
  );
}
