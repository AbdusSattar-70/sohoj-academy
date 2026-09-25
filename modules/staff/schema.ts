import { z } from "zod";

export const staffRoleCodeSchema = z.enum([
  "ADMINISTRATOR",
  "OPERATOR",
  "TEACHER",
  "COUNSELLOR",
  "ACCOUNTANT",
  "SUPPORT",
]);

export const staffEmploymentTypeSchema = z.enum([
  "FULL_TIME",
  "PART_TIME",
  "CONTRACT",
  "VISITING",
  "OTHER",
]);

export const createStaffSchema = z
  .object({
    fullName: z.string().trim().min(2, "Staff name is required.").max(120),
    nameBn: z.string().trim().max(120).optional(),
    mobile: z.string().trim().max(30).optional(),
    alternateMobile: z.string().trim().max(30).optional(),
    email: z.union([z.string().trim().email("Enter a valid email."), z.literal("")]).optional(),
    address: z.string().trim().max(500).optional(),
    roleCode: staffRoleCodeSchema,
    employmentType: staffEmploymentTypeSchema,
    startsOn: z.string().min(1, "Employment start date is required."),
    subjectIds: z.array(z.string().uuid()).default([]),
    notes: z.string().trim().max(1000).optional(),
  })
  .superRefine((value, ctx) => {
    if (value.roleCode !== "TEACHER" && value.subjectIds.length > 0) {
      ctx.addIssue({
        code: "custom",
        path: ["subjectIds"],
        message: "Subject assignments are only valid for teaching staff.",
      });
    }
  });

export type CreateStaffInput = z.input<typeof createStaffSchema>;
