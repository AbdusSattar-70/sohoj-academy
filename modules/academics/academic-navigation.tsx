'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useEffect,useRef,useState,type ReactNode} from 'react';
import {useWords} from '@/modules/academy/components/common';
export function AcademicNavigation({permissions,children}:{permissions:string[];children:ReactNode}){
 const t=useWords(),path=usePathname(),panel=useRef<HTMLDivElement>(null),[message,setMessage]=useState('');
 const items=[
  {href:'/dashboard/academics',en:'Start here',bn:'এখান থেকে শুরু',show:true},
  {href:'/dashboard/academics/settings',en:'Academic settings',bn:'শিক্ষা সেটিংস',show:permissions.includes('directory.view')||permissions.includes('academics.manage')},
  {href:'/dashboard/academics/programmes',en:'Programme offerings',bn:'Programme offerings',show:permissions.includes('academics.view')},
  {href:'/dashboard/academics/fees',en:'Standard fees',bn:'নির্ধারিত ফি',show:permissions.includes('fees.manage')},
  {href:'/dashboard/academics/batches',en:'Batches',bn:'ব্যাচ',show:permissions.includes('academics.view')},
  {href:'/dashboard/academics/website',en:'Website & applications',bn:'Website ও আবেদন',show:permissions.includes('academics.manage')},
  {href:'/dashboard/academics/routines',en:'Weekly routine',bn:'সাপ্তাহিক রুটিন',show:permissions.includes('academics.view')},
  {href:'/dashboard/academics/calendar',en:'Class calendar',bn:'ক্লাস ক্যালেন্ডার',show:permissions.includes('academics.view')},
  {href:'/dashboard/academics/teaching-hours',en:'Teaching hours',bn:'পাঠদানের সময়',show:permissions.includes('academics.view')},
  {href:'/dashboard/academics/admissions',en:'Admissions',bn:'ভর্তি',show:permissions.includes('admissions.view')},
  {href:'/dashboard/academics/sessions',en:'Class operation',bn:'ক্লাস পরিচালনা',show:permissions.includes('academics.view')},
 ];
 useEffect(()=>{
  function warn(event:BeforeUnloadEvent){if(panel.current?.querySelector('[data-busy="true"], [data-editor][data-dirty="true"]')){event.preventDefault();event.returnValue='';}}
  window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);
 },[]);
 return <section className="space-y-5"><nav data-academic-navigation aria-label={t('Academic work areas','শিক্ষা পরিচালনার কাজ')} className="flex flex-wrap gap-2 border-b pb-3">{items.filter(x=>x.show).map(x=><Link key={x.href} href={x.href} prefetch={false} aria-current={path===x.href?'page':undefined} className={`rounded-lg px-4 py-2.5 text-sm ${path===x.href?'bg-primary text-primary-foreground':'border hover:bg-muted'}`} onNavigate={event=>{
  if(panel.current?.querySelector('[data-busy="true"]')){event.preventDefault();setMessage(t('Confirm the running request before leaving this section.','এই অংশ ছাড়ার আগে চলমান অনুরোধের ফলাফল নিশ্চিত করুন।'));return;}
  if(panel.current?.querySelector('[data-editor][data-dirty="true"]')&&!window.confirm(t('Discard unsaved input and leave this section?','অসংরক্ষিত তথ্য বাদ দিয়ে অন্য অংশে যাবেন?')))event.preventDefault();else setMessage('');
 }}>{t(x.en,x.bn)}</Link>)}</nav>{message&&<p role="status" className="rounded-lg border p-3">{message}</p>}<div ref={panel} data-academic-content>{children}</div></section>;
}
