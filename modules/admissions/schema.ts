import { z } from "zod";
const uuid = z.string().uuid();
export const commandSchema = z
  .object({
    action: z.enum([
      "CREATE_BATCH",
      "CREATE",
      "EDIT_DRAFT",
      "READY",
      "REFRESH_FEES",
      "ACCEPT",
      "BILL",
      "ACTIVATE",
      "PAY",
    ]),
    requestId: uuid,
    reason: z
      .string()
      .trim()
      .min(5, "Enter a reason with at least five characters.")
      .max(500),
    offeringId: z.string().optional(),
    prospectId: z.string().optional(),
    batchId: z.string().optional(),
    admissionId: z.string().optional(),
    studentName: z.string().trim().min(2).max(160).optional(),
    guardianName: z.string().trim().min(2).max(160).optional(),
    mobile: z
      .string()
      .regex(/^01[3-9][0-9]{8}$/, "Enter an 11-digit Bangladesh mobile.")
      .optional(),
    code: z.string().trim().max(40).optional(),
    name: z.string().trim().max(160).optional(),
    capacity: z.number().int().positive().max(500).optional(),
    amount: z.number().positive().max(9999999999.99).optional(),
    paymentMethodId: z.string().optional(),
    externalReference: z.string().trim().max(120).optional(),
  })
  .superRefine((v, ctx) => {
    const required =
      v.action === "CREATE_BATCH"
        ? ["offeringId"]
        : v.action === "CREATE"
          ? ["prospectId", "batchId"]
          : v.action === "PAY"
            ? ["admissionId", "paymentMethodId"]
            : ["admissionId"];
    for (const field of required)
      if (!uuid.safeParse(v[field as keyof typeof v]).success)
        ctx.addIssue({
          code: "custom",
          path: [field],
          message: "Select a valid option.",
        });
    if (v.action === "CREATE_BATCH") {
      for (const field of ["code", "name"] as const)
        if ((v[field]?.length ?? 0) < 2)
          ctx.addIssue({
            code: "custom",
            path: [field],
            message: "Enter at least two characters.",
          });
      if (!v.capacity)
        ctx.addIssue({
          code: "custom",
          path: ["capacity"],
          message: "Enter the batch capacity.",
        });
    }
    if (v.action === "EDIT_DRAFT")
      for (const key of ["studentName", "guardianName", "mobile"] as const)
        if (!v[key])
          ctx.addIssue({
            code: "custom",
            path: [key],
            message: "This field is required.",
          });
    if (v.action === "PAY" && !v.amount)
      ctx.addIssue({
        code: "custom",
        path: ["amount"],
        message: "Enter the actual amount received.",
      });
  });
export type AdmissionCommand = z.infer<typeof commandSchema>;
const option = z.object({ id: uuid, name: z.string() });
export const workspaceSchema = z.object({
  offerings: z.array(option.extend({ classId: uuid, className: z.string() })),
  capacityLimit: z.number().nullable(),
  batches: z.array(
    option.extend({
      code: z.string(),
      offeringId: uuid,
      classId: uuid,
      capacity: z.number(),
      occupied: z.number(),
    }),
  ),
  prospects: z.array(
    option.extend({
      number: z.string(),
      classId: uuid.nullable(),
      guardian: z.string(),
      mobile: z.string(),
    }),
  ),
  paymentMethods: z.array(option),
  cases: z.array(
    z.object({
      id: uuid,
      number: z.string(),
      status: z.enum([
        "DRAFT",
        "READY",
        "ACCEPTED",
        "BILLING_POSTED",
        "PENDING_PAYMENT",
        "ACTIVE_ENROLLMENT",
      ]),
      createdAt: z.string(),
      batchId: uuid,
      studentNo: z.string().nullable(),
      studentId: uuid.nullable(),
      name: z.string(),
      guardian: z.string(),
      mobile: z.string(),
      feeVersion: z.number(),
      feePlanId: uuid,
      policyVersion: z.number().nullable(),
      paymentRequirement: z.string().nullable(),
      components: z.array(
        z.object({
          name: z.string(),
          amount: z.number(),
          recurrence: z.string(),
        }),
      ),
      invoice: z
        .object({
          number: z.string(),
          total: z.number(),
          dueOn: z.string(),
          paid: z.number(),
        })
        .nullable(),
      receipts: z.array(
        z.object({
          number: z.string(),
          amount: z.number(),
          postedAt: z.string(),
          method: z.string(),
        }),
      ),
    }),
  ),
});
export type AdmissionWorkspace = z.infer<typeof workspaceSchema>;
export type AdmissionCase = AdmissionWorkspace["cases"][number];
