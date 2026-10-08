'use client';
import Link from 'next/link';
import {useWords} from '@/modules/academy/components/common';
export function PrintControls({back}:{back:string}){const t=useWords();return <nav className="mb-6 flex gap-4 print:hidden"><Link href={back} className="cursor-pointer rounded-lg border px-4 py-2">{t('← Back to admission','← ভর্তিতে ফিরুন')}</Link><button onClick={()=>window.print()} className="cursor-pointer rounded-lg border px-4 py-2">{t('Print / save PDF','প্রিন্ট / PDF')}</button></nav>;}
