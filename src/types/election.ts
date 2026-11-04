export type ElectionState = "closed" | "open" | "paused";

export interface ElectionSettings {
  singleton: boolean;
  title: string;
  election_state: ElectionState;
  results_published: boolean;
  show_public_participation: boolean;
  updated_at: string;
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
  queue_state: QueueState;
  queue_position: number;
  device_name: string | null;
  has_assignment_history: boolean;
}

export interface AdminData extends AdminDashboard {
  voters: AdminVoter[];
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
}

export interface DeviceCandidate {
  id: string;
  name: string;
  vision: string;
  mission: string;
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
}

export interface PublicResultsPublished {
  published: true;
  title: string;
  total_votes: number;
  candidates: PublicResultCandidate[];
  participation_percentage?: number;
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
  imageUrl: string;
  active: boolean;
  photo: File | null;
  removePhoto: boolean;
}
