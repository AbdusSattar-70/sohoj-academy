"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import {
  recordProspectFollowupSchema,
  type RecordProspectFollowupInput,
} from "@/modules/crm/schema";
import { allowedProspectStatuses } from "@/modules/crm/prospect-status";

export async function reviewAdmissionRequirement(input: {
  applicationId: string; prospectId: string; requirementLabel: string;
  status: "PENDING" | "VERIFIED" | "FOLLOW_UP"; note: string; expectedRevision: number;
}): Promise<{ ok: true } | { ok: false; error: string }> {
  const context = await getErpContext();
  if (!context?.permissions.includes("crm.followups.manage"))
    return { ok: false, error: "CRM review permission is required." };
  if (!/^[0-9a-f-]{36}$/i.test(input.applicationId) ||
      !/^[0-9a-f-]{36}$/i.test(input.prospectId) ||
      input.requirementLabel.trim().length < 3 || input.requirementLabel.length > 160 ||
      !["PENDING", "VERIFIED", "FOLLOW_UP"].includes(input.status) ||
      input.note.length > 1000 || input.expectedRevision < 0 ||
      (input.status === "FOLLOW_UP" && input.note.trim().length < 5))
    return { ok: false, error: "Check the requirement review details." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("review_admission_requirement" as never, {
    p_input: {
      application_id: input.applicationId, requirement_label: input.requirementLabel,
      status: input.status, note: input.note, expected_revision: input.expectedRevision,
    },
  } as never);
  if (error) return { ok: false, error: error.message };
  revalidatePath(`/dashboard/crm/prospects/${input.prospectId}`);
  return { ok: true };
}

export type ProspectFollowupResult =
  | { ok: true; status: string }
  | { ok: false; error: string; field?: string };

export async function recordProspectFollowup(
  input: RecordProspectFollowupInput
): Promise<ProspectFollowupResult> {
  const parsed = recordProspectFollowupSchema.safeParse(input);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Please check the follow-up information.",
      field: issue?.path?.[0]?.toString(),
    };
  }

  const context = await getErpContext();
  if (!context || !context.permissions.includes("crm.followups.manage")) {
    return { ok: false, error: "You are not authorized to record CRM follow-ups." };
  }

  const supabase = await createClient();
  const { data: current, error: currentError } = await supabase
    .from("prospects")
    .select("status")
    .eq("id", parsed.data.prospectId)
    .maybeSingle();

  if (currentError || !current) {
    return { ok: false, error: "Prospect could not be loaded." };
  }

  if (!allowedProspectStatuses(current.status).includes(parsed.data.newStatus)) {
    return {
      ok: false,
      error: `Status cannot move from ${current.status} to ${parsed.data.newStatus} through a follow-up.`,
      field: "newStatus",
    };
  }

  const value = parsed.data;
  const nextFollowUpAt = value.nextFollowUpAt
    ? new Date(value.nextFollowUpAt).toISOString()
    : null;

  const { data, error } = await supabase.rpc("record_prospect_followup", {
    p_input: {
      prospect_id: value.prospectId,
      followup_type: value.followupType,
      notes: value.notes,
      outcome: value.outcome || null,
      new_status: value.newStatus,
      next_follow_up_at: nextFollowUpAt,
      lost_reason: value.lostReason || null,
    },
  });

  if (error) return { ok: false, error: error.message };

  const result = data as { status?: string } | null;

  revalidatePath("/dashboard");
  revalidatePath("/dashboard/action-center");
  revalidatePath("/dashboard/crm/prospects");
  revalidatePath(`/dashboard/crm/prospects/${value.prospectId}`);

  return { ok: true, status: result?.status ?? value.newStatus };
}
