"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

async function staff(roles:string[]) {
 const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser();
 if(!user)return{error:"You must sign in." as const};
 const {data:p}=await supabase.from("profiles").select("role").eq("id",user.id).single();
 if(!p||!roles.includes(p.role))return{error:"Not authorized." as const};
 return{supabase,user};
}
export async function recordPayment(formData:FormData){
 const c=await staff(["ADMIN","OPERATOR"]); if("error" in c)return{ok:false,error:c.error};
 const student_id=String(formData.get("student_id")??""), enrollment_id=String(formData.get("enrollment_id")??"")||null, amount=Number(formData.get("amount")??0);
 if(!student_id||amount<=0)return{ok:false,error:"Student and a valid amount are required."};
 const {data:receipt,error:receiptError}=await c.supabase.rpc("generate_receipt_no");
 if(receiptError)return{ok:false,error:receiptError.message};
 const {error}=await c.supabase.from("payments").insert({receipt_no:receipt,student_id,enrollment_id,amount,payment_date:String(formData.get("payment_date")??""),method:String(formData.get("method")??"CASH"),notes:String(formData.get("notes")??"")||null,collected_by:c.user.id});
 if(error)return{ok:false,error:error.message}; revalidatePath("/dashboard/payments");revalidatePath("/dashboard");return{ok:true,receipt};
}
export async function createAssessment(formData:FormData){
 const c=await staff(["ADMIN","OPERATOR","TEACHER"]);if("error" in c)return{ok:false,error:c.error};
 const academic_year_id=String(formData.get("academic_year_id")??""),batch_id=String(formData.get("batch_id")??""),title=String(formData.get("title")??"").trim();
 if(!academic_year_id||!batch_id||!title)return{ok:false,error:"Year, batch and title are required."};
 const subject=String(formData.get("subject_id")??"");
 const {error}=await c.supabase.from("assessments").insert({academic_year_id,batch_id,subject_id:subject||null,title,assessment_type:String(formData.get("assessment_type")??"WEEKLY"),held_on:String(formData.get("held_on")??""),total_marks:Number(formData.get("total_marks")??100),created_by:c.user.id});
 if(error)return{ok:false,error:error.message};revalidatePath("/dashboard/assessments");return{ok:true};
}
export async function createNotice(formData:FormData){
 const c=await staff(["ADMIN","OPERATOR"]);if("error" in c)return{ok:false,error:c.error};
 const title=String(formData.get("title")??"").trim(),body=String(formData.get("body")??"").trim();if(!title||!body)return{ok:false,error:"Title and notice are required."};
 const publish=formData.get("publish")==="on";
 const {error}=await c.supabase.from("notices").insert({title,body,audience:String(formData.get("audience")??"ALL"),published_at:publish?new Date().toISOString():null,created_by:c.user.id});
 if(error)return{ok:false,error:error.message};revalidatePath("/dashboard/notices");return{ok:true};
}


export async function saveAttendance(formData: FormData) {
 const c=await staff(["ADMIN","OPERATOR","TEACHER"]); if("error" in c)return{ok:false,error:c.error};
 const session_id=String(formData.get("session_id")??"");
 if(!session_id)return{ok:false,error:"Class session is required."};
 const entriesRaw=String(formData.get("entries")??"[]");
 let entries: unknown;
 try { entries=JSON.parse(entriesRaw); } catch { return {ok:false,error:"Invalid attendance data."}; }
 if(!Array.isArray(entries))return{ok:false,error:"Invalid attendance data."};
 const {data,error}=await c.supabase.rpc("save_attendance",{p_session_id:session_id,p_entries:entries});
 if(error)return{ok:false,error:error.message};
 revalidatePath("/dashboard/attendance");revalidatePath("/dashboard");
 return{ok:true,count:Number(data??0)};
}


export async function saveAssessmentResults(formData: FormData) {
 const c=await staff(["ADMIN","OPERATOR","TEACHER"]); if("error" in c)return{ok:false,error:c.error};
 const assessment_id=String(formData.get("assessment_id")??"");
 if(!assessment_id)return{ok:false,error:"Assessment is required."};
 let entries: unknown;
 try { entries=JSON.parse(String(formData.get("entries")??"[]")); } catch { return {ok:false,error:"Invalid result data."}; }
 if(!Array.isArray(entries))return{ok:false,error:"Invalid result data."};
 const {data,error}=await c.supabase.rpc("save_assessment_results",{p_assessment_id:assessment_id,p_entries:entries});
 if(error)return{ok:false,error:error.message};
 revalidatePath("/dashboard/assessments");revalidatePath("/dashboard/progress");
 return{ok:true,count:Number(data??0)};
}
