import Link from 'next/link';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {databaseId} from '@/lib/database-id';
import {SessionWork} from '@/modules/academics/session-work';
import {loadClassWork,loadAcademicSession} from '@/modules/academics/actions';
import {SessionDesk} from '@/modules/academics/session-desk';
export default async function Page({params}:{params:Promise<{sessionId:string}>}){
 await requireAcademyPermission('academics.view');const id=databaseId.parse((await params).sessionId);
 const [detail,work]=await Promise.all([loadAcademicSession(id),loadClassWork(id)]);
 return <div className="space-y-4"><Link className="cursor-pointer underline" href="/dashboard/academics/calendar" prefetch={false}>← Calendar</Link><SessionDesk initial={detail} detailId={id}/><SessionWork initial={work}/></div>;
}
