import { z } from "zod";

const id = z.string().uuid("Select a valid option.");
export const createOfferingSchema = z.object({
  branchId: id,
  academicYearId: id,
  classId: id,
  programId: id,
  groupId: z.union([id, z.literal("")]),
  code: z.string().trim().min(2).max(40).regex(/^[A-Za-z0-9_-]+$/, "Use letters, numbers, _ or -."),
  name: z.string().trim().min(2).max(160),
  reason: z.string().trim().min(5, "Explain why this offering is being created.").max(500),
});
export type CreateOfferingInput = z.infer<typeof createOfferingSchema>;

export const publishFeePlanSchema = z.object({
  offeringId: id,
  billingCycle: z.enum(["MONTHLY", "ONE_TIME", "TERM"]),
  dueDay: z.number().int().min(1).max(28).nullable(),
  effectiveFrom: z.iso.date(),
  reason: z.string().trim().min(5, "Explain the fee change.").max(500),
  components: z.array(z.object({
    code: z.string().trim().min(2).max(40).regex(/^[A-Za-z][A-Za-z0-9_]*$/),
    name: z.string().trim().min(2).max(100),
    amount: z.number().finite().min(0).max(9999999999.99),
    chargeType: z.enum(["TUITION", "ADMISSION", "EXAM", "MATERIAL", "OTHER"]),
    recurrence: z.enum(["PER_CYCLE", "ONE_TIME"]),
  })).min(1).max(30),
}).superRefine((value, ctx) => {
  if ((value.billingCycle === "MONTHLY") !== (value.dueDay !== null)) {
    ctx.addIssue({ code: "custom", path: ["dueDay"], message: "Monthly plans need a due day; other plans must leave it blank." });
  }
  if (!value.components.some((item) => item.chargeType === "TUITION" && item.recurrence === "PER_CYCLE")) {
    ctx.addIssue({ code: "custom", path: ["components"], message: "Add a recurring Tuition component." });
  }
  if (new Set(value.components.map((item) => item.code.toUpperCase())).size !== value.components.length) {
    ctx.addIssue({ code: "custom", path: ["components"], message: "Component codes must be unique." });
  }
});
export type PublishFeePlanInput = z.infer<typeof publishFeePlanSchema>;
