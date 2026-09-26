import { createClient } from "@/lib/supabase/server";
import type { ProspectStatus } from "@/modules/crm/prospect-status";

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
  status: ProspectStatus;
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


export type ProspectDetail = {
  id: string;
  prospectNo: string;
  studentName: string;
  guardianName: string;
  relationship: string;
  mobile: string;
  alternateMobile: string | null;
  className: string;
  schoolName: string;
  area: string;
  preferredSchedule: string | null;
  preferredDays: string[];
  trialInterest: boolean;
  sourceName: string;
  referralNote: string | null;
  notes: string | null;
  status: ProspectStatus;
  assignedTo: string;
  nextFollowUpAt: string | null;
  lostReason: string | null;
  createdAt: string;
  programs: string[];
  subjects: string[];
  followups: Array<{
    id: string;
    type: string;
    occurredAt: string;
    outcome: string | null;
    notes: string;
    nextFollowUpAt: string | null;
    recordedBy: string;
  }>;
};

export async function getProspectDetail(
  prospectId: string
): Promise<ProspectDetail | null> {
  const supabase = await createClient();

  const { data: prospect, error } = await supabase
    .from("prospects")
    .select(
      "id,prospect_no,student_name,guardian_name,guardian_relationship_snapshot,mobile,alternate_mobile,current_class_id,school_id,school_name_snapshot,area_snapshot,preferred_schedule,preferred_days,trial_interest,source_id,referral_note,notes,status,assigned_to_staff_id,next_follow_up_at,lost_reason,created_at"
    )
    .eq("id", prospectId)
    .maybeSingle();

  if (error || !prospect) return null;

  const [classesQ, schoolsQ, sourcesQ, staffQ, programLinksQ, subjectLinksQ, programsQ, subjectsQ, followupsQ, profilesQ] =
    await Promise.all([
      supabase.from("classes").select("id,name"),
      supabase.from("schools").select("id,name"),
      supabase.from("lead_sources").select("id,name"),
      supabase.from("staff").select("id,full_name"),
      supabase
        .from("prospect_program_interests")
        .select("program_id")
        .eq("prospect_id", prospectId),
      supabase
        .from("prospect_subject_interests")
        .select("subject_id")
        .eq("prospect_id", prospectId),
      supabase.from("programs").select("id,name"),
      supabase.from("subjects").select("id,name"),
      supabase
        .from("prospect_followups")
        .select(
          "id,followup_type,occurred_at,outcome,notes,next_follow_up_at,recorded_by"
        )
        .eq("prospect_id", prospectId)
        .order("occurred_at", { ascending: false }),
      supabase.from("profiles").select("id,display_name"),
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
  const programNames = new Map(
    (programsQ.data ?? []).map((row) => [row.id, row.name])
  );
  const subjectNames = new Map(
    (subjectsQ.data ?? []).map((row) => [row.id, row.name])
  );
  const profileNames = new Map(
    (profilesQ.data ?? []).map((row) => [row.id, row.display_name])
  );

  return {
    id: prospect.id,
    prospectNo: prospect.prospect_no,
    studentName: prospect.student_name,
    guardianName: prospect.guardian_name,
    relationship: prospect.guardian_relationship_snapshot ?? "—",
    mobile: prospect.mobile,
    alternateMobile: prospect.alternate_mobile,
    className: prospect.current_class_id
      ? classNames.get(prospect.current_class_id) ?? "—"
      : "—",
    schoolName:
      (prospect.school_id ? schoolNames.get(prospect.school_id) : null) ??
      prospect.school_name_snapshot ??
      "—",
    area: prospect.area_snapshot ?? "—",
    preferredSchedule: prospect.preferred_schedule,
    preferredDays: prospect.preferred_days,
    trialInterest: prospect.trial_interest,
    sourceName: prospect.source_id
      ? sourceNames.get(prospect.source_id) ?? "—"
      : "—",
    referralNote: prospect.referral_note,
    notes: prospect.notes,
    status: prospect.status,
    assignedTo: prospect.assigned_to_staff_id
      ? staffNames.get(prospect.assigned_to_staff_id) ?? "Unassigned"
      : "Unassigned",
    nextFollowUpAt: prospect.next_follow_up_at,
    lostReason: prospect.lost_reason,
    createdAt: prospect.created_at,
    programs: (programLinksQ.data ?? [])
      .map((link) => programNames.get(link.program_id))
      .filter((value): value is string => Boolean(value)),
    subjects: (subjectLinksQ.data ?? [])
      .map((link) => subjectNames.get(link.subject_id))
      .filter((value): value is string => Boolean(value)),
    followups: (followupsQ.data ?? []).map((row) => ({
      id: row.id,
      type: row.followup_type,
      occurredAt: row.occurred_at,
      outcome: row.outcome,
      notes: row.notes,
      nextFollowUpAt: row.next_follow_up_at,
      recordedBy: profileNames.get(row.recorded_by) ?? "Staff user",
    })),
  };
}
