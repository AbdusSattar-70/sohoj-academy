"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import { requireErpContext } from "@/modules/platform/auth/erp-context";

const schema=z.object({
  action:z.enum(["CAPTURE","REQUEST_BONUS","DECIDE_BONUS"]),
  admissionId:z.string().uuid().optional(),
  approvalId:z.string().uuid().optional(),
  source:z.enum(["ORGANIC","REFERRED"]).optional(),
  staffId:z.string().uuid().optional(),
  referrerId:z.string().uuid().optional(),
  fullName:z.string().trim().max(160).optional(),
  mobile:z.string().trim().optional(),
  relationshipNote:z.string().trim().max(160).optional(),
  contactNote:z.string().trim().max(500).optional(),
  decision:z.enum(["APPROVED","REJECTED"]).optional(),
  reason:z.string().trim().min(5).max(500),
}).superRefine((v,ctx)=>{
  if(v.action==="CAPTURE"){
    if(!v.admissionId||!v.source) ctx.addIssue({code:"custom",message:"Choose a referral source."});
    if(v.source==="REFERRED"&&!v.staffId&&!v.referrerId && (!v.fullName||!/^01[3-9][0-9]{8}$/.test(v.mobile??"")))
      ctx.addIssue({code:"custom",message:"Select an existing person or enter the new referrer's name and 11-digit mobile."});
  }
  if(v.action==="REQUEST_BONUS"&&!v.admissionId)ctx.addIssue({code:"custom",message:"Select an admission."});
  if(v.action==="DECIDE_BONUS"&&(!v.approvalId||!v.decision))ctx.addIssue({code:"custom",message:"Choose an approval and decision."});
});
export async function runReferralCommand(input:unknown):Promise<{ok:boolean;message:string}>{
 const parsed=schema.safeParse(input);
 if(!parsed.success)return {ok:false,message:parsed.error.issues[0]?.message??"Invalid referral details."};
 const v=parsed.data;
 const permission=v.action==="CAPTURE"?"admissions.create":v.action==="REQUEST_BONUS"?"staff.compensation.manage":"staff.compensation.approve";
 const context=await requireErpContext();
 if(!context.permissions.includes(permission))return {ok:false,message:"You do not have permission for this action."};
 const db=(await createClient()) as unknown as SupabaseClient;
 const {data,error}=await db.rpc("referral_command",{p_input:{
  action:v.action,request_id:crypto.randomUUID(),reason:v.reason,admission_id:v.admissionId,
  approval_id:v.approvalId,source:v.source,staff_id:v.staffId,referrer_id:v.referrerId,
  full_name:v.fullName,mobile:v.mobile,relationship_note:v.relationshipNote,
  contact_note:v.contactNote,decision:v.decision,
 }});
 if(error)return {ok:false,message:error.message};
 if(v.action!=="CAPTURE") revalidatePath("/dashboard/finance/accounting");
 return {ok:true,message:(data as {message?:string}|null)?.message??"Referral saved."};
}
