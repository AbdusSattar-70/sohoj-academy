import {redirect} from 'next/navigation';
import {academyContext} from '@/modules/academy/queries';
import {AcademicsWorkspace} from '@/modules/academy/components/academics-workspace';
export default async function Page({searchParams}:{searchParams:Promise<{tab?:string;section?:string}>}){
 const {tab,section}=await searchParams;
 if(tab==='programmes')redirect('/dashboard/academics/programmes');
 if(tab==='settings')redirect('/dashboard/academics/settings'+(section==='years'?'?section=years':section==='names'?'?section=names':section==='choices'?'?section=schools':''));
 if(tab==='admissions')redirect('/dashboard/academics/admissions');
 const context=await academyContext();if(!context)redirect('/auth/sign-in?next=/dashboard/academics');
 return <AcademicsWorkspace permissions={context.permissions}/>;
}
