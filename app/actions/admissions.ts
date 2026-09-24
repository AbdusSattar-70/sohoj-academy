"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { admissionSchema, type AdmissionInput } from "@/lib/academy/admission-schema";

export async function createAdmission(input: AdmissionInput) {
  const parsed = admissionSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: "Please check the admission information." };

  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "You must sign in." };

  const d = parsed.data;
  const { data: student, error: studentError } = await supabase.from("students").insert({
    name: d.name, name_bn: d.nameBn || null, gender: d.gender || null,
    date_of_birth: d.dateOfBirth || null, school_name: d.schoolName || null, school_roll: d.schoolRoll || null,
  }).select("id,student_no").single();
  if (studentError || !student) return { ok: false, error: studentError?.message ?? "Could not create student." };

  const { data: guardian, error: guardianError } = await supabase.from("guardians").insert({
    name: d.guardianName, mobile: d.mobile, alternate_mobile: d.alternateMobile || null, address: d.address || null,
  }).select("id").single();
  if (guardianError || !guardian) return { ok: false, error: guardianError?.message ?? "Could not create guardian." };

  const { error: linkError } = await supabase.from("student_guardians").insert({
    student_id: student.id, guardian_id: guardian.id, relationship: d.relationship, is_primary: true,
  });
  if (linkError) return { ok: false, error: linkError.message };

  const { error: enrollmentError } = await supabase.from("enrollments").insert({
    student_id: student.id, academic_year_id: d.academicYearId, class_id: d.classId,
    batch_id: d.batchId || null, program_id: d.programId || null, admission_date: d.admissionDate,
    monthly_fee: d.monthlyFee, discount: d.discount,
  });
  if (enrollmentError) return { ok: false, error: enrollmentError.message };

  revalidatePath("/dashboard/students");
  revalidatePath("/dashboard/admissions");
  return { ok: true, studentNo: student.student_no };
}
