"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { admissionSchema, type AdmissionInput } from "@/lib/academy/admission-schema";

export async function createAdmission(input: AdmissionInput) {
  const parsed = admissionSchema.safeParse(input);
  if (!parsed.success) {
    const issue = parsed.error.issues[0];
    return {
      ok: false,
      error: issue?.message ?? "Please check the admission information.",
      field: issue?.path?.[0]?.toString() ?? null,
    };
  }

  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "You must sign in." };

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", auth.user.id)
    .single();

  if (!profile || !["ADMIN", "OPERATOR"].includes(profile.role)) {
    return { ok: false, error: "You are not authorized to create admissions." };
  }

  const d = parsed.data;

  const { data, error } = await supabase.rpc("create_admission", {
    p_student: {
      name: d.name,
      name_bn: d.nameBn ?? "",
      gender: d.gender ?? "",
      date_of_birth: d.dateOfBirth ?? "",
      school_name: d.schoolName ?? "",
      school_roll: d.schoolRoll ?? "",
    },
    p_guardian: {
      name: d.guardianName,
      relationship: d.relationship,
      mobile: d.mobile,
      alternate_mobile: d.alternateMobile ?? "",
      address: d.address ?? "",
    },
    p_enrollment: {
      academic_year_id: d.academicYearId,
      class_id: d.classId,
      batch_id: d.batchId ?? "",
      program_id: d.programId ?? "",
      admission_date: d.admissionDate,
      monthly_fee: d.monthlyFee,
      discount: d.discount,
    },
  });

  if (error) return { ok: false, error: error.message };

  revalidatePath("/dashboard/students");
  revalidatePath("/dashboard/admissions");

  const result = data as {
    student_id?: string;
    student_no?: string;
    guardian_id?: string;
    enrollment_id?: string;
  } | null;

  return {
    ok: true,
    studentId: result?.student_id ?? null,
    studentNo: result?.student_no ?? null,
  };
}
