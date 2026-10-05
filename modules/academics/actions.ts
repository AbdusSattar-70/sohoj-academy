'use server';
import {z} from 'zod';
import {academyClient,verifiedAcademyUser} from '@/modules/academy/client';
import type {Json} from '@/types/academy-rpc';
const envelope=z.object({requestId:z.uuid(),payload:z.record(z.string(),z.unknown())});
export async function loadAcademicDesk(page=1){
 if(!await verifiedAcademyUser())throw Error('Sign in with your academy account.');
 const {data,error}=await(await academyClient()).rpc('academic_workspace',{p_page:Math.max(1,page)});
 if(error)throw Error(error.message);
 const manager=(data as {manage?:boolean})?.manage;if(manager){const resources=await(await academyClient()).rpc('academic_resource_setup');if(resources.error)throw Error(resources.error.message);return {...data as object,resources:resources.data};}return data;
}
export async function saveAcademicOperation(input:unknown){
 const parsed=envelope.safeParse(input);if(!parsed.success)return{ok:false,message:'Check the form input.'};
 if(!await verifiedAcademyUser())return{ok:false,message:'Please sign in again.'};
 const {error}=await(await academyClient()).rpc('academic_command',{p_request_id:parsed.data.requestId,p_payload:parsed.data.payload as Json});
 return error?{ok:false,message:error.message}:{ok:true,message:'Saved. Class-change messages are queued separately.'};
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
