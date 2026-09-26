import { z } from "zod";

export const createStaffInputSchema = z.object({
  fullName: z.string().trim().min(2, "Enter the staff member's full name.").max(120),
  mobile: z.string().trim().max(30).optional(),
  alternateMobile: z.string().trim().max(30).optional(),
  email: z.union([z.string().trim().email("Enter a valid email address."), z.literal("")]).optional(),
  address: z.string().trim().max(500).optional(),
  emergencyContactName: z.string().trim().max(120).optional(),
  emergencyContactMobile: z.string().trim().max(30).optional(),
  joinedOn: z.string().min(1, "Select the joining date."),
  staffRoleCode: z.string().trim().min(1, "Select a Staff role.").max(60),
  subjectIds: z.array(z.string().uuid()).max(30).default([]),
  notes: z.string().trim().max(1000).optional(),
});

export type CreateStaffInput = z.infer<typeof createStaffInputSchema>;
