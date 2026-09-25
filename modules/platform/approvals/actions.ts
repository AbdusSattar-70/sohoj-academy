"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const submitSchema = z.object({
  workflowType: z.enum([
    "ATTENDANCE_FINALIZATION",
    "ASSESSMENT_RESULTS_FINALIZATION",
  ]),
  entityType: z.enum(["CLASS_SESSION", "ASSESSMENT"]),
  entityId: z.string().uuid(),
  requestedAction: z.literal("FINALIZE"),
  note: z.string().trim().max(500).optional(),
});

const decisionSchema = z.object({
  approvalRequestId: z.string().uuid(),
  decision: z.enum(["APPROVED", "REJECTED"]),
  note: z.string().trim().max(500).optional(),
});

export type ApprovalActionResult =
  | { ok: true; approvalRequestId: string }
  | { ok: false; error: string };

function revalidateWorkflow(workflowType: string) {
  if (workflowType === "ATTENDANCE_FINALIZATION") {
    revalidatePath("/dashboard/attendance");
  }
  if (workflowType === "ASSESSMENT_RESULTS_FINALIZATION") {
    revalidatePath("/dashboard/assessments");
    revalidatePath("/dashboard/progress");
  }
  revalidatePath("/dashboard");
}

async function getAuthenticatedContext() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "You must sign in." as const };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return { error: "Your academy role could not be verified." as const };
  }

  return { supabase, user, role: profile.role };
}

export async function submitForApproval(
  input: z.input<typeof submitSchema>
): Promise<ApprovalActionResult> {
  const parsed = submitSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: "The approval request is incomplete." };
  }

  const context = await getAuthenticatedContext();
  if ("error" in context) return { ok: false, error: context.error };

  if (!["ADMIN", "OPERATOR", "TEACHER"].includes(context.role)) {
    return { ok: false, error: "You are not authorised to submit this workflow." };
  }

  const { data, error } = await context.supabase
    .from("approval_requests")
    .insert({
      workflow_type: parsed.data.workflowType,
      entity_type: parsed.data.entityType,
      entity_id: parsed.data.entityId,
      requested_action: parsed.data.requestedAction,
      request_note: parsed.data.note || null,
      requested_by: context.user.id,
    })
    .select("id")
    .single();

  if (error) {
    return { ok: false, error: error.message };
  }

  revalidateWorkflow(parsed.data.workflowType);
  return { ok: true, approvalRequestId: data.id };
}

export async function decideApproval(
  input: z.input<typeof decisionSchema>
): Promise<ApprovalActionResult> {
  const parsed = decisionSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: "The approval decision is incomplete." };
  }

  const context = await getAuthenticatedContext();
  if ("error" in context) return { ok: false, error: context.error };

  if (context.role !== "ADMIN") {
    return { ok: false, error: "Administrator approval is required." };
  }

  const { data: request, error: requestError } = await context.supabase
    .from("approval_requests")
    .select("id,workflow_type,status,requested_by")
    .eq("id", parsed.data.approvalRequestId)
    .maybeSingle();

  if (requestError || !request) {
    return { ok: false, error: "Approval request was not found." };
  }

  if (request.status !== "PENDING") {
    return { ok: false, error: "This approval request has already been decided." };
  }

  if (
    parsed.data.decision === "APPROVED" &&
    request.requested_by === context.user.id
  ) {
    return {
      ok: false,
      error: "The same user cannot submit and approve the same workflow.",
    };
  }

  const { error } = await context.supabase
    .from("approval_requests")
    .update({
      status: parsed.data.decision,
      decided_by: context.user.id,
      decided_at: new Date().toISOString(),
      decision_note: parsed.data.note || null,
    })
    .eq("id", request.id)
    .eq("status", "PENDING");

  if (error) {
    return { ok: false, error: error.message };
  }

  revalidateWorkflow(request.workflow_type);
  return { ok: true, approvalRequestId: request.id };
}
