'use server';
import {z} from 'zod';
import {academyClient} from '@/modules/academy/client';
import {academyContext} from '@/modules/academy/queries';
import type {Json} from '@/types/academy-rpc';
import {revalidatePath} from 'next/cache';
async function requireAdmin(){const context=await academyContext();if(!context?.roles.includes('ADMIN'))throw Error('Administrator access is required.');}
export async function loadAccessSettings(query='',page=1){
 await requireAdmin();z.string().max(160).parse(query);z.number().int().min(1).max(10000).parse(page);
 const {data,error}=await(await academyClient()).rpc('account_access_settings',{p_query:query,p_page:page});if(error)throw Error(error.message);return data;
}
export async function saveAccessSettings(input:unknown){
 const parsed=z.object({requestId:z.uuid(),payload:z.record(z.string(),z.unknown())}).safeParse(input);
 if(!parsed.success)return{ok:false,message:'Check the selected permissions and account.'};
 try{await requireAdmin();const {error}=await(await academyClient()).rpc('save_account_access',{p_request_id:parsed.data.requestId,p_input:parsed.data.payload as Json});if(error)return{ok:false,message:error.message};revalidatePath('/dashboard','layout');return{ok:true,message:'Access saved. New requests use the updated permissions.'};}catch{return{ok:false,message:'Access change could not be confirmed. Retry the unchanged request.'};}
}
