'use server';
import {z} from 'zod';
import {academyClient} from '@/modules/academy/client';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {caseSchema,optionsSchema,registerSchema,personSchema} from './contracts';
import type {Json} from '@/types/academy-rpc';
import {revalidatePath} from 'next/cache';
const id=z.guid();
export async function admissionOptions(query='',page=1,run?:string){await requireAcademyPermission('admissions.view');z.string().max(160).parse(query);z.number().int().min(1).max(10000).parse(page);if(run)id.parse(run);const {data,error}=await(await academyClient()).rpc('admission_options',{p_query:query,p_page:page,p_run:run});if(error)throw Error(error.message);return optionsSchema.parse(data);}
export async function admissionRegister(query='',page=1,status='DRAFT'){await requireAcademyPermission('admissions.view');const {data,error}=await(await academyClient()).rpc('admission_register',{p_query:query,p_page:page,p_status:status});if(error)throw Error(error.message);return registerSchema.parse(data);}
export async function admissionCase(idValue:string){await requireAcademyPermission('admissions.view');id.parse(idValue);const {data,error}=await(await academyClient()).rpc('admission_case',{p_id:idValue});if(error)throw Error(error.message);return caseSchema.parse(data);}
export async function admissionEnquiry(idValue:string){await requireAcademyPermission('admissions.manage');id.parse(idValue);const {data,error}=await(await academyClient()).rpc('admission_enquiry',{p_id:idValue});if(error)throw Error(error.message);return z.object({payload:z.record(z.string(),z.unknown()),admissionId:z.string().nullable()}).parse(data);}
export async function admissionPeople(query:string,page=1){await requireAcademyPermission('admissions.manage');z.string().trim().min(2).max(160).parse(query);const {data,error}=await(await academyClient()).rpc('admission_person_search',{p_query:query,p_page:page});if(error)throw Error(error.message);return z.array(personSchema).parse(data);}
export async function saveAdmissionDraft(input:{requestId:string;payload:Record<string,unknown>}){
 await requireAcademyPermission('admissions.manage');z.uuid().parse(input.requestId);
 const {data,error}=await(await academyClient()).rpc('save_admission_draft',{p_request_id:input.requestId,p_input:input.payload as Json});
 if(error){if(!error.code)throw Error(error.message);return{ok:false,message:error.message};}
 const result=z.object({id:z.string()}).parse(data);revalidatePath('/dashboard/academics/admissions');return{ok:true,message:'Draft saved.',id:result.id};
}
