"use server";

import { createHash, randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { getErpContext } from "@/modules/platform/auth/erp-context";

const inputSchema = z.object({
  admissionId: z.string().uuid(),
  guardianSignedOn: z.iso.date(),
  studentSigned: z.boolean(),
});
const types: Record<string, string> = {
  "application/pdf": "pdf", "image/jpeg": "jpg", "image/png": "png",
};

export async function receiveSignedConsent(formData: FormData): Promise<{ ok: boolean; message: string }> {
  const context = await getErpContext();
  if (!context?.permissions.includes("admissions.create")) return { ok: false, message: "Admission permission required." };
  const parsed = inputSchema.safeParse({
    admissionId: formData.get("admissionId"),
    guardianSignedOn: formData.get("guardianSignedOn"),
    studentSigned: formData.get("studentSigned") === "on",
  });
  if (!parsed.success) return { ok: false, message: "Check the admission case and guardian signing date." };
  const file = formData.get("signedFile");
  if (!(file instanceof File) || file.size<1 || file.size>5*1024*1024 || !types[file.type]) {
    return { ok: false, message: "Attach a PDF, JPEG or PNG signed form up to 5 MB." };
  }
  const bytes = Buffer.from(await file.arrayBuffer());
  const valid = file.type === "application/pdf" ? bytes.subarray(0,5).toString() === "%PDF-" :
    file.type === "image/jpeg" ? bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff :
    bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (!valid) return { ok: false, message: "The selected file does not match its declared format." };
  const hash = createHash("sha256").update(bytes).digest("hex");
  const path = `${parsed.data.admissionId}/${randomUUID()}.${types[file.type]}`;
  const db = await createClient();
  const { error: uploadError } = await db.storage.from("admission-consent")
    .upload(path, bytes, { contentType: file.type, upsert: false });
  if (uploadError) return { ok: false, message: `Upload failed: ${uploadError.message}` };
  const { error } = await db.rpc("record_admission_consent" as never, { p_input: {
    admission_id: parsed.data.admissionId,
    storage_path: path,
    sha256: hash,
    mime_type: file.type,
    file_size: file.size,
    guardian_signed_on: parsed.data.guardianSignedOn,
    student_signed: parsed.data.studentSigned,
  } } as never);
  if (error) return { ok: false, message: `The file uploaded, but its receipt could not be recorded. Contact an administrator with path ${path}. ${error.message}` };
  revalidatePath("/dashboard/admissions");
  return { ok: true, message: "Signed consent received and recorded against the admission case." };
}
