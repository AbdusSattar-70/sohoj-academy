import type { EditorRow } from "./rows";
import type { TimetableInput } from "./schema";
export function expandClassGroups(rows: EditorRow[]): TimetableInput["slots"] {
  return rows.flatMap((r) =>
    r.days.map((weekday) => ({
      weekday,
      subject_id: r.subject_id,
      teacher_id: r.teacher_id,
      room_id: r.room_id,
      start_time: r.start_time,
      end_time: r.end_time,
      planned_scope: r.planned_scope,
      curriculum_id: r.curriculum_id || undefined,
    })),
  );
}
