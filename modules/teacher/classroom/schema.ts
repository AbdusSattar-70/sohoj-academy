import { z } from "zod";
const id = z.string().uuid();
const reportFields = {
  unit_progress: z
    .array(
      z.object({
        unit_index: z.number().int().nonnegative(),
        status: z.enum(["COVERED", "PARTIAL", "NOT_COVERED"]),
        note: z.string().max(500),
      }),
    )
    .max(200)
    .default([]),
  class_summary: z.string().trim().max(4000).default(""),
  unfinished_reason: z.string().max(2000).default(""),
  homework: z.string().max(2000).default(""),
  next_session_plan: z.string().max(2000).default(""),
};
export const classCommandSchema = z
  .object({
    action: z.enum([
      "START",
      "END",
      "CORRECT_CLOCK",
      "SAVE_REPORT",
      "SUBMIT_REPORT",
    ]),
    session_id: id,
    request_id: id,
    reason: z.string().trim().min(5).max(500),
    started_at: z.string().optional(),
    ended_at: z.string().optional(),
    ...reportFields,
  })
  .superRefine((v, c) => {
    if (
      ["SAVE_REPORT", "SUBMIT_REPORT"].includes(v.action) &&
      v.class_summary.length < 2
    )
      c.addIssue({
        code: "custom",
        path: ["class_summary"],
        message: "Confirm what was taught.",
      });
    if (
      v.unit_progress.some((x) => x.status !== "COVERED") &&
      !v.unfinished_reason.trim()
    )
      c.addIssue({
        code: "custom",
        path: ["unfinished_reason"],
        message: "Select or explain why topics remain incomplete.",
      });
  });
export const classFlowSchema = z.object({
  clock: z
    .object({
      session_id: id,
      teacher_id: id,
      started_at: z.string(),
      ended_at: z.string().nullable(),
    })
    .nullable(),
  reminders: z.array(
    z.object({
      id: z.string(),
      session_id: id,
      date: z.string(),
      batch: z.string(),
      subject: z.string(),
      topic: z.string(),
      kind: z.enum(["CLASS", "EXAM"]),
      title: z.string().nullable(),
      assessment_id: z.string().uuid().nullable(),
      document: z
        .object({
          id,
          status: z.enum(["DRAFT", "SUBMITTED", "RETURNED", "FINAL"]),
          topic: z.string(),
          draft_url: z.string(),
          page_reference: z.string(),
          review_note: z.string().nullable(),
        })
        .nullable(),
    }),
  ),
});
export type ClassFlow = z.infer<typeof classFlowSchema>;
export type ClassCommand = z.input<typeof classCommandSchema>;
