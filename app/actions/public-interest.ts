"use server";

import { createClient } from "@/lib/supabase/server";
import {
  publicInterestSchema,
  type PublicInterestInput,
} from "@/lib/academy/public-interest-schema";

export type PublicInterestResult =
  | { ok: true; prospectNo: string | null }
  | { ok: false; error: string; field?: string | null };

type RpcResult = {
  data: { prospect_no?: string } | null;
  error: { message: string } | null;
};

export async function submitPublicInterest(
  input: PublicInterestInput
): Promise<PublicInterestResult> {
  const parsed = publicInterestSchema.safeParse(input);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Please check the information and try again.",
      field: issue?.path?.[0]?.toString() ?? null,
    };
  }

  const data = parsed.data;

  // Honeypot: pretend success for automated submissions without polluting CRM.
  if (data.website) {
    return { ok: true, prospectNo: null };
  }

  const supabase = await createClient();
  const rpc = supabase.rpc as unknown as (
    fn: "submit_public_interest",
    args: { p_payload: Record<string, unknown> }
  ) => Promise<RpcResult>;

  const { data: result, error } = await rpc("submit_public_interest", {
    p_payload: {
      student_name: data.studentName,
      student_name_bn: data.studentNameBn || "",
      guardian_name: data.guardianName,
      guardian_relationship: data.guardianRelationship || "",
      mobile: data.mobile,
      alternate_mobile: data.alternateMobile || "",
      class_id: data.classId,
      school_id: data.schoolId || "",
      school_name_snapshot: data.schoolNameSnapshot || "",
      area: data.area || "",
      preferred_schedule: data.preferredSchedule || "",
      preferred_days: data.preferredDays.join(","),
      trial_interest: data.trialInterest,
      program_ids: data.programIds,
      subject_ids: data.subjectIds,
      source_code: data.sourceCode || "",
      referral_note: data.referralNote || "",
      notes: data.notes || "",
      consent_to_contact: data.consentToContact,
    },
  });

  if (error) {
    const knownMessages = [
      "A similar interest request was submitted recently.",
      "Student name is required.",
      "Guardian name is required.",
      "A valid mobile number is required.",
      "Consent to contact is required.",
      "Selected class is not available.",
      "Selected school is not available.",
      "Selected source is not available.",
      "One selected program is not available.",
      "One selected subject is not available.",
    ];

    const known = knownMessages.find((message) => error.message.includes(message));
    return {
      ok: false,
      error:
        known ??
        "We could not save your interest request right now. Please try again in a moment.",
    };
  }

  return {
    ok: true,
    prospectNo: result?.prospect_no ?? null,
  };
}
