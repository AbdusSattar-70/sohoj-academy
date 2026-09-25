"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createStaffSchema, type CreateStaffInput } from "@/modules/staff/schema";

export type CreateStaffResult =
  | { ok: true; staffId: string; staffNo: string }
  | { ok: false; error: string };

export async function createStaffMember(
  input: CreateStaffInput
): Promise<CreateStaffResult> {
  const parsed = createStaffSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Please check the staff information.",
    };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { ok: false, error: "You must sign in." };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || profile?.role !== "ADMIN") {
    return { ok: false, error: "Administrator access is required." };
  }

  const value = parsed.data;

  const { data, error } = await supabase.rpc("create_staff_member", {
    p_input: {
      full_name: value.fullName,
      name_bn: value.nameBn || null,
      mobile: value.mobile || null,
      alternate_mobile: value.alternateMobile || null,
      email: value.email || null,
      address: value.address || null,
      role_code: value.roleCode,
      employment_type: value.employmentType,
      starts_on: value.startsOn,
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
    return { ok: false, error: "Staff record was created without a valid identity response." };
  }

  revalidatePath("/dashboard/staff");
  revalidatePath("/dashboard/teachers");
  revalidatePath("/dashboard");

  return {
    ok: true,
    staffId: result.staff_id,
    staffNo: result.staff_no,
  };
}
