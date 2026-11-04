import type { ElectionState } from "../../types/election";
import { getElectionStateLabel } from "../../utils/format";

export function ElectionBadge({ state }: { state: ElectionState }) {
  return <span className={`badge badge-${state}`}>{getElectionStateLabel(state)}</span>;
}
