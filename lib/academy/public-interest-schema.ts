import { z } from "zod";

const optionalPhone = z.string().trim().max(30).optional();

export const publicInterestSchema = z.object({
  studentName: z.string().trim().min(2, "Enter the student's name.").max(120),
  studentNameBn: z.string().trim().max(120).optional(),
  guardianName: z.string().trim().min(2, "Enter the guardian's name.").max(120),
  guardianRelationship: z.string().trim().max(40).optional(),
  mobile: z.string().trim().min(10, "Enter a valid mobile number.").max(30),
  alternateMobile: optionalPhone,
  classId: z.string().uuid("Select the student's current class."),
  schoolId: z.string().uuid().optional(),
  schoolNameSnapshot: z.string().trim().max(180).optional(),
  area: z.string().trim().max(180).optional(),
  preferredSchedule: z
    .enum(["MORNING", "AFTERNOON", "EVENING", "FLEXIBLE"])
    .optional(),
  preferredDays: z
    .array(z.enum(["SAT", "SUN", "MON", "TUE", "WED", "THU", "FRI"]))
    .max(7)
    .default([]),
  trialInterest: z.boolean().default(false),
  programIds: z.array(z.string().uuid()).max(10).default([]),
  subjectIds: z.array(z.string().uuid()).max(20).default([]),
  sourceCode: z
    .enum([
      "WALK_IN",
      "SOCIAL",
      "TEACHER_REFERRAL",
      "STUDENT_REFERRAL",
      "GUARDIAN_REFERRAL",
      "SCHOOL_VISIT",
      "OFFLINE_CAMPAIGN",
      "OTHER",
    ])
    .optional(),
  referralNote: z.string().trim().max(240).optional(),
  notes: z.string().trim().max(500).optional(),
  consentToContact: z.boolean().refine((value) => value, {
    message: "Please allow Sohoj Academy to contact you about this interest request.",
  }),
  website: z.string().max(0).optional(),
});

export type PublicInterestInput = z.infer<typeof publicInterestSchema>;
