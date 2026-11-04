import type { QueueAssignment } from "../../types/election";
import { formatDateTime } from "../../utils/format";
import { Button } from "../ui/Button";
import { Panel } from "../ui/Panel";

interface AssignmentPanelProps {
  assignments: QueueAssignment[];
  onCancel: (assignment: QueueAssignment) => void;
}

export function AssignmentPanel({ assignments, onCancel }: AssignmentPanelProps) {
  return (
    <Panel
      title="Assignment aktif"
      description="Perangkat yang lebih dulu siap menerima NIM eligible berikutnya dalam urutan global."
      aside={<span className="muted small">{assignments.length} aktif</span>}
    >
      <div className="list-stack">
        {assignments.length === 0 && (
          <p className="muted">Tidak ada assignment aktif.</p>
        )}
        {assignments.map((assignment) => (
          <article className="list-row" key={assignment.id}>
            <div>
              <strong>
                {assignment.device_name} · {assignment.nim}
              </strong>
              <p className="muted small">
                Aktif sejak {formatDateTime(assignment.assigned_at)}
              </p>
            </div>
            <Button
              size="sm"
              variant="danger"
              onClick={() => onCancel(assignment)}
            >
              Batalkan
            </Button>
          </article>
        ))}
      </div>
    </Panel>
  );
}
