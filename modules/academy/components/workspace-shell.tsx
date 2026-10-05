'use client';
import Link from 'next/link';
import {usePathname} from 'next/navigation';
import type {ReactNode} from 'react';
import {useWords} from './common';
export function WorkspaceShell({name,permissions,children}:{name:string;permissions:string[];children:ReactNode}) {
 const t=useWords(),path=usePathname();
 const links=[['/academy','Start','শুরু',''],['/academy/people','People','ব্যক্তি','people.view'],['/academy/directory','Directory','তালিকা','directory.view'],['/academy/programmes','Programmes','প্রোগ্রাম','academics.view']];
 return <div className="min-h-screen bg-background text-foreground"><header className="border-b p-4"><div className="mx-auto max-w-6xl flex flex-wrap justify-between gap-3"><strong>{t('Academy workspace','একাডেমি কর্মক্ষেত্র')}</strong><span>{name}</span></div></header><nav aria-label={t('Workspace navigation','কর্মক্ষেত্রের মেনু')} className="mx-auto max-w-6xl flex flex-wrap gap-2 p-4">{links.filter(item=>!item[3]||permissions.includes(item[3])).map(([href,en,bn])=><Link key={href} href={href} aria-current={path===href?'page':undefined} className={`rounded-lg border px-4 py-2 ${path===href?'bg-primary text-primary-foreground':''}`}>{t(en,bn)}</Link>)}</nav><main className="mx-auto max-w-6xl p-4 md:p-6">{children}</main></div>;
}
