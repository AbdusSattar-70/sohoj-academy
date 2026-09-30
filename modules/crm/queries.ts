import { createClient } from "@/lib/supabase/server";
import { createOfferingClient } from "@/modules/offerings/database-contract";
import type { ProspectStatus } from "@/modules/crm/prospect-status";

/** Prospect columns including migration 0025 fields (types/database may lag). */
type ProspectCoreRow = {
  application_snapshot?: {
    class_label?: string;
    offering_label?: string;
    program_labels?: string[];
    subject_labels?: string[];
  } | null;
  id: string;
  prospect_no: string;
  student_name: string;
  guardian_name: string;
  guardian_relationship_snapshot?: string | null;
  mobile: string;
  alternate_mobile?: string | null;
  current_class_id: string | null;
  school_id: string | null;
  school_name_snapshot: string | null;
  area_snapshot?: string | null;
  preferred_schedule?: string | null;
  preferred_days?: string[] | null;
  trial_interest?: boolean;
  source_id: string | null;
  referral_note?: string | null;
  notes?: string | null;
  status: ProspectStatus;
  assigned_to_staff_id: string | null;
  next_follow_up_at: string | null;
  lost_reason?: string | null;
  created_at: string;
  interested_offering_id: string | null;
  submission_intent: string | null;
};

export type SubmissionIntent = "interest" | "admission";

type CorrectionRow = {
  id: string;
  requested_changes: string;
  status: string;
  staff_note: string;
  submitted_at: string;
  reviewed_at: string | null;
};

type PublicApplication = {
  id: string;
  guardianAddress: string;
  academicBackground: string | null;
  requirementsAcknowledged: boolean;
  policyAcknowledged: boolean;
  submittedAt: string;
  feePlanVersionId: string | null;
  publishedTerms: {
    offering_name?: string;
    requirements?: string | null;
    policy?: string | null;
    schedule?: string | null;
    applications_open_on?: string | null;
    applications_close_on?: string | null;
  };
  reviews: Array<{
    id: string;
    requirementLabel: string;
    status: string;
    note: string;
    revision: number;
    reviewedAt: string;
  }>;
  corrections: Array<{
    id: string;
    requestedChanges: string;
    status: string;
    staffNote: string;
    submittedAt: string;
    reviewedAt: string | null;
  }>;
};

export type ProspectListRow = {
  id: string;
  prospectNo: string;
  studentName: string;
  guardianName: string;
  mobile: string;
  className: string;
  schoolName: string;
  schoolNeedsReview: boolean;
  sourceName: string;
  assignedTo: string;
  status: ProspectStatus;
  nextFollowUpAt: string | null;
  createdAt: string;
  submissionIntent: SubmissionIntent;
  offeringLabel: string;
};

