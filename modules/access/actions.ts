'use server';
import {z} from 'zod';
import {createClient} from '@supabase/supabase-js';
import {revalidatePath} from 'next/cache';
import {academyClient} from '@/modules/academy/client';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {deliverReviewedSetup} from './setup-delivery';
import {setupError,type SetupFeedback} from './setup-errors';
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
function emailClient(){
 const key=process.env.SUPABASE_SECRET_KEY?.trim()||process.env.SUPABASE_SERVICE_ROLE_KEY?.trim(),url=process.env.NEXT_PUBLIC_SUPABASE_URL?.trim(),site=process.env.NEXT_PUBLIC_SITE_URL?.trim();
 if(!key||!url||!site)return {ok:false as const,feedback:{ok:false,message:'Account setup email is not configured. Check the server environment and restart the application.',messageBn:'Account setup email configuration নেই। Server environment যাচাই করে application restart করুন।',code:'configuration_missing'}};
 let origin:URL,project:URL;
 try{origin=new URL(site);project=new URL(url);if(!['http:','https:'].includes(origin.protocol)||!['http:','https:'].includes(project.protocol)||origin.username||origin.password||project.username||project.password)throw Error();}
 catch{return {ok:false as const,feedback:{ok:false,message:'Configure valid HTTP/HTTPS project and site origins.',messageBn:'Project ও site-এর সঠিক HTTP/HTTPS origin দিন।',code:'configuration_invalid'}};}
 // Match master's server-key support and reject public/wrong-project credentials before sending.
 if(key.startsWith('sb_publishable_')||key.includes('YOUR_')||/\s/.test(key))return {ok:false as const,feedback:setupError({code:'not_admin',status:401})};
 if(!key.startsWith('sb_secret_')){
  try{const claims=JSON.parse(Buffer.from(key.split('.')[1]??'','base64url').toString());if(claims.role!=='service_role'||(claims.ref&&project.hostname.endsWith('.supabase.co')&&claims.ref!==project.hostname.split('.')[0]))throw Error();}
  catch{return {ok:false as const,feedback:setupError({code:'not_admin',status:401})};}
 }
 return {ok:true as const,admin:createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false,flowType:'implicit'},global:{fetch:boundedFetch}}),redirectTo:new URL('/auth/update-password',origin.origin).href};
}
export async function checkAccountSetup():Promise<SetupFeedback>{
 await requireAcademyPermission('access.manage');
 const config=emailClient();if(!config.ok)return config.feedback;
 try{const {error}=await config.admin.auth.admin.listUsers({page:1,perPage:1});if(error)return setupError(error);
  return {ok:true,message:'Server credential is accepted by the configured Auth project. This check sends no email; SMTP delivery and redirect allowlists still need verification in Supabase.',messageBn:'Configured Auth project server credential গ্রহণ করেছে। এই যাচাই ইমেইল পাঠায় না; Supabase-এ SMTP delivery ও redirect allowlist যাচাই করুন।'};
 }catch{return setupError({code:'request_timeout'});}
}
export async function sendSetup(id:string):Promise<SetupFeedback>{
 databaseId.parse(id);await requireAcademyPermission('access.manage');
 const config=emailClient();if(!config.ok)return config.feedback;
 try{
  const db=await academyClient();
  const {data:request,error:requestError}=await db.rpc('access_setup_request',{p_request_id:id});
  if(requestError)return {ok:false,message:requestError.message,messageBn:'অনুরোধের পরিচয়, অনুমোদন ও বর্তমান অবস্থা যাচাই করুন।',code:'request_not_ready'};
  const row=accessRow.parse(request);
  return await deliverReviewedSetup({
   link:async()=>{const result=await db.rpc('complete_access_setup',{p_request_id:id});return {data:result.data,error:result.error};},
   invite:()=>config.admin.auth.admin.inviteUserByEmail(row.email,{redirectTo:config.redirectTo,data:{full_name:row.full_name}}),
   recover:()=>config.admin.auth.resetPasswordForEmail(row.email,{redirectTo:config.redirectTo}),
  });
 }catch{return setupError({code:'request_timeout'});}
}
