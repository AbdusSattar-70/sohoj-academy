import { createClient } from "@/lib/supabase/server";
import { can, type ErpContext } from "@/types/erp";
import { adminReviewQueueSchema } from "@/modules/governance/schema";

export type ActionCenterData = {
  teacherReviews: Array<{
    id: string;
    reviewType: "ATTENDANCE" | "CLASS_LOG" | "ASSESSMENT_RESULTS" | "QUESTION";
    title: string;
    teacherName: string;
    batchName: string;
    subjectName: string;
    submittedAt: string;
    revision: number;
    href: string;
  }>;
  approvals: Array<{
    id: string;
    workflowType: string;
    entityType: string;
    requestedAction: string;
    requestedAt: string;
    requestNote: string | null;
  }>;
  dueProspects: Array<{
    id: string;
    prospectNo: string;
    studentName: string;
    mobile: string;
    status: string;
    nextFollowUpAt: string;
  }>;
  verificationQueue: Array<{
    id: string;
    prospectNo: string;
    studentName: string;
    mobile: string;
    status: string;
    createdAt: string;
    schoolNeedsReview: boolean;
    schoolName: string;
  }>;
};

export async function getActionCenterData(
  context: ErpContext,
): Promise<ActionCenterData> {
  const supabase = await createClient();

  let teacherReviews: ActionCenterData["teacherReviews"] = [];
  let approvals: ActionCenterData["approvals"] = [];
  let dueProspects: ActionCenterData["dueProspects"] = [];
  let verificationQueue: ActionCenterData["verificationQueue"] = [];

  if (
    can(context, "academics.attendance.approve") ||
    can(context, "academics.assessments.approve")
  ) {
    const { data, error } = await supabase.rpc("admin_review_queue" as never);
    if (error) throw new Error(error.message);
    teacherReviews = adminReviewQueueSchema
      .parse(data)
      .filter((item) =>
        item.reviewType === "ATTENDANCE" || item.reviewType === "CLASS_LOG"
          ? can(context, "academics.attendance.approve")
          : can(context, "academics.assessments.approve"),
      )
      .slice(0, 8);
  }

  if (can(context, "approvals.view")) {
    const { data, error } = await supabase
      .from("approval_requests")
      .select(
        "id,workflow_type,entity_type,requested_action,requested_at,request_note",
      )
      .eq("status", "PENDING")
      .order("requested_at", { ascending: true })
      .limit(50);

    if (error) throw new Error(error.message);

    approvals = (data ?? []).map((row) => ({
      id: row.id,
      workflowType: row.workflow_type,
      entityType: row.entity_type,
      requestedAction: row.requested_action,
      requestedAt: row.requested_at,
      requestNote: row.request_note,
    }));
  }

  if (can(context, "crm.prospects.view")) {
    const nowIso = new Date().toISOString();

    const [dueQ, queueQ] = await Promise.all([
      supabase
        .from("prospects")
        .select("id,prospect_no,student_name,mobile,status,next_follow_up_at")
        .not("next_follow_up_at", "is", null)
        .lte("next_follow_up_at", nowIso)
        .not("status", "in", "(CONVERTED,LOST)")
        .order("next_follow_up_at", { ascending: true })
        .limit(50),
      supabase
        .from("prospects")
        .select(
          "id,prospect_no,student_name,mobile,status,created_at,school_id,school_name_snapshot",
        )
        .in("status", ["NEW", "CONTACTED", "COUNSELLING"])
        .order("created_at", { ascending: false })
        .limit(40),
    ]);

    if (dueQ.error) throw new Error(dueQ.error.message);
    if (queueQ.error) throw new Error(queueQ.error.message);

    dueProspects = (dueQ.data ?? [])
      .filter((row) => row.next_follow_up_at)
      .map((row) => ({
        id: row.id,
        prospectNo: row.prospect_no,
        studentName: row.student_name,
        mobile: row.mobile,
        status: row.status,
        nextFollowUpAt: row.next_follow_up_at as string,
      }));

    verificationQueue = (queueQ.data ?? []).map((row) => ({
      id: row.id,
      prospectNo: row.prospect_no,
      studentName: row.student_name,
      mobile: row.mobile,
      status: row.status,
      createdAt: row.created_at,
      schoolNeedsReview: Boolean(!row.school_id && row.school_name_snapshot),
      schoolName: row.school_name_snapshot ?? "—",
    }));
  }

  return { teacherReviews, approvals, dueProspects, verificationQueue };
}
