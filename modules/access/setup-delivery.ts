import {setupError,type SetupFeedback} from './setup-errors';
type ProviderError={message:string;code?:string;status?:number};
type LinkResult={data:unknown;error:{message:string}|null};
type DeliveryResult={error:ProviderError|null};
type SetupDependencies={link:()=>Promise<LinkResult>;invite:()=>Promise<DeliveryResult>;recover:()=>Promise<DeliveryResult>};
/** Called only after server-side permission and reviewed-request validation. */
export async function deliverReviewedSetup({link,invite,recover}:SetupDependencies):Promise<SetupFeedback>{
 const complete=await link();
 let existing=!complete.error&&!!complete.data;
 if(complete.error?.message!=='Account setup is not ready. Retry sending instructions.'&&!existing)return {ok:false,message:complete.error?.message??'Verify the request first.',messageBn:'অনুরোধ, linked identity ও account access যাচাই করুন।',code:'access_link_failed'};
 if(!existing){
  const {error}=await invite();
  if(error){
   if(!['email_exists','user_already_exists'].includes(error.code??'')&&!error.message.toLowerCase().includes('already registered'))return setupError(error);
   // A concurrent invitation may have created the same account. Verify the existing identity before recovery.
   const linked=await link();
   if(linked.error||!linked.data)return {ok:false,message:'The existing account could not be linked. Review identity/access before retrying.',messageBn:'আগের account link হয়নি। পরিচয় ও access যাচাই করুন।',code:'access_link_failed'};
   existing=true;
  }else{
   const linked=await link();
   if(linked.error||!linked.data)return {ok:false,message:'The email service accepted the invitation, but access linking is incomplete. Retry to reuse the same account.',messageBn:'Email service invitation গ্রহণ করেছে; access linking অসম্পূর্ণ। একই account ব্যবহার করে আবার চেষ্টা করুন।',code:'access_link_failed'};
   return {ok:true,message:'The email service accepted the account invitation. Ask the recipient to check inbox and spam; delivery is not confirmed by the app.',messageBn:'Email service account invitation গ্রহণ করেছে। প্রাপক inbox ও spam দেখবেন; application delivery নিশ্চিত করতে পারে না।'};
  }
 }
 const {error}=await recover();
 if(error)return setupError(error);
 return {ok:true,message:'The existing account was reused and the email service accepted fresh password setup/recovery instructions. Check inbox and spam.',messageBn:'আগের account ব্যবহার হয়েছে এবং email service নতুন password setup/recovery নির্দেশনা গ্রহণ করেছে। Inbox ও spam দেখুন।'};
}
