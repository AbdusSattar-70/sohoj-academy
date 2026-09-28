"use server";

import { createClient } from "@/lib/supabase/server";
import {
  applicantCorrectionSchema,
  type ApplicantCorrectionInput,
} from "@/lib/academy/applicant-correction-schema";

export type ApplicantCorrectionResult =
  | { ok: true; reference: string }
  | { ok: false; error: string; field?: string | null };

export async function submitApplicantCorrection(
  input: ApplicantCorrectionInput,
): Promise<ApplicantCorrectionResult> {
  const parsed = applicantCorrectionSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Please check the correction details.",
      field: issue?.path?.[0]?.toString() ?? null,
    };
  }

  if (parsed.data.website) return { ok: true, reference: "" };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("submit_applicant_correction", {
    p_payload: {
      prospect_no: parsed.data.prospectNo,
      mobile: parsed.data.mobile,
      requested_changes: parsed.data.requestedChanges,
    },
  });

  if (error) {
    return { ok: false, error: error.message };
  }

  const result = data as { reference?: string } | null;
  if (!result?.reference) {
    return {
      ok: false,
      error: "The correction request returned no reference.",
    };
  }

  return { ok: true, reference: result.reference };
}
