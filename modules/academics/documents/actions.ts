"use server";
import { revalidatePath } from "next/cache";
import { getErpContext } from "@/modules/platform/auth/erp-context";
import { platformClient } from "@/modules/platform/rpc-client";
import { commandEnvelope, studentChoices } from "./schema";
export async function saveAcademicDocument(
  kind: "questions" | "progress",
  input: unknown,
) {
  const p = commandEnvelope.safeParse(input);
  if (!p.success)
    return {
      ok: false,
      message: p.error.issues[0]?.message ?? "Check highlighted details.",
    };
  if (kind !== "questions" && kind !== "progress")
    return { ok: false, message: "Unknown workflow." };
  const context = await getErpContext();
  if (!context?.permissions.includes("academics.view"))
    return { ok: false, message: "Academic access required." };
  try {
    const { data, error } = await (
      await platformClient()
    ).rpc(
      kind === "questions"
        ? "class_question_document_command"
        : "student_progress_command",
      { p_input: p.data },
    );
    if (error)
      return { ok: false, message: error.message, uncertain: !error.code };
    const id = typeof data?.id === "string" ? data.id : null;
    if (!id)
      return {
        ok: false,
        message: "Result unconfirmed. Retry the same request.",
        uncertain: true,
      };
    revalidatePath("/dashboard/academics/" + kind);
    revalidatePath("/dashboard/teacher");
    return { ok: true, message: "Saved successfully.", id };
  } catch {
    return {
      ok: false,
      message: "Result unconfirmed. Retry the same unchanged request.",
      uncertain: true,
    };
  }
}

export async function getReportStudentChoices(
  batch: string,
  search: string,
  page: number,
) {
  const parsed = commandEnvelope.shape.batch_id.unwrap().safeParse(batch);
  if (
    !parsed.success ||
    search.length > 100 ||
    !Number.isInteger(page) ||
    page < 1 ||
    page > 10000
  )
    return { ok: false as const, message: "Choose a valid batch and search." };
  const context = await getErpContext();
  if (!context?.permissions.includes("academics.view"))
    return { ok: false as const, message: "Academic access required." };
  const { data, error } = await (
    await platformClient()
  ).rpc("student_progress_student_choices", {
    p_batch_id: batch,
    p_search: search,
    p_page: page,
  });
  if (error) return { ok: false as const, message: error.message };
  const result = studentChoices.parse(data);
  return { ok: true as const, ...result };
}
