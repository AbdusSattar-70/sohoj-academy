import { z } from "zod";
const id = z.string().uuid(),
  day = z.iso.date(),
  time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
export const timetableSlot = z.object({
  weekday: z.number().int().min(0).max(6),
  subject_id: id,
  teacher_id: id,
  room_id: id,
  start_time: time,
  end_time: time,
  planned_scope: z.string().trim().max(2000).default(""),
});
export const timetableSchema = z
  .object({
    batch_id: id,
    starts_on: day,
    ends_on: day,
    slots: z.array(timetableSlot).min(1).max(40),
    locale: z.enum(["en", "bn"]),
  })
  .superRefine((v, c) => {
    if (v.ends_on < v.starts_on)
      c.addIssue({
        code: "custom",
        path: ["ends_on"],
        message: "End must follow start.",
      });
    v.slots.forEach((s, i) => {
      if (s.end_time <= s.start_time)
        c.addIssue({
          code: "custom",
          path: ["slots", i, "end_time"],
          message: `Row ${i + 1}: end must follow start.`,
        });
    });
  });
export const timetableSaveSchema = timetableSchema.safeExtend({
  request_id: id,
  reason: z.string().trim().min(5).max(500),
});
export const previewSchema = z.object({
  from: day,
  through: day,
  ready: z.boolean(),
  count: z.number(),
  issues: z.array(z.object({ row: z.number(), message: z.string() })),
  classes: z.array(
    z.object({
      row: z.number(),
      date: day,
      start_time: z.string(),
      end_time: z.string(),
      status: z.enum(["READY", "SKIPPED", "CONFLICT"]),
      message: z.string(),
    }),
  ),
});
export type TimetableInput = z.input<typeof timetableSchema>;
export type TimetableSave = z.input<typeof timetableSaveSchema>;
export type TimetablePreview = z.infer<typeof previewSchema>;
