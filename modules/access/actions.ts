'use server';
import {z} from 'zod';
import {createClient} from '@supabase/supabase-js';
import {revalidatePath} from 'next/cache';
import {academyClient} from '@/modules/academy/client';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {boundedFetch} from '@/lib/supabase/fetch';
import {databaseId} from '@/lib/database-id';
import {pageSchema} from '@/modules/academy/schema';
import {accessInput,accessRow,reviewInput} from './schema';
export async function requestAccess(input:unknown){
 const parsed=accessInput.safeParse(input);if(!parsed.success)return {ok:false,message:'Check your name, email, role and purpose.'};
 if(parsed.data.website)return {ok:true,message:'Your request has been received. The academy will review it and contact you.'};
 try{const {data,error}=await (await academyClient()).rpc('request_academy_access',{p_input:parsed.data});if(error||!data)return {ok:false,message:'Request could not be received. Check your details or try again later.'};return {ok:true,message:'Your request has been received. The academy will review it and contact you.'};}catch{return {ok:false,message:'Request could not be received. Check your details or try again later.'};}
}
export async function listRequests(page=1,history=false){
 z.number().int().min(1).max(100000).parse(page);z.boolean().parse(history);await requireAcademyPermission('access.manage');
 const {data,error}=await (await academyClient()).rpc('list_access_requests',{p_page:page,p_history:history});if(error)throw Error('Could not load requests.');return pageSchema(accessRow).parse(data);
}
export async function reviewRequest(input:unknown){
 const parsed=reviewInput.safeParse(input);if(!parsed.success)return {ok:false,message:'Check the selected role, identity and verification reason.'};
 try{await requireAcademyPermission('access.manage');const {data,error}=await (await academyClient()).rpc('review_access_request',{p_input:parsed.data});if(error)return {ok:false,message:error.message};revalidatePath('/dashboard','layout');return {ok:true,message:'Review saved.',data:accessRow.parse(data)};}catch{return {ok:false,message:'Review could not be confirmed. Retry the unchanged request.'};}
}
export async function sendSetup(id:string){
 databaseId.parse(id);await requireAcademyPermission('access.manage');
 const db=await academyClient();
 // Resolve only the reviewed request through its scoped database contract.
 const {data:complete,error:existingError}=await db.rpc('complete_access_setup',{p_request_id:id});
 if(!existingError&&complete){revalidatePath('/dashboard','layout');return {ok:true,message:'Account access is linked. Use the existing setup message or sign in; password recovery is available if needed.'};}
 if(existingError?.message!=='Account setup is not ready. Retry sending instructions.')return {ok:false,message:existingError?.message??'Verify the request first.'};
 const key=process.env.SUPABASE_SERVICE_ROLE_KEY,url=process.env.NEXT_PUBLIC_SUPABASE_URL,site=process.env.NEXT_PUBLIC_SITE_URL;
 if(!key||!url||!site)return {ok:false,message:'Account setup email is not configured. Follow Settings & Help → Account configuration.'};
 let origin:URL;try{origin=new URL(site);if(!['http:','https:'].includes(origin.protocol))throw Error();}catch{return {ok:false,message:'Configure a valid site URL.'};}
 const {data:request,error:requestError}=await db.rpc('access_setup_request',{p_request_id:id});
 if(requestError)return {ok:false,message:requestError.message};const row=accessRow.parse(request);
 const admin=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false},global:{fetch:boundedFetch}});
 const {error}=await admin.auth.admin.inviteUserByEmail(row.email,{redirectTo:new URL('/auth/update-password',origin.origin).href});
 if(error)return {ok:false,message:error.message.toLowerCase().includes('api key')?'Account setup email credentials are invalid. Check the server-only service role key for this project.':'Account setup instructions could not be sent. Check the email service configuration and retry.'};
 const {error:linkError}=await db.rpc('complete_access_setup',{p_request_id:id});
 if(linkError)return {ok:false,message:'Setup email was sent, but access linking is incomplete. Retry this action; it will reuse the existing account.'};
 revalidatePath('/dashboard','layout');return {ok:true,message:'Secure account setup instructions have been sent.'};
}
