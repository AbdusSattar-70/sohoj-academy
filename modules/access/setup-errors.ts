export type SetupFeedback = {ok:boolean;message:string;messageBn?:string;code?:string;status?:number};
type ProviderError={message?:string;code?:string;status?:number};
/** Return actionable, allowlisted messages; never echo provider response bodies or keys. */
export function setupError(error:ProviderError):SetupFeedback {
 const text=(error.message??'').toLowerCase();
 const code=error.code&&/^[a-z_]{1,60}$/.test(error.code)?error.code:'email_service_error';
 const status=error.status&&error.status>=400&&error.status<=599?error.status:undefined;
 let message='The email service could not confirm delivery. Check Supabase Auth logs and your SMTP provider logs, then retry.',messageBn='ইমেইল পাঠানোর অনুরোধ নিশ্চিত হয়নি। Supabase Auth ও SMTP provider-এর logs দেখে আবার চেষ্টা করুন।';
 if(code==='email_address_not_authorized'||text.includes('email address not authorized')) {
  message='The default email service cannot send to this recipient. Configure custom SMTP in Supabase Authentication; site URL and API keys alone do not enable external delivery.';
  messageBn='Default email service এই ঠিকানায় ইমেইল পাঠাতে পারে না। Supabase Authentication-এ custom SMTP দিন; শুধু site URL ও API key দিলেই বাইরের ঠিকানায় ইমেইল যায় না।';
 }else if(['over_email_send_rate_limit','over_request_rate_limit'].includes(code)||status===429){
  message='The email/request limit was reached. Wait before retrying. The default email service has a small project-wide limit; check Auth rate limits and custom SMTP.';
  messageBn='ইমেইল বা অনুরোধের সীমা শেষ হয়েছে। অপেক্ষা করে আবার চেষ্টা করুন। Auth rate limits ও custom SMTP যাচাই করুন।';
 }else if(['bad_jwt','not_admin','no_authorization','invalid_credentials'].includes(code)||status===401||status===403||text.includes('api key')){
  message='The server credential was rejected. Use this project’s server-only service role/secret key and restart the dev server after changing .env.local.';
  messageBn='Server credential গ্রহণ করা হয়নি। একই project-এর server-only service role/secret key দিন এবং .env.local পরিবর্তনের পরে dev server restart করুন।';
 }else if(code==='email_address_invalid'){
  message='The email service rejected the recipient address. Correct the verified email before sending setup instructions.';
  messageBn='প্রাপকের ইমেইল ঠিকানা গ্রহণ করা হয়নি। যাচাইকৃত ইমেইল সংশোধন করুন।';
 }else if(['request_timeout','hook_timeout','hook_timeout_after_retry'].includes(code)||text.includes('fetch')||text.includes('timeout')||text.includes('aborted')){
  message='The email request timed out. Delivery is unconfirmed; check Auth/email logs before retrying to avoid repeated messages.';
  messageBn='ইমেইল অনুরোধের সময় শেষ। পাঠানো নিশ্চিত নয়; আবার পাঠানোর আগে Auth/email logs দেখুন।';
 }else if(code==='email_provider_disabled'){
  message='Email authentication is disabled in this project. Enable the email provider in Supabase Authentication.';
  messageBn='এই project-এ email authentication বন্ধ। Supabase Authentication-এ email provider চালু করুন।';
 }else if(status&&status>=500){
  message='The authentication/email service failed. Check Auth logs, SMTP host/port, sender verification and SMTP credentials. Retry after correcting the reported provider error.';
  messageBn='Authentication/email service ব্যর্থ হয়েছে। Auth logs, SMTP host/port, sender verification ও SMTP credential যাচাই করুন।';
 }
 return {ok:false,message,messageBn,code,status};
}
