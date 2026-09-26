"use server";

import { revalidatePath } from "next/cache";
import { createStaffInputSchema, type CreateStaffInput } from "@/modules/staff/schema";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { createClient } from "@/lib/supabase/server";

export type CreateStaffResult =
  | { ok: true; staffNo: string; staffId: string }
  | { ok: false; error: string; field?: string };

export async function createStaffMember(
  input: CreateStaffInput
): Promise<CreateStaffResult> {
  const parsed = createStaffInputSchema.safeParse(input);

  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Please check the Staff information.",
      field: issue?.path?.[0]?.toString(),
    };
  }

  const context = await getErpContext();

  if (!context || !context.permissions.includes("staff.manage")) {
    return { ok: false, error: "You are not authorized to create Staff identities." };
  }

  const value = parsed.data;
  const supabase = await createClient();

  const { data, error } = await supabase.rpc("create_staff_member", {
    p_input: {
      full_name: value.fullName,
      mobile: value.mobile || null,
      alternate_mobile: value.alternateMobile || null,
      email: value.email || null,
      address: value.address || null,
      emergency_contact_name: value.emergencyContactName || null,
      emergency_contact_mobile: value.emergencyContactMobile || null,
      joined_on: value.joinedOn,
      staff_role_code: value.staffRoleCode,
      subject_ids: value.subjectIds,
      notes: value.notes || null,
    },
  });

  if (error) {
    return { ok: false, error: error.message };
  }

  const result = data as {
    staff_id?: string;
    staff_no?: string;
  } | null;

  if (!result?.staff_id || !result.staff_no) {
    return {
      ok: false,
      error: "The Staff workflow completed without returning a permanent identity.",
    };
  }

  revalidatePath("/dashboard/staff");
  revalidatePath("/dashboard");

  return {
    ok: true,
    staffNo: result.staff_no,
    staffId: result.staff_id,
  };
}
