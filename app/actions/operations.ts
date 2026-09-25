"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

type Result = { ok: boolean; error?: string };

async function adminClient() {
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { error: "You must sign in." as const };
  const { data: profile } = await supabase.from("profiles").select("role").eq("id", auth.user.id).single();
  if (!profile || profile.role !== "ADMIN") return { error: "Administrator access required." as const };
  return { supabase };
}

function done(path = "/dashboard/settings"): Result {
  revalidatePath(path);
  revalidatePath("/dashboard");
  return { ok: true };
}

export async function createAcademicYear(formData: FormData): Promise<Result> {
  const ctx = await adminClient(); if ("error" in ctx) return { ok:false,error:ctx.error };
  const name=String(formData.get("name")??"").trim(), starts_on=String(formData.get("starts_on")??""), ends_on=String(formData.get("ends_on")??"");
  if(!name||!starts_on||!ends_on) return {ok:false,error:"Name, start date and end date are required."};
  const {error}=await ctx.supabase.from("academic_years").insert({name,starts_on,ends_on,is_active:formData.get("is_active")==="on"});
  return error?{ok:false,error:error.message}:done();
}
export async function createClass(formData: FormData): Promise<Result> {
  const ctx=await adminClient(); if("error" in ctx)return{ok:false,error:ctx.error};
  const name=String(formData.get("name")??"").trim(); if(!name)return{ok:false,error:"Class name is required."};
  const {error}=await ctx.supabase.from("classes").insert({name,sort_order:Number(formData.get("sort_order")??0)});
  return error?{ok:false,error:error.message}:done();
}
export async function createProgram(formData: FormData): Promise<Result> {
  const ctx=await adminClient(); if("error" in ctx)return{ok:false,error:ctx.error};
  const name=String(formData.get("name")??"").trim(); if(!name)return{ok:false,error:"Program name is required."};
  const code=String(formData.get("code")??"").trim()||null;
  const {error}=await ctx.supabase.from("programs").insert({name,code,is_active:true});
  return error?{ok:false,error:error.message}:done();
}
export async function createSubject(formData: FormData): Promise<Result> {
  const ctx=await adminClient(); if("error" in ctx)return{ok:false,error:ctx.error};
  const name=String(formData.get("name")??"").trim(); if(!name)return{ok:false,error:"Subject name is required."};
  const code=String(formData.get("code")??"").trim()||null;
  const {error}=await ctx.supabase.from("subjects").insert({name,code,is_active:true});
  return error?{ok:false,error:error.message}:done();
}
export async function createBatch(formData: FormData): Promise<Result> {
  const ctx=await adminClient(); if("error" in ctx)return{ok:false,error:ctx.error};
  const name=String(formData.get("name")??"").trim(), academic_year_id=String(formData.get("academic_year_id")??""), class_id=String(formData.get("class_id")??"");
  if(!name||!academic_year_id||!class_id)return{ok:false,error:"Batch name, academic year and class are required."};
  const program=String(formData.get("program_id")??"");
  const {error}=await ctx.supabase.from("batches").insert({name,academic_year_id,class_id,program_id:program||null,capacity:Number(formData.get("capacity")??12),is_active:true});
  return error?{ok:false,error:error.message}:done();
}
export async function createFeeStructure(formData: FormData): Promise<Result> {
  const ctx=await adminClient(); if("error" in ctx)return{ok:false,error:ctx.error};
  const title=String(formData.get("title")??"").trim(), academic_year_id=String(formData.get("academic_year_id")??""), effective_from=String(formData.get("effective_from")??"");
  if(!title||!academic_year_id||!effective_from)return{ok:false,error:"Title, year and effective date are required."};
  const program=String(formData.get("program_id")??""), klass=String(formData.get("class_id")??"");
  const {error}=await ctx.supabase.from("fee_structures").insert({title,academic_year_id,program_id:program||null,class_id:klass||null,amount:Number(formData.get("amount")??0),frequency:"MONTHLY",effective_from});
  return error?{ok:false,error:error.message}:done("/dashboard/fees");
}
