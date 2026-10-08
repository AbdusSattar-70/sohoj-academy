import { z } from "zod";
const id = z.string().uuid(),
  option = z.object({ id, label: z.string() });
export const documentRow = z.object({
  id,
  session_id: id,
  author_id: id,
  topic: z.string(),
  page_reference: z.string(),
  draft_url: z.string(),
  status: z.enum(["DRAFT", "SUBMITTED", "RETURNED", "FINAL"]),
  final_question_url: z.string().nullable(),
  final_answer_url: z.string().nullable(),
  review_note: z.string().nullable(),
  batch: z.string(),
  subject: z.string(),
  session_date: z.string(),
  teacher: z.string(),
});
export const questionWorkspace = z.object({
  page: z.number(),
  total: z.number(),
  canReview: z.boolean(),
  rows: z.array(documentRow),
  sessions: z.array(
    option.extend({
      topics: z.array(z.object({ title: z.string() }).passthrough()),
    }),
  ),
});
const evidence = z.object({
  student: z.object({
    id,
    name: z.string(),
    number: z.string(),
    batch: z.string(),
    programme: z.string().nullable(),
    startsOn: z.string(),
    endsOn: z.string(),
    generatedAt: z.string(),
  }),
  attendance: z.array(
    z.object({
      sessionId: id,
      date: z.string(),
      subject: z.string(),
      status: z.string(),
    }),
  ),
  assessments: z.array(
    z.object({
      assessmentId: id,
      date: z.string(),
      title: z.string(),
      subject: z.string(),
      score: z.number(),
      maxMarks: z.number(),
      feedback: z.string().nullable(),
    }),
  ),
  coverage: z.array(
    z.object({
      sessionId: id,
      date: z.string(),
      subject: z.string(),
      summary: z.string(),
      homework: z.string().nullable(),
      progress: z.array(
        z.object({
          title: z.string().nullable(),
          status: z.string(),
          note: z.string().nullable(),
        }),
      ),
      homeworkStatus: z.string().nullable(),
      homeworkFeedback: z.string().nullable(),
    }),
  ),
  scoreTotal: z.number().nullable(),
  maxTotal: z.number().nullable(),
});
export const reportRow = z.object({
  id,
  author_id: id,
  status: z.enum(["DRAFT", "SUBMITTED", "RETURNED", "FINAL"]),
  snapshot: evidence,
  teacher_comment: z.string(),
  home_support: z.array(z.string()),
  review_note: z.string().nullable(),
  author_name: z.string(),
  reviewer_name: z.string().nullable(),
  finalized_at: z.string().nullable(),
});
export const progressWorkspace = z.object({
  page: z.number(),
  total: z.number(),
  canReview: z.boolean(),
  canFinalizeOwn: z.boolean(),
  rows: z.array(reportRow),
  batches: z.array(option),
  students: z.array(option.extend({ batch_id: id })),
});
export type QuestionWorkspace = z.infer<typeof questionWorkspace>;
export type ProgressWorkspace = z.infer<typeof progressWorkspace>;
export type ReportRow = z.infer<typeof reportRow>;
export const commandEnvelope = z.object({
  request_id: id,
  action: z.enum(["SAVE", "SUBMIT", "RETURN", "FINALIZE", "GENERATE"]),
  id: id.optional(),
  session_id: id.optional(),
  assessment_id: id.optional(),
  batch_id: id.optional(),
  student_id: id.optional(),
  topic: z.string().max(300).optional(),
  page_reference: z.string().max(100).optional(),
  draft_url: z.string().max(2000).optional(),
  final_question_url: z.string().max(2000).optional(),
  final_answer_url: z.string().max(2000).optional(),
  academy_copy_confirmed: z.boolean().optional(),
  source_id: z.union([id, z.literal("")]).optional(),
  starts_on: z.iso.date().optional(),
  ends_on: z.iso.date().optional(),
  review_note: z.string().max(1000).optional(),
  teacher_comment: z.string().max(2000).optional(),
  home_support: z.array(z.string()).max(4).optional(),
});

export const studentChoices = z.object({
  rows: z.array(option),
  more: z.boolean(),
});
