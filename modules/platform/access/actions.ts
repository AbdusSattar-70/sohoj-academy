"use server";
import { z } from "zod";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { revalidatePath } from "next/cache";
import { getErpContext } from "../auth/erp-context";
import { platformClient } from "../rpc-client";
const roles = z.enum(["ADMIN", "OPERATOR", "TEACHER", "ACCOUNTANT"]);
const requestSchema = z.object({
  full_name: z.string().trim().min(2).max(160),
  email: z.email().max(254),
  mobile: z.string().regex(/^01[3-9][0-9]{8}$/),
  requested_role: roles,
  purpose: z.string().trim().min(5).max(500),
  website: z.string().max(0).optional(),
});
export async function requestStaffAccess(input: unknown) {
  const parsed = requestSchema.safeParse(input);
  if (!parsed.success)
    return {
      ok: false,
      message: parsed.error.issues[0]?.message ?? "Check your details.",
    };
  const db = await platformClient();
  const { error } = await db.rpc("request_staff_access", {
    p_input: parsed.data,
  });
  return error
    ? {
        ok: false,
        message: "Could not receive your request. Please try again.",
      }
    : {
        ok: true,
        message:
          "Request received. The super admin will verify your role and email a secure account setup link. You do not have ERP access yet.",
      };
}
const reviewSchema = z.object({
  id: z.string().uuid(),
  action: z.enum(["VERIFY", "DECLINE", "INVITE"]),
  assigned_role: roles,
  reason: z.string().trim().min(5).max(500),
});
export async function reviewStaffAccess(input: unknown) {
  const parsed = reviewSchema.safeParse(input);
  if (!parsed.success)
    return { ok: false, message: "Choose a role and verification note." };
  const context = await getErpContext();
  if (
    !context?.roles.includes("ADMIN") ||
    !context.permissions.includes("system.users.manage")
  )
    return { ok: false, message: "Super admin verification required." };
  const value = parsed.data,
    db = await platformClient();
  if (value.action !== "INVITE") {
    const { error } = await db.rpc("review_staff_access", { p_input: value });
    if (error) return { ok: false, message: error.message };
  } else {
    const { data: r, error: readError } = await db
      .from("staff_access_requests")
      .select("email,full_name,status")
      .eq("id", value.id)
      .single();
    if (readError || !r || !["VERIFIED", "INVITED"].includes(r.status))
      return {
        ok: false,
        message: "Verify the request before sending an invitation.",
      };
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY,
      origin = process.env.NEXT_PUBLIC_SITE_URL;
    if (!key || !origin)
      return {
        ok: false,
        message:
          "Configure SUPABASE_SERVICE_ROLE_KEY and NEXT_PUBLIC_SITE_URL on the server to send Supabase invitations.",
      };
    const admin = createSupabaseClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      key,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          flowType: "implicit",
        },
      },
    );
    // Invitation email belongs only to this explicitly verified request.
    const { error } = await admin.auth.admin.inviteUserByEmail(r.email, {
      redirectTo: `${origin.replace(/\/$/, "")}/auth/update-password`,
      data: { full_name: r.full_name },
    });
    if (error) {
      if (
        r.status !== "INVITED" &&
        !["email_exists", "user_already_exists"].includes(error.code ?? "")
      )
        return {
          ok: false,
          message: `Invitation failed: ${error.message}. If this account already exists, assign its access under Settings and use password recovery.`,
        };
      const reset = await admin.auth.resetPasswordForEmail(r.email, {
        redirectTo: `${origin.replace(/\/$/, "")}/auth/update-password`,
      });
      if (reset.error) return { ok: false, message: reset.error.message };
    }
    const { error: completeError } = await db.rpc("review_staff_access", {
      p_input: { ...value, action: "COMPLETE_INVITATION" },
    });
    if (completeError)
      return {
        ok: false,
        message: `Invitation sent, but access assignment failed: ${completeError.message}. Retry this verified request; do not create another account.`,
      };
  }
  revalidatePath("/dashboard/settings/access-requests");
  revalidatePath("/dashboard/settings");
  revalidatePath("/dashboard/action-center");
  return {
    ok: true,
    message:
      value.action === "INVITE"
        ? "Supabase setup email sent and assigned access recorded."
        : "Request updated.",
  };
}
