import { z } from "zod";
export const sections = [
  "offerings",
  "batches",
  "rooms",
  "availability",
  "closures",
  "routines",
] as const;
export type PlanningSection = (typeof sections)[number];
export const choiceSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  batch_id: z.string().uuid().optional(),
  subject_id: z.string().uuid().optional(),
  branch_id: z.string().uuid().optional(),
  offering_id: z.string().uuid().optional(),
  capacity: z.number().optional(),
  subjects: z.array(z.string()).optional(),
  offerings: z.array(z.string()).optional(),
  days: z.array(z.number()).optional(),
  starts_on: z.string().nullable().optional(),
  ends_on: z.string().nullable().optional(),
  windows: z
    .array(
      z.object({
        weekday: z.number(),
        start_time: z.string(),
        end_time: z.string(),
      }),
    )
    .optional(),
});
export const planningSchema = z.object({
  section: z.enum(sections),
  page: z.number(),
  total: z.number(),
  choices: z.object({
    curricula: z.array(choiceSchema).default([]),
    branches: z.array(choiceSchema),
    offerings: z.array(choiceSchema),
    batches: z.array(choiceSchema),
    subjects: z.array(choiceSchema),
    teachers: z.array(choiceSchema),
    rooms: z.array(choiceSchema),
  }),
  rows: z.array(z.record(z.string(), z.unknown())),
});
export type PlanningData = z.infer<typeof planningSchema>;
export const calendarSchema = z.object({
  page: z.number(),
  total: z.number(),
  pendingReports: z.number(),
  canManage: z.boolean(),
  rows: z.array(
    z.object({
      id: z.string().uuid(),
      batch_id: z.string().uuid(),
      subject_id: z.string().uuid(),
      teacher_id: z.string().uuid(),
      room_id: z.string().uuid(),
      batch: z.string(),
      subject: z.string(),
      teacher: z.string(),
      room: z.string(),
      session_date: z.string(),
      starts_at: z.string(),
      ends_at: z.string(),
      status: z.string(),
      planned_scope: z.string(),
      attendance: z.string().nullable(),
      approved_revision: z.number().nullable(),
      report_status: z.string().nullable(),
      replacement_for_id: z.string().nullable(),
      change_kind: z.string().nullable(),
    }),
  ),
});
export type CalendarData = z.infer<typeof calendarSchema>;
