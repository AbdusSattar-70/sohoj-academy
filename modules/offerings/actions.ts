"use server";

import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { createOfferingClient } from "@/modules/offerings/database-contract";
import {
  createOfferingSchema, publishFeePlanSchema,
  type CreateOfferingInput, type PublishFeePlanInput,
} from "@/modules/offerings/schema";

export type OfferingMutationResult =
  | { ok: true; reference: string }
  | { ok: false; error: string; field?: string };

export async function createProgrammeOffering(input: CreateOfferingInput): Promise<OfferingMutationResult> {
  const parsed = createOfferingSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return { ok: false, error: issue?.message ?? "Check the offering details.", field: issue?.path[0]?.toString() };
  }
  const context = await getErpContext();
  if (!context?.permissions.includes("academics.manage")) {
    return { ok: false, error: "You are not authorized to create offerings." };
  }
  const value = parsed.data;
  const db = await createOfferingClient();
  const { data, error } = await db.rpc("create_programme_offering", { p_input: {
    branch_id: value.branchId,
    academic_year_id: value.academicYearId,
    class_id: value.classId,
    program_id: value.programId,
    group_id: value.groupId || null,
    code: value.code,
    name: value.name,
    reason: value.reason,
  } });
  if (error) return { ok: false, error: error.message };
  const result = data as { offering_id?: string } | null;
  if (!result?.offering_id) return { ok: false, error: "Offering creation returned no identity." };
  revalidatePath("/dashboard/academics/offerings");
  revalidatePath("/dashboard/finance/fee-plans");
  return { ok: true, reference: result.offering_id };
}

export async function publishFeePlan(input: PublishFeePlanInput): Promise<OfferingMutationResult> {
  const parsed = publishFeePlanSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return { ok: false, error: issue?.message ?? "Check the Fee Plan.", field: issue?.path[0]?.toString() };
  }
  const context = await getErpContext();
  if (!context?.permissions.includes("finance.billing.manage")) {
    return { ok: false, error: "You are not authorized to publish Fee Plans." };
  }
  const value = parsed.data;
  const db = await createOfferingClient();
  const { data, error } = await db.rpc("publish_fee_plan", { p_input: {
    offering_id: value.offeringId,
    billing_cycle: value.billingCycle,
    due_day: value.dueDay,
    effective_from: value.effectiveFrom,
    reason: value.reason,
    components: value.components.map((component, sortOrder) => ({
      code: component.code, name: component.name, amount: component.amount,
      charge_type: component.chargeType, recurrence: component.recurrence,
      sort_order: sortOrder,
    })),
  } });
  if (error) return { ok: false, error: error.message };
  const result = data as { fee_plan_version_id?: string; version?: number } | null;
  if (!result?.fee_plan_version_id) return { ok: false, error: "Fee Plan publication returned no version." };
  revalidatePath("/dashboard/academics/offerings");
  revalidatePath("/dashboard/finance/fee-plans");
  return { ok: true, reference: `Version ${result.version}` };
}
