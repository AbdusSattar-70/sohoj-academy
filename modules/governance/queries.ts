import { createClient } from "@/lib/supabase/server";
import { adminReviewQueueSchema } from "./schema";

export async function getAdminReviewQueue() {
  const db = await createClient();
  const { data, error } = await db.rpc("admin_review_queue" as never);
  if (error) throw new Error(error.message);
  return adminReviewQueueSchema.parse(data);
}

export async function getApprovalList() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("approval_requests")
    .select(
      "id,workflow_type,entity_type,entity_id,requested_action,status,requested_at,request_note,decision_note",
    )
    .order("requested_at", { ascending: false })
    .limit(200);

  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getAuditList() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("audit_events")
    .select(
      "id,occurred_at,actor_role_code,entity_type,entity_id,action,reason,correlation_id",
    )
    .order("occurred_at", { ascending: false })
    .limit(250);

  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getBusinessRules() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("business_rule_versions")
    .select(
      "id,domain,rule_key,version,status,effective_from,effective_to,payload,change_reason,created_at",
    )
    .order("domain")
    .order("rule_key")
    .order("version", { ascending: false });

  if (error) throw new Error(error.message);
  return data ?? [];
}
