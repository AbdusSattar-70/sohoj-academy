import { NextResponse } from "next/server";
import { z } from "zod";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { createClient } from "@/lib/supabase/server";

export async function GET(_request: Request, { params }: { params: Promise<{ admissionId: string; documentId: string }> }) {
  await requirePermission("admissions.view");
  const values = await params;
  if (!z.string().uuid().safeParse(values.admissionId).success || !z.string().uuid().safeParse(values.documentId).success) {
    return new Response("Not found", { status: 404 });
  }
  const db = await createClient();
  const table = db as unknown as { from: (name: string) => { select: (columns: string) => { eq: (column: string, value: string) => { eq: (column: string, value: string) => { maybeSingle: () => Promise<{ data: { storage_path: string } | null; error: unknown }> } } } } };
  const { data } = await table.from("admission_consent_documents").select("storage_path")
    .eq("admission_id",values.admissionId).eq("id",values.documentId).maybeSingle();
  if (!data) return new Response("Not found", { status: 404 });
  const { data: signed, error } = await db.storage.from("admission-consent").createSignedUrl(data.storage_path, 60);
  if (error || !signed?.signedUrl) return new Response("Document unavailable", { status: 503 });
  return NextResponse.redirect(signed.signedUrl);
}
