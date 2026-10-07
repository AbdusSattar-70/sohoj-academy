'use client';
import {useState,useTransition} from 'react';
import {checkAccountSetup} from './actions';
import type {SetupFeedback} from './setup-errors';
import {useWords} from '@/modules/academy/components/common';
export function SetupDiagnostics(){
 const t=useWords(),[pending,start]=useTransition(),[feedback,setFeedback]=useState<SetupFeedback|null>(null);
 return <div className="space-y-3"><button type="button" disabled={pending} aria-busy={pending} className="rounded-lg border px-4 py-2" onClick={()=>{setFeedback(null);start(async()=>{try{setFeedback(await checkAccountSetup());}catch{setFeedback({ok:false,message:'Configuration check could not be completed. Sign in again or retry.',messageBn:'Configuration যাচাই হয়নি। আবার sign in করুন অথবা পুনরায় চেষ্টা করুন।'});}});}}>{pending?t('Checking configuration…','Configuration যাচাই হচ্ছে…'):t('Check account email configuration','Account email configuration যাচাই')}</button>{feedback&&<p role={feedback.ok?'status':'alert'} className="rounded-lg border p-3 text-sm">{t(feedback.message,feedback.messageBn??feedback.message)}{feedback.code&&<span className="mt-1 block text-xs">{feedback.code}{feedback.status?` · HTTP ${feedback.status}`:''}</span>}</p>}</div>;
}
