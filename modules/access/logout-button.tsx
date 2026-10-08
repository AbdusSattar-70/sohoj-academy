'use client';
import {useState,useTransition} from 'react';
import {LogOut} from 'lucide-react';
import {signOutAccount} from './session-actions';
import {useWords} from '@/modules/academy/components/common';
export function LogoutButton({compact=false,onBefore}:{compact?:boolean;onBefore?:()=>boolean}){
 const t=useWords(),[pending,start]=useTransition(),[error,setError]=useState('');
 return <div><button type="button" disabled={pending} aria-busy={pending} title={t('Sign out','সাইন আউট')} className="flex min-h-11 w-full cursor-pointer items-center gap-3 rounded-lg border px-3 py-2 hover:bg-muted disabled:cursor-wait" onClick={()=>{if(onBefore&&!onBefore())return;setError('');start(async()=>{try{const result=await signOutAccount();if(!result.ok){setError(t(result.message,'সাইন আউট নিশ্চিত হয়নি। আবার চেষ্টা করুন।'));return;}window.location.replace('/auth/sign-in');}catch{setError(t('Sign out could not be confirmed. Retry.','সাইন আউট নিশ্চিত হয়নি। আবার চেষ্টা করুন।'));}});}}><LogOut className="size-5 shrink-0"/><span className={compact?'sr-only':''}>{pending?t('Signing out…','সাইন আউট হচ্ছে…'):t('Sign out','সাইন আউট')}</span></button>{error&&<p role="alert" className="mt-2 text-sm">{error}</p>}</div>;
}
