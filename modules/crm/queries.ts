import { createClient } from "@/lib/supabase/server";

export type ProspectListRow = {
  id: string;
  prospectNo: string;
  studentName: string;
  guardianName: string;
  mobile: string;
  className: string;
  schoolName: string;
  sourceName: string;
  assignedTo: string;
  status: string;
  nextFollowUpAt: string | null;
  createdAt: string;
};

export async function getProspectList(): Promise<ProspectListRow[]> {
  const supabase = await createClient();

  const [prospectsQ, classesQ, schoolsQ, sourcesQ, staffQ] =
    await Promise.all([
      supabase
        .from("prospects")
        .select(
          "id,prospect_no,student_name,guardian_name,mobile,current_class_id,school_id,school_name_snapshot,source_id,assigned_to_staff_id,status,next_follow_up_at,created_at"
        )
        .order("created_at", { ascending: false })
        .limit(500),
      supabase.from("classes").select("id,name"),
      supabase.from("schools").select("id,name"),
      supabase.from("lead_sources").select("id,name"),
      supabase.from("staff").select("id,full_name"),
    ]);

  const classNames = new Map(
    (classesQ.data ?? []).map((row) => [row.id, row.name])
  );
  const schoolNames = new Map(
    (schoolsQ.data ?? []).map((row) => [row.id, row.name])
  );
  const sourceNames = new Map(
    (sourcesQ.data ?? []).map((row) => [row.id, row.name])
  );
  const staffNames = new Map(
    (staffQ.data ?? []).map((row) => [row.id, row.full_name])
  );

  return (prospectsQ.data ?? []).map((row) => ({
    id: row.id,
    prospectNo: row.prospect_no,
    studentName: row.student_name,
    guardianName: row.guardian_name,
    mobile: row.mobile,
    className: row.current_class_id
      ? classNames.get(row.current_class_id) ?? "—"
      : "—",
    schoolName:
      (row.school_id ? schoolNames.get(row.school_id) : null) ??
      row.school_name_snapshot ??
      "—",
    sourceName: row.source_id
      ? sourceNames.get(row.source_id) ?? "—"
      : "—",
    assignedTo: row.assigned_to_staff_id
      ? staffNames.get(row.assigned_to_staff_id) ?? "Unassigned"
      : "Unassigned",
    status: row.status,
    nextFollowUpAt: row.next_follow_up_at,
    createdAt: row.created_at,
  }));
}
