'use client';
import Link from 'next/link';
import {useState} from 'react';
import {useWords} from '@/modules/academy/components/common';
import {academicSettingsSections,type AcademicSettingsSection} from './settings-sections';
const nextSteps:Record<AcademicSettingsSection,{href:string;en:string;bn:string}>={
 choices:{href:'/dashboard/academics/settings',en:'Return to academic settings',bn:'শিক্ষা সেটিংসে ফিরুন'},
 years:{href:'?section=subjects',en:'Next: review subjects',bn:'পরের কাজ: বিষয় যাচাই'},subjects:{href:'?section=names',en:'Next: review programme names',bn:'পরের কাজ: প্রোগ্রামের নাম যাচাই'},
 groups:{href:'/dashboard/academics/programmes',en:'Next: choose the group in a programme',bn:'পরের কাজ: প্রোগ্রামে বিভাগ নির্বাচন'},schools:{href:'/dashboard/enquiries',en:'Next: review student applications',bn:'পরের কাজ: শিক্ষার্থীর আবেদন দেখুন'},
 names:{href:'/dashboard/academics/programmes',en:'Next: prepare a programme',bn:'পরের কাজ: প্রোগ্রাম প্রস্তুত করুন'},rooms:{href:'?section=teachers',en:'Next: verify teacher subjects',bn:'পরের কাজ: শিক্ষকের বিষয় যাচাই'},
 teachers:{href:'?section=availability',en:'Next: set weekly available times',bn:'পরের কাজ: সাপ্তাহিক সময় ঠিক করুন'},availability:{href:'?section=holidays',en:'Next: check holidays, then schedule classes',bn:'পরের কাজ: ছুটি দেখে ক্লাসের সময় দিন'},
 holidays:{href:'/dashboard/academics/sessions',en:'Next: schedule classes',bn:'পরের কাজ: ক্লাসের সময় দিন'},contacts:{href:'/dashboard/academics/sessions',en:'Next: run classes and send change notices',bn:'পরের কাজ: ক্লাস ও পরিবর্তনের বার্তা'},emails:{href:'/dashboard/academics/sessions',en:'Return to class operation',bn:'ক্লাস পরিচালনায় ফিরুন'},
};
export function SettingGuide({section}:{section:AcademicSettingsSection}){
 const t=useWords(),[message,setMessage]=useState(''),item=academicSettingsSections.find(x=>x.id===section)!,next=nextSteps[section];
 return <div className="space-y-3 rounded-xl border bg-muted/30 p-4"><p className="text-sm">{t(item.descriptionEn,item.descriptionBn)}</p><div className="flex flex-wrap gap-4">{[{href:'/dashboard/academics/settings',en:'← All academic settings',bn:'← সব শিক্ষা সেটিংস'},next].filter((x,index,items)=>items.findIndex(item=>item.href===x.href)===index).map(x=><Link href={x.href} prefetch={false} key={x.href} className="text-sm underline" onNavigate={e=>{const root=document.querySelector('[data-academic-content]');if(root?.querySelector('[data-busy="true"]')){e.preventDefault();setMessage(t('Confirm the running request before leaving.','চলমান অনুরোধের ফলাফল নিশ্চিত করুন।'));}else if(root?.querySelector('[data-editor][data-dirty="true"]')&&!window.confirm(t('Discard unsaved input?','অসংরক্ষিত তথ্য বাদ দেবেন?')))e.preventDefault();}}>{t(x.en,x.bn)}</Link>)}</div>{message&&<p role="status">{message}</p>}</div>;
}
