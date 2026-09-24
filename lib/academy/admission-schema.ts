import { z } from "zod";

export const admissionSchema = z.object({
  name: z.string().trim().min(2),
  nameBn: z.string().trim().optional(),
  gender: z.string().trim().optional(),
  dateOfBirth: z.string().optional(),
  schoolName: z.string().trim().optional(),
  schoolRoll: z.string().trim().optional(),
  guardianName: z.string().trim().min(2),
  relationship: z.string().trim().min(2),
  mobile: z.string().trim().min(10),
  alternateMobile: z.string().trim().optional(),
  address: z.string().trim().optional(),
  academicYearId: z.string().uuid(),
  classId: z.string().uuid(),
  batchId: z.string().uuid().optional(),
  programId: z.string().uuid().optional(),
  admissionDate: z.string(),
  monthlyFee: z.coerce.number().min(0),
  discount: z.coerce.number().min(0),
});

export type AdmissionInput = z.infer<typeof admissionSchema>;
