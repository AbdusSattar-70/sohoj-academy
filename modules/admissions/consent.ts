import { createClient } from "@/lib/supabase/server";

export type ConsentDocument = {
  id: string; admission_id: string; version: number; storage_path: string;
  guardian_signed_on: string; student_signed: boolean; received_at: string;
  sha256: string; mime_type: string; file_size: number;
};

export async function getConsentDocuments(): Promise<ConsentDocument[]> {
  const db = await createClient();
  const table = db as unknown as { from: (name: string) => { select: (columns: string) => { order: (column: string, options: { ascending: boolean }) => Promise<{ data: ConsentDocument[] | null; error: { message: string } | null }> } } };
  const { data, error } = await table.from("admission_consent_documents")
    .select("id,admission_id,version,storage_path,guardian_signed_on,student_signed,received_at,sha256,mime_type,file_size")
    .order("received_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}
