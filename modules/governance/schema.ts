import { z } from "zod";

const uuid = z.string().uuid();

export const adminReviewItemSchema = z.object({
  id: uuid,
  reviewType: z.enum([
    "ATTENDANCE",
    "CLASS_LOG",
    "ASSESSMENT_RESULTS",
    "QUESTION",
  ]),
  entityId: uuid,
  title: z.string(),
  teacherName: z.string(),
  teacherStaffNo: z.string().nullable(),
  batchName: z.string(),
  subjectName: z.string(),
  submittedAt: z.string(),
  revision: z.number(),
  href: z.string().startsWith("/dashboard/"),
});

export const adminReviewQueueSchema = z.array(adminReviewItemSchema);

export type AdminReviewItem = z.infer<typeof adminReviewItemSchema>;
export type AdminReviewQueue = z.infer<typeof adminReviewQueueSchema>;
