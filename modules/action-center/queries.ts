import { createClient } from "@/lib/supabase/server";
import { can, type ErpContext } from "@/types/erp";

export type ActionCenterData = {
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
};

export async function getActionCenterData(
  context: ErpContext
): Promise<ActionCenterData> {
  const supabase = await createClient();

  let approvals: ActionCenterData["approvals"] = [];
  let dueProspects: ActionCenterData["dueProspects"] = [];

  if (can(context, "approvals.view")) {
    const { data } = await supabase
      .from("approval_requests")
      .select(
        "id,workflow_type,entity_type,requested_action,requested_at,request_note"
      )
      .eq("status", "PENDING")
      .order("requested_at", { ascending: true })
      .limit(50);

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
    const { data } = await supabase
      .from("prospects")
      .select("id,prospect_no,student_name,mobile,status,next_follow_up_at")
      .not("next_follow_up_at", "is", null)
      .lte("next_follow_up_at", new Date().toISOString())
      .not("status", "in", "(CONVERTED,LOST)")
      .order("next_follow_up_at", { ascending: true })
      .limit(50);

    dueProspects = (data ?? [])
      .filter((row) => row.next_follow_up_at)
      .map((row) => ({
        id: row.id,
        prospectNo: row.prospect_no,
        studentName: row.student_name,
        mobile: row.mobile,
        status: row.status,
        nextFollowUpAt: row.next_follow_up_at as string,
      }));
  }

  return { approvals, dueProspects };
}
