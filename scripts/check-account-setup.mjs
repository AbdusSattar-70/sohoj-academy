import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createRequire} from 'node:module';
const output=await mkdtemp(join(tmpdir(),'sohoj-setup-check-'));
try{
 execFileSync('pnpm',['exec','tsc','modules/access/setup-errors.ts','modules/access/setup-delivery.ts','--module','commonjs','--target','es2022','--skipLibCheck','--outDir',output],{stdio:'inherit'});
 const require=createRequire(import.meta.url);
 const {deliverReviewedSetup}=require(join(output,'setup-delivery.js'));
 const {setupError}=require(join(output,'setup-errors.js'));
 const ready={data:{ready:true},error:null};
 const missing={data:null,error:{message:'Account setup is not ready. Retry sending instructions.'}};
 const rejected={data:null,error:{message:'The account or person is already linked elsewhere.'}};
 async function run(links,inviteError=null,recoveryError=null){
  const calls={link:0,invite:0,recover:0};
  const result=await deliverReviewedSetup({
   link:async()=>links[Math.min(calls.link++,links.length-1)],
   invite:async()=>{calls.invite++;return {error:inviteError};},
   recover:async()=>{calls.recover++;return {error:recoveryError};},
  });
  return {result,calls};
 }
 let value=await run([ready]);assert.equal(value.result.ok,true);assert.deepEqual(value.calls,{link:1,invite:0,recover:1});
 value=await run([missing,ready]);assert.equal(value.result.ok,true);assert.deepEqual(value.calls,{link:2,invite:1,recover:0});
 value=await run([missing,ready],{message:'Email already exists',code:'email_exists'});assert.equal(value.result.ok,true);assert.deepEqual(value.calls,{link:2,invite:1,recover:1});
 value=await run([missing,rejected],{message:'Email already exists',code:'email_exists'});assert.equal(value.result.ok,false);assert.equal(value.calls.recover,0);
 value=await run([rejected]);assert.equal(value.result.ok,false);assert.deepEqual(value.calls,{link:1,invite:0,recover:0});
 value=await run([missing],{message:'Email address not authorized',code:'email_address_not_authorized',status:403});assert.equal(value.result.ok,false);assert.equal(value.result.code,'email_address_not_authorized');assert.match(value.result.message,/custom SMTP/);assert.equal(value.calls.link,1);
 value=await run([ready],null,{message:'Limit reached',code:'over_email_send_rate_limit',status:429});assert.equal(value.result.ok,false);assert.match(value.result.message,/limit/);
 value=await run([missing,rejected]);assert.equal(value.result.ok,false);assert.match(value.result.message,/linking is incomplete/);
 const sentinel='PRIVATE_PROVIDER_RESPONSE_SECRET';const error=setupError({message:sentinel,status:500,code:'unexpected_failure'});assert.equal(JSON.stringify(error).includes(sentinel),false);
 assert.match(setupError({message:'Invalid API key',status:401}).message,/restart/);
 console.log('PASS: existing-account email, new invite, race reuse, link rejection, delivery failures, and safe diagnostics. No real emails were sent.');
}finally{await rm(output,{recursive:true,force:true});}
