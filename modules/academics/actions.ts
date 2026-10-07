'use server';
import {z} from 'zod';
import {academyClient,verifiedAcademyUser} from '@/modules/academy/client';
import type {Json} from '@/types/academy-rpc';
const envelope=z.object({requestId:z.uuid(),payload:z.record(z.string(),z.unknown())});
export async function loadAcademicDesk(page=1){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_session_register',{p_page:Math.max(1,page)});
 if(error)throw Error(error.message);return data;
}
export async function loadAcademicChoices(section:'SESSION'|'QUALIFICATIONS'|'AVAILABILITY'|'CONTACTS'='SESSION'){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_operation_choices',{p_section:section});
 if(error)throw Error(error.message);return data;
}
export async function loadAcademicSettings(section:'ROOMS'|'WINDOWS'|'CLOSURES'|'CONTACTS'|'EMAILS',page=1){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_settings_register',{p_section:section,p_page:page});
 if(error)throw Error(error.message);return data;
}
export async function saveAcademicOperation(input:unknown){
 const parsed=envelope.safeParse(input);if(!parsed.success)return{ok:false,message:'Check the form input.'};
 if(!await verifiedAcademyUser())return{ok:false,message:'Please sign in again.'};
 const {error}=await(await academyClient()).rpc('academic_command',{p_request_id:parsed.data.requestId,p_payload:parsed.data.payload as Json});
 const action=String(parsed.data.payload.action);
 const nextSteps:Record<string,string>={CREATE:'Class scheduled. Next: the teacher teaches and submits a report.',ROUTINE:'Weekly classes scheduled. Next: the teacher works from the class list.',CHANGE:'Class updated. Change notices are queued; email status is under Academic settings.',CANCEL:'Class cancelled. Next: arrange a linked makeup class when ready.',MAKEUP:'Makeup class scheduled and linked to its original class.',SUBMIT:'Report submitted. Next: an administrator reviews it.',APPROVE:'Teaching report approved.',RETURN:'Report returned. Next: the assigned teacher corrects and resubmits it.'};
 return error?{ok:false,message:error.message}:{ok:true,message:nextSteps[action]??'Saved. Use the next-step link when ready.'};
}

const resourcePayload=z.discriminatedUnion('action',[
 z.object({action:z.literal('QUALIFICATION'),teacherId:z.guid(),subjectId:z.guid(),revision:z.coerce.number().int().min(0),active:z.boolean(),reason:z.string().min(5).max(1000)}),
 z.object({action:z.literal('BLOCK'),id:z.guid().optional(),revision:z.coerce.number().int().min(1).optional(),kind:z.enum(['TEACHER','ROOM']),resourceId:z.guid(),start:z.iso.datetime({offset:true}),end:z.iso.datetime({offset:true}),active:z.boolean(),reason:z.string().min(5).max(1000)}),
]);
export async function loadAcademicResources(page=1){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_resource_register',{p_page:page});if(error)throw Error(error.message);return data;
}
export async function saveAcademicResource(input:unknown){
 const outer=envelope.safeParse(input);if(!outer.success)return{ok:false,message:'Check the request input.'};
 const parsed=resourcePayload.safeParse(outer.data.payload);if(!parsed.success)return{ok:false,message:'Choose a resource, valid dates and a change reason.'};
 if(!await verifiedAcademyUser())return{ok:false,message:'Please sign in again.'};
 const {error}=await(await academyClient()).rpc('save_academic_resource',{p_request_id:outer.data.requestId,p_payload:parsed.data});
 return error?{ok:false,message:error.message}:{ok:true,message:'Resource settings saved.'};
}

const schedulePreviewSchema=z.object({ok:z.boolean(),issues:z.array(z.object({message:z.string()})),warnings:z.array(z.object({message:z.string()})),classes:z.array(z.unknown()),skipped:z.array(z.string())});
export async function checkAcademicSchedule(payload:Record<string,unknown>){
 if(!await verifiedAcademyUser())return{ok:false,message:'Please sign in again.'};
 const {data,error}=await(await academyClient()).rpc('preview_academic_schedule',{p_payload:payload as Json});
 if(error)return{ok:false,message:error.message};
 const result=schedulePreviewSchema.parse(data);
 return{ok:result.ok,message:[result.ok?`${result.classes.length} classes ready; ${result.skipped.length} closed dates skipped.`:'Resolve the following scheduling issues:',...result.issues.map(x=>x.message),...result.warnings.map(x=>`Availability will be added after confirmation: ${x.message}`)].join('\n')};
}

export async function loadAcademicCalendar(from:string,through:string,page=1,status=''){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_calendar',{p_from:from,p_through:through,p_page:page,p_status:status});if(error)throw Error(error.message);return data;
}
export async function loadAcademicSession(id:string){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_session_detail',{p_id:id});if(error)throw Error(error.message);return data;
}
export async function loadAcademicRoutines(page=1){
 if(!await verifiedAcademyUser())throw Error('Please sign in again.');
 const {data,error}=await(await academyClient()).rpc('academic_routine_register',{p_page:page});if(error)throw Error(error.message);return data;
}
export async function saveAcademicRoutine(input:unknown){
 const parsed=envelope.safeParse(input);if(!parsed.success)return{ok:false,message:'Check routine input.'};
 if(!await verifiedAcademyUser())return{ok:false,message:'Please sign in again.'};
 const {error}=await(await academyClient()).rpc('manage_academic_routine',{p_request_id:parsed.data.requestId,p_payload:parsed.data.payload as Json});
 return error?{ok:false,message:error.message}:{ok:true,message:'Routine saved. Existing session history is preserved.'};
}