export async function getProspectList(): Promise<ProspectListRow[]> {
  const supabase = await createClient();
  const offeringDb = await createOfferingClient();

  const prospectsClient = supabase as unknown as {
    from: (table: string) => {
      select: (cols: string) => {
        order: (
          col: string,
          opts: { ascending: boolean },
        ) => {
          limit: (n: number) => Promise<{ data: ProspectCoreRow[] | null }>;
        };
      };
    };
  };

  const [prospectsQ, classesQ, schoolsQ, sourcesQ, staffQ, offeringsQ] =
    await Promise.all([
      prospectsClient
        .from("prospects")
        .select(
          "id,prospect_no,student_name,guardian_name,mobile,current_class_id,school_id,school_name_snapshot,source_id,assigned_to_staff_id,status,next_follow_up_at,created_at,interested_offering_id,submission_intent,application_snapshot",
        )
        .order("created_at", { ascending: false })
        .limit(500),
      supabase.from("classes").select("id,name"),
      supabase.from("schools").select("id,name,is_verified"),
      supabase.from("lead_sources").select("id,name"),
      supabase.from("staff").select("id,full_name"),
      offeringDb.from("programme_offerings").select("id,code,name"),
    ]);

  const classNames = new Map(
    (classesQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const schoolRows = new Map((schoolsQ.data ?? []).map((row) => [row.id, row]));
  const sourceNames = new Map(
    (sourcesQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const staffNames = new Map(
    (staffQ.data ?? []).map((row) => [row.id, row.full_name]),
  );
  const offeringLabels = new Map(
    (offeringsQ.data ?? []).map((row) => [
      row.id,
      row.code ? `${row.code} — ${row.name}` : row.name,
    ]),
  );

  return (prospectsQ.data ?? []).map((row) => {
    const linkedSchool = row.school_id ? schoolRows.get(row.school_id) : null;
    const schoolName = linkedSchool?.name ?? row.school_name_snapshot ?? "—";
    const schoolNeedsReview = Boolean(
      (!row.school_id && row.school_name_snapshot) ||
      (linkedSchool && linkedSchool.is_verified === false),
    );

    return {
      id: row.id,
      prospectNo: row.prospect_no,
      studentName: row.student_name,
      guardianName: row.guardian_name,
      mobile: row.mobile,
      className: row.current_class_id
        ? (classNames.get(row.current_class_id) ?? "—")
        : row.application_snapshot?.class_label
          ? `${row.application_snapshot.class_label} · unverified`
          : "Not verified",
      schoolName,
      schoolNeedsReview,
      sourceName: row.source_id ? (sourceNames.get(row.source_id) ?? "—") : "—",
      assignedTo: row.assigned_to_staff_id
        ? (staffNames.get(row.assigned_to_staff_id) ?? "Unassigned")
        : "Unassigned",
      status: row.status as ProspectStatus,
      nextFollowUpAt: row.next_follow_up_at,
      createdAt: row.created_at,
      submissionIntent:
        row.submission_intent === "admission" ? "admission" : "interest",
      offeringLabel: row.interested_offering_id
        ? (offeringLabels.get(row.interested_offering_id) ?? "Linked offering")
        : row.application_snapshot?.offering_label
          ? `${row.application_snapshot.offering_label} · unverified`
          : "Not verified",
    };
  });
}

export type ProspectDetail = {
  applicationSnapshot: ProspectCoreRow["application_snapshot"];
  id: string;
  prospectNo: string;
  studentName: string;
  guardianName: string;
  relationship: string;
  mobile: string;
  alternateMobile: string | null;
  className: string;
  schoolName: string;
  schoolNeedsReview: boolean;
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
  submissionIntent: SubmissionIntent;
  offeringLabel: string;
  application: PublicApplication | null;
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
  prospectId: string,
): Promise<ProspectDetail | null> {
  const supabase = await createClient();
  const offeringDb = await createOfferingClient();

  const detailClient = supabase as unknown as {
    from: (table: string) => {
      select: (cols: string) => {
        eq: (
          col: string,
          val: string,
        ) => {
          maybeSingle: () => Promise<{
            data: ProspectCoreRow | null;
            error: unknown;
          }>;
        };
      };
    };
  };

  const { data: prospect, error } = await detailClient
    .from("prospects")
    .select(
      "id,prospect_no,student_name,guardian_name,guardian_relationship_snapshot,mobile,alternate_mobile,current_class_id,school_id,school_name_snapshot,area_snapshot,preferred_schedule,preferred_days,trial_interest,source_id,referral_note,notes,status,assigned_to_staff_id,next_follow_up_at,lost_reason,created_at,interested_offering_id,submission_intent,application_snapshot",
    )
    .eq("id", prospectId)
    .maybeSingle();

  if (error || !prospect) return null;

  const [
    classesQ,
    schoolsQ,
    sourcesQ,
    staffQ,
    programsQ,
    subjectsQ,
    programLinksQ,
    subjectLinksQ,
    followupsQ,
    offeringsQ,
    applicationQ,
  ] = await Promise.all([
    supabase.from("classes").select("id,name"),
    supabase.from("schools").select("id,name,is_verified"),
    supabase.from("lead_sources").select("id,name"),
    supabase.from("staff").select("id,full_name"),
    supabase.from("programs").select("id,name"),
    supabase.from("subjects").select("id,name"),
    supabase
      .from("prospect_program_interests")
      .select("program_id")
      .eq("prospect_id", prospectId),
    supabase
      .from("prospect_subject_interests")
      .select("subject_id")
      .eq("prospect_id", prospectId),
    supabase
      .from("prospect_followups")
      .select(
        "id,followup_type,occurred_at,outcome,notes,next_follow_up_at,recorded_by",
      )
      .eq("prospect_id", prospectId)
      .order("occurred_at", { ascending: false }),
    offeringDb.from("programme_offerings").select("id,code,name"),
    (
      supabase as unknown as {
        from: (name: string) => {
          select: (columns: string) => {
            eq: (
              column: string,
              value: string,
            ) => {
              maybeSingle: () => Promise<{
                data: {
                  id: string;
                  guardian_address: string;
                  academic_background: string | null;
                  requirements_acknowledged: boolean;
                  policy_acknowledged: boolean;
                  submitted_at: string;
                  fee_plan_version_id: string | null;
                  published_terms_snapshot: Record<string, string | null>;
                } | null;
                error: unknown;
              }>;
            };
          };
        };
      }
    )
      .from("public_admission_applications")
      .select(
        "id,guardian_address,academic_background,requirements_acknowledged,policy_acknowledged,submitted_at,fee_plan_version_id,published_terms_snapshot",
      )
      .eq("prospect_id", prospectId)
      .maybeSingle(),
  ]);

  type ReviewRow = {
    id: string;
    requirement_label: string;
    status: string;
    note: string;
    revision: number;
    reviewed_at: string;
  };
  const correctionsQ: { data: CorrectionRow[] | null } = applicationQ.data
    ? await (
        supabase as unknown as {
          from: (name: string) => {
            select: (columns: string) => {
              eq: (
                column: string,
                value: string,
              ) => {
                order: (
                  column: string,
                  options: { ascending: boolean },
                ) => Promise<{ data: CorrectionRow[] | null }>;
              };
            };
          };
        }
      )
        .from("public_admission_corrections")
        .select(
          "id,requested_changes,status,staff_note,submitted_at,reviewed_at",
        )
        .eq("application_id", applicationQ.data.id)
        .order("submitted_at", { ascending: false })
    : { data: [] };
  const reviewsQ: { data: ReviewRow[] | null } = applicationQ.data
    ? await (
        supabase as unknown as {
          from: (name: string) => {
            select: (columns: string) => {
              eq: (
                column: string,
                value: string,
              ) => {
                order: (
                  column: string,
                  options: { ascending: boolean },
                ) => Promise<{ data: ReviewRow[] | null }>;
              };
            };
          };
        }
      )
        .from("admission_requirement_reviews")
        .select("id,requirement_label,status,note,revision,reviewed_at")
        .eq("application_id", applicationQ.data.id)
        .order("reviewed_at", { ascending: false })
    : { data: [] };

  const profileIds = Array.from(
    new Set(
      (followupsQ.data ?? [])
        .map((row) => row.recorded_by)
        .filter((value): value is string => Boolean(value)),
    ),
  );

  const profilesQ = profileIds.length
    ? await supabase
        .from("profiles")
        .select("id,display_name")
        .in("id", profileIds)
    : { data: [] as Array<{ id: string; display_name: string | null }> };

  const classNames = new Map(
    (classesQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const schoolRows = new Map((schoolsQ.data ?? []).map((row) => [row.id, row]));
  const sourceNames = new Map(
    (sourcesQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const staffNames = new Map(
    (staffQ.data ?? []).map((row) => [row.id, row.full_name]),
  );
  const programNames = new Map(
    (programsQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const subjectNames = new Map(
    (subjectsQ.data ?? []).map((row) => [row.id, row.name]),
  );
  const profileNames = new Map(
    (profilesQ.data ?? []).map((row) => [row.id, row.display_name]),
  );
  const offeringLabels = new Map(
    (offeringsQ.data ?? []).map((row) => [
      row.id,
      row.code ? `${row.code} — ${row.name}` : row.name,
    ]),
  );

  const linkedSchool = prospect.school_id
    ? schoolRows.get(prospect.school_id)
    : null;
  const schoolName = linkedSchool?.name ?? prospect.school_name_snapshot ?? "—";
  const schoolNeedsReview = Boolean(
    (!prospect.school_id && prospect.school_name_snapshot) ||
    (linkedSchool && linkedSchool.is_verified === false),
  );

  return {
    applicationSnapshot: prospect.application_snapshot,
    id: prospect.id,
    prospectNo: prospect.prospect_no,
    studentName: prospect.student_name,
    guardianName: prospect.guardian_name,
    relationship: prospect.guardian_relationship_snapshot ?? "—",
    mobile: prospect.mobile,
    alternateMobile: prospect.alternate_mobile ?? null,
    className: prospect.current_class_id
      ? (classNames.get(prospect.current_class_id) ?? "—")
      : prospect.application_snapshot?.class_label
        ? `${prospect.application_snapshot.class_label} · unverified`
        : "Not verified",
    schoolName,
    schoolNeedsReview,
    area: prospect.area_snapshot ?? "—",
    preferredSchedule: prospect.preferred_schedule ?? null,
    preferredDays: prospect.preferred_days ?? [],
    trialInterest: Boolean(prospect.trial_interest),
    sourceName: prospect.source_id
      ? (sourceNames.get(prospect.source_id) ?? "—")
      : "—",
    referralNote: prospect.referral_note ?? null,
    notes: prospect.notes ?? null,
    status: prospect.status as ProspectStatus,
    assignedTo: prospect.assigned_to_staff_id
      ? (staffNames.get(prospect.assigned_to_staff_id) ?? "Unassigned")
      : "Unassigned",
    nextFollowUpAt: prospect.next_follow_up_at,
    lostReason: prospect.lost_reason ?? null,
    createdAt: prospect.created_at,
    programs:
      prospect.application_snapshot?.program_labels ??
      (programLinksQ.data ?? [])
        .map((link) => programNames.get(link.program_id))
        .filter((value): value is string => Boolean(value)),
    subjects:
      prospect.application_snapshot?.subject_labels ??
      (subjectLinksQ.data ?? [])
        .map((link) => subjectNames.get(link.subject_id))
        .filter((value): value is string => Boolean(value)),
    submissionIntent:
      prospect.submission_intent === "admission" ? "admission" : "interest",
    offeringLabel: prospect.interested_offering_id
      ? (offeringLabels.get(prospect.interested_offering_id) ??
        "Linked offering")
      : "—",
    application: applicationQ.data
      ? {
          id: applicationQ.data.id,
          guardianAddress: applicationQ.data.guardian_address,
          academicBackground: applicationQ.data.academic_background,
          requirementsAcknowledged: applicationQ.data.requirements_acknowledged,
          policyAcknowledged: applicationQ.data.policy_acknowledged,
          submittedAt: applicationQ.data.submitted_at,
          feePlanVersionId: applicationQ.data.fee_plan_version_id,
          publishedTerms: applicationQ.data.published_terms_snapshot,
          reviews: (reviewsQ.data ?? []).map((row) => ({
            id: row.id,
            requirementLabel: row.requirement_label,
            status: row.status,
            note: row.note,
            revision: row.revision,
            reviewedAt: row.reviewed_at,
          })),
          corrections: (correctionsQ.data ?? []).map((row) => ({
            id: row.id,
            requestedChanges: row.requested_changes,
            status: row.status,
            staffNote: row.staff_note,
            submittedAt: row.submitted_at,
            reviewedAt: row.reviewed_at,
          })),
        }
      : null,
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
