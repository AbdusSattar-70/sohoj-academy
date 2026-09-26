"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { admissionClient } from "./queries";
import { commandSchema, type AdmissionCommand } from "./schema";
import type { Json } from "@/types/database";
export async function runAdmissionCommand(
  input: AdmissionCommand,
): Promise<{ ok: boolean; message: string; field?: string }> {
  const parsed = commandSchema.safeParse(input);
  if (!parsed.success)
    return {
      ok: false,
      message: parsed.error.issues[0].message,
      field: parsed.error.issues[0].path[0]?.toString(),
    };
  const v = parsed.data;
  const context = await getErpContext();
  const permission =
    v.action === "CREATE_BATCH"
      ? "academics.manage"
      : v.action === "PAY"
        ? "finance.payments.post"
        : "admissions.create";
  if (!context?.permissions.includes(permission))
    return {
      ok: false,
      message: "You do not have permission for this action.",
    };
  const payload: Record<string, Json> = {
    action: v.action,
    request_id: v.requestId,
    reason: v.reason,
  };
  const fields = {
    studentName: "student_name",
    guardianName: "guardian_name",
    mobile: "mobile",
    offeringId: "offering_id",
    prospectId: "prospect_id",
    batchId: "batch_id",
    admissionId: "admission_id",
    code: "code",
    name: "name",
    capacity: "capacity",
    amount: "amount",
    paymentMethodId: "payment_method_id",
    externalReference: "external_reference",
  } as const;
  for (const [key, column] of Object.entries(fields)) {
    const value = v[key as keyof typeof fields];
    if (value !== undefined) payload[column] = value;
  }
  const db = await admissionClient();
  const { data, error } = await db.rpc(
    v.action === "PAY" ? "post_admission_payment" : "admission_command",
    { p_input: payload },
  );
  if (error) return { ok: false, message: error.message };
  const result = data as { status?: string; receipt_no?: string };
  for (const path of [
    "/dashboard/admissions",
    "/dashboard/academics/batches",
    "/dashboard/students",
    "/dashboard/crm/prospects",
    "/dashboard/governance/audit",
    "/dashboard",
  ])
    revalidatePath(path);
  return {
    ok: true,
    message: result.receipt_no
      ? `Payment posted. Receipt ${result.receipt_no}.`
      : `Saved: ${(result.status ?? "completed").replaceAll("_", " ")}.`,
  };
}
