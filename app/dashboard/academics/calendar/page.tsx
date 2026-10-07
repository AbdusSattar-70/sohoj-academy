import {bangladeshToday} from '@/modules/academics/class-time';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {loadAcademicCalendar} from '@/modules/academics/actions';
import {CalendarDesk} from '@/modules/academics/calendar-desk';
export default async function Page({searchParams}:{searchParams:Promise<{from?:string;through?:string}>}){
 await requireAcademyPermission('academics.view');
 const search=await searchParams,today=bangladeshToday(),end=new Date(today+'T00:00:00Z');end.setUTCDate(end.getUTCDate()+6);
 const from=search.from??today,through=search.through??end.toISOString().slice(0,10);
 return <CalendarDesk initial={await loadAcademicCalendar(from,through)}/>;
}
