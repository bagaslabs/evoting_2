export type ElectionState = "closed" | "open" | "paused";

export interface ElectionSettings {
  singleton: boolean;
  title: string;
  election_state: ElectionState;
  active_round_id?: string | null;
  active_round_number?: number | null;
  active_round_title?: string | null;
  results_published: boolean;
  show_public_participation: boolean;
  updated_at: string;
}

export interface ElectionRound {
  id: string;
  round_number: number;
  title: string;
  results_published: boolean;
  show_public_participation: boolean;
  candidate_ids: string[];
}

export interface RoundArchive {
  round: {
    number: number;
    title: string;
    created_at: string;
    eligible_voters_at_start: number | null;
  };
  totals: {
    ballots: number;
    voted: number;
    eligible_not_voted: number;
    non_eligible: number;
  };
  candidates: Array<{
    name: string;
    votes: number;
    percentage: number;
  }>;
  voters: {
    voted: Array<{ nama: string; nim: string; eligible_now: boolean; cast_at: string }>;
    eligible_not_voted: Array<{ nama: string; nim: string }>;
    non_eligible: Array<{ nama: string; nim: string }>;
  };
  eligibility_note: string;
}

export interface ElectionStatistics {
  eligible: number;
  voted: number;
  remaining: number;
  participation_percentage: number;
  total_ballots: number;
}

export interface Candidate {
  id: string;
  name: string;
  vision: string;
  mission: string;
  show_vision_mission: boolean;
  image_url: string;
  active: boolean;
  votes: number;
  percentage: number;
}

export interface VotingDevice {
  id: string;
  name: string;
  active: boolean;
  last_seen_at: string | null;
  connected: boolean;
  active_assignment_id: string | null;
  active_nim: string | null;
  token: string | null;
}

export interface QueueAssignment {
  id: string;
  device_id: string;
  device_name: string;
  nim: string;
  assigned_at: string;
}

export interface QueueOrderItem {
  nim: string;
  position: number;
}

export interface AuditLogItem {
  action: string;
  details: Record<string, unknown>;
  created_at: string;
}

export interface AdminDashboard {
  election: ElectionSettings;
  statistics: ElectionStatistics;
  candidates: Candidate[];
  rounds: ElectionRound[];
  devices: VotingDevice[];
  assignments: QueueAssignment[];
  queue_order: QueueOrderItem[];
  audit_log: AuditLogItem[];
}

export type QueueState = "waiting" | "assigned" | "completed";

export interface AdminVoter {
  nama: string;
  nim: string;
  eligible: boolean;
  has_voted: boolean;
  has_voted_any_round: boolean;
  queue_state: QueueState;
  queue_position: number;
  queue_device_id: string | null;
  device_name: string | null;
  has_assignment_history: boolean;
}

export interface AdminData extends AdminDashboard {
  voters: AdminVoter[];
}

export interface AdminQueueSnapshot {
  devices: AdminQueueDevice[];
  voters: AdminQueueVoter[];
}

export interface AdminQueueDevice {
  id: string;
  name: string;
  active: boolean;
  connected: boolean;
}

export interface AdminQueueVoter {
  nama: string;
  nim: string;
  eligible: boolean;
  has_voted: boolean;
  queue_state: QueueState;
  queue_position: number;
  queue_device_id: string | null;
  device_name: string | null;
}

export interface PublicQueueEntry {
  device_name: string;
  voter_suffix: string | null;
  voter_name: string | null;
  waiting_for_voter: boolean;
  assigned_at: string | null;
  voter_started_at: string | null;
}

export interface DeviceToken {
  device_id: string;
  token: string | null;
}

export type DeviceStatus =
  | "assigned"
  | "waiting"
  | "empty"
  | "inactive"
  | "open"
  | "paused"
  | "closed";

export interface DevicePollResult {
  status: DeviceStatus;
  assignment_id?: string;
}

export type DeviceStage =
  | "idle"
  | "assigned"
  | "waiting"
  | "empty"
  | "inactive"
  | "paused"
  | "closed"
  | "verified"
  | "voting"
  | "thanks";

export interface VerifiedVoter {
  nama: string;
  nim: string;
  jenis_kelamin: string;
  tanggal_masuk: string | null;
  status_saat_ini: string;
}

export interface VerifyVoterResult {
  ok: boolean;
  code?: string;
  voter?: VerifiedVoter;
  voters?: VerifiedVoter[];
}

export interface DeviceCandidate {
  id: string;
  name: string;
  vision: string;
  mission: string;
  show_vision_mission: boolean;
  image_url: string;
}

export interface CastVoteResult {
  ok: boolean;
  code?: string;
}

export interface PublicResultCandidate {
  name: string;
  votes: number;
  percentage: number;
  image_url?: string;
}

export interface PublicResultsPublished {
  published: true;
  title: string;
  total_votes: number;
  candidates: PublicResultCandidate[];
  participation_percentage?: number;
  participation_voted?: number;
  participation_eligible?: number;
}

export interface PublicResultsUnpublished {
  published: false;
  message: string;
}

export type PublicResults = PublicResultsPublished | PublicResultsUnpublished;

export interface CandidateInput {
  id: string | null;
  name: string;
  vision: string;
  mission: string;
  showVisionMission: boolean;
  imageUrl: string;
  active: boolean;
  photo: File | null;
  removePhoto: boolean;
}
