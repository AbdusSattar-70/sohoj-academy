"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import {
  manageMasterRecordSchema,
  type ManageMasterRecordInput,
} from "@/modules/crm/manage/schema";

export type ManageCrmMutationResult =
  | { ok: true; reference: string }
  | { ok: false; error: string; field?: string };

export async function manageCrmMasterRecord(
  input: ManageMasterRecordInput,
): Promise<ManageCrmMutationResult> {
  const parsed = manageMasterRecordSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Check the master-data details.",
      field: issue?.path[0]?.toString(),
    };
  }

  const context = await getErpContext();
  if (!context?.permissions.includes("system.master_data.manage")) {
    return { ok: false, error: "You are not authorized to manage CRM master data." };
  }

  const value = parsed.data;
  const supabase = await createClient();
  const rpcClient = supabase as unknown as {
    rpc: (
      fn: "manage_crm_master_record",
      args: { p_input: Record<string, unknown> },
    ) => Promise<{ data: unknown; error: { message: string } | null }>;
  };

  const { data, error } = await rpcClient.rpc("manage_crm_master_record", {
    p_input: {
      entity: value.entity,
      id: value.id || null,
      code: value.code ?? null,
      name: value.name ?? null,
      description: value.description ?? null,
      sort_order: value.sortOrder ?? 0,
      starts_on: value.startsOn || null,
      ends_on: value.endsOn || null,
      area_id: value.areaId || null,
      is_active: value.isActive,
      is_verified: value.isVerified ?? false,
      reason: value.reason,
    },
  });

  if (error) return { ok: false, error: error.message };
  const result = data as { id?: string; action?: string } | null;
  if (!result?.id) return { ok: false, error: "Master-data change returned no identity." };

  revalidatePath("/dashboard/crm/manage");
  revalidatePath("/dashboard/crm/prospects");
  revalidatePath("/dashboard/academics/offerings");
  revalidatePath("/interest");
  revalidatePath("/");

  return { ok: true, reference: `${result.action ?? "SAVED"}:${result.id}` };
}
