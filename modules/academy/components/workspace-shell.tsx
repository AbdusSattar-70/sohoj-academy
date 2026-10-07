'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {useRef,useState,type ReactNode} from 'react';
import {LayoutDashboard,UsersRound,GraduationCap,Settings2,MessagesSquare,PanelLeftClose,PanelLeftOpen,ArrowLeftRight,School,BookOpen,BriefcaseBusiness} from 'lucide-react';
import {useWords} from './common';
import {navigation,currentRoute} from '../navigation';
import {OperationScope,useOperationScope} from './operation-scope';
type Props={accountId:string;staffId:string|null;roles:string[];name:string;academyName:string;permissions:string[];divisions:{id:string;name:string;nameBn:string;code:string}[];children:ReactNode};
const icons=[LayoutDashboard,MessagesSquare,UsersRound,GraduationCap,Settings2];
function Shell({name,staffId,roles,academyName,permissions,children}:Props){
 const t=useWords(),path=usePathname(),active=currentRoute(path),[collapsed,setCollapsed]=useState(false),[mobileOpen,setMobileOpen]=useState(false),[choosing,setChoosing]=useState(false),scope=useOperationScope(),main=useRef<HTMLElement>(null),[navigationMessage,setNavigationMessage]=useState('');
 const selectsWorkspace=roles.includes('ADMIN')||permissions.includes('academics.manage');
 const current=scope.divisions.find(d=>d.id===scope.division);
 function guard(event:{preventDefault:()=>void}){
  if(main.current?.querySelector('[data-busy="true"]')){event.preventDefault();setNavigationMessage(t('Confirm the running request before leaving.','চলমান অনুরোধের ফলাফল নিশ্চিত করুন।'));return;}
  if(main.current?.querySelector('[data-editor][data-dirty="true"]')&&!window.confirm(t('Discard unsaved input?','অসংরক্ষিত তথ্য বাদ দেবেন?')))event.preventDefault();else setNavigationMessage('');
 }
 function switchWorkspace(){let blocked=false;guard({preventDefault:()=>{blocked=true;}});if(!blocked){setChoosing(true);setMobileOpen(false);}}
 function workspaceName(d:{code:string;name:string;nameBn:string}){
  return d.code==='TRAINING'?t('Job preparation & training','চাকরি প্রস্তুতি ও প্রশিক্ষণ'):t(d.name,d.nameBn);
 }
 const identity=(compact=false)=><div className={`rounded-lg border p-3 text-sm ${compact?'sr-only':''}`}><p className="font-semibold">{name}</p>{staffId&&<p className="text-xs text-muted-foreground">{staffId}</p>}<p className="mt-1 text-xs">{roles.join(' · ')}</p></div>;
 const workspace=(compact=false)=>selectsWorkspace&&current&&<button type="button" onClick={switchWorkspace} title={t('Switch workspace','কর্মক্ষেত্র পরিবর্তন')} className="flex w-full items-center gap-3 rounded-xl border bg-muted/30 p-3 text-left" aria-label={t('Switch workspace','কর্মক্ষেত্র পরিবর্তন')}><ArrowLeftRight className="size-5 shrink-0" aria-hidden="true"/>{!compact&&<span className="min-w-0"><span className="block text-xs text-muted-foreground">{t('Workspace','কর্মক্ষেত্র')}</span><span className="block text-sm font-medium">{workspaceName(current)}</span><span className="block text-xs text-muted-foreground">{t('Switch','পরিবর্তন করুন')}</span></span>}</button>;
 const groups=navigation.map((g,index)=>({...g,index,items:g.items.filter(i=>!i.permission||(i.permission==='academic.workspace'?permissions.includes('academics.view')||permissions.includes('directory.view'):permissions.includes(i.permission)))})).filter(g=>g.items.length);
 const menu=(compact=false)=><>{groups.map(group=>{const Icon=icons[group.index];return <section key={group.group[0]} className="space-y-1 py-3"><p className={`px-3 pb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground ${compact?'sr-only':''}`}>{t(group.group[0],group.group[1])}</p>{group.items.map(item=><Link prefetch={false} onNavigate={guard} key={item.href} href={item.href} onClick={()=>setMobileOpen(false)} title={t(item.label[0],item.label[1])} aria-current={active?.href===item.href?'page':undefined} className={`flex min-h-11 items-center gap-3 rounded-lg px-3 py-2 text-sm ${active?.href===item.href?'bg-primary text-primary-foreground':'hover:bg-muted'}`}><Icon className="size-5 shrink-0" aria-hidden="true"/><span className={compact?'sr-only':''}>{t(item.label[0],item.label[1])}</span></Link>)}</section>;})}</>;
 if(selectsWorkspace&&(!current||choosing))return <main className="erp-workspace flex min-h-screen items-center justify-center bg-background p-5 text-foreground"><section className="w-full max-w-3xl space-y-6"><div><p className="text-sm text-muted-foreground">{academyName}</p><h1 className="mt-2 text-3xl font-semibold">{t('Where would you like to work?','কোন কর্মক্ষেত্রে কাজ করবেন?')}</h1><p className="mt-3 text-muted-foreground">{t('Choose a workspace to continue. You can switch from the sidebar at any time.','এগিয়ে যেতে কর্মক্ষেত্র নির্বাচন করুন। Sidebar থেকে যেকোনো সময় পরিবর্তন করতে পারবেন।')}</p></div><div className="grid gap-4 sm:grid-cols-3">{scope.divisions.map(d=>{const Icon=d.code==='SCHOOL'?School:d.code==='COACHING'?BookOpen:BriefcaseBusiness;return <button key={d.id} type="button" onClick={()=>{scope.setDivision(d.id);setChoosing(false);}} className="space-y-4 rounded-2xl border bg-card p-6 text-left shadow-sm hover:border-primary focus-visible:ring-2"><Icon className="size-8 text-primary" aria-hidden="true"/><span className="block text-lg font-semibold">{workspaceName(d)}</span><span className="block text-sm text-muted-foreground">{t('Enter workspace →','প্রবেশ করুন →')}</span></button>;})}</div>{!scope.divisions.length&&<p role="alert">{t('No active workspace is configured. Ask your administrator to configure the academy divisions.','সক্রিয় কর্মক্ষেত্র নেই। Academy division প্রস্তুত করতে প্রশাসককে জানান।')}</p>}{identity()}{current&&<button type="button" className="rounded-lg border px-4 py-2" onClick={()=>setChoosing(false)}>{t('Cancel — continue current workspace','বাতিল — বর্তমান কর্মক্ষেত্রে থাকুন')}</button>}</section></main>;
 return <div className="erp-workspace min-h-screen bg-background text-foreground">
  <aside className={`fixed inset-y-0 left-0 z-30 hidden flex-col gap-3 border-r bg-card p-3 lg:flex ${collapsed?'w-20':'w-64'}`}>
   <div className={`flex items-center gap-2 ${collapsed?'flex-col':'justify-between'}`}><Link prefetch={false} onNavigate={guard} href="/dashboard" className="min-w-0 px-2 py-3 font-bold" aria-label={academyName}>{collapsed?'SA':academyName}</Link><button type="button" onClick={()=>setCollapsed(!collapsed)} className="shrink-0 rounded-lg border" aria-expanded={!collapsed} aria-label={t(collapsed?'Expand sidebar':'Collapse sidebar',collapsed?'মেনু বড় করুন':'মেনু ছোট করুন')}>{collapsed?<PanelLeftOpen className="size-5"/>:<PanelLeftClose className="size-5"/>}</button></div>
   {workspace(collapsed)}<nav aria-label={t('ERP navigation','ERP মেনু')} className="flex-1 overflow-y-auto">{menu(collapsed)}</nav>{identity(collapsed)}
  </aside>
  <div className={collapsed?'lg:pl-20':'lg:pl-64'}>
   <header className="sticky top-0 z-20 border-b bg-background/95 px-4 py-3 backdrop-blur"><p className="font-semibold">{active?t(active.label[0],active.label[1]):t('Workspace','কর্মক্ষেত্র')}</p><details className="mt-3 lg:hidden" open={mobileOpen} onToggle={e=>setMobileOpen(e.currentTarget.open)}><summary className="cursor-pointer rounded-lg border px-3 py-2 text-sm">{t('Navigation','মেনু খুলুন')}</summary><nav aria-label={t('Mobile ERP navigation','মোবাইল ERP মেনু')} className="max-h-[65vh] space-y-3 overflow-auto py-3">{workspace()}{menu()}{identity()}</nav></details></header>
   <main ref={main} className="mx-auto max-w-6xl space-y-5 p-4 md:p-6">{navigationMessage&&<p role="status" className="rounded-lg border p-3">{navigationMessage}</p>}{children}</main>
  </div>
 </div>;
}
export function WorkspaceShell(props:Props){return <OperationScope accountId={props.accountId} divisions={props.divisions}><Shell {...props}/></OperationScope>;}
