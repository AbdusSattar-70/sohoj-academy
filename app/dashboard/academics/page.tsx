import {redirect} from 'next/navigation';
import {academyContext} from '@/modules/academy/queries';
import {AcademicsWorkspace,type AcademicTab} from '@/modules/academy/components/academics-workspace';
export default async function Page({searchParams}:{searchParams:Promise<{tab?:string;section?:string}>}){
 const context=await academyContext();if(!context)redirect('/auth/sign-in?next=/dashboard/academics');
 const canAcademics=context.permissions.includes('academics.view'),canDirectory=context.permissions.includes('directory.view');
 if(!canAcademics&&!canDirectory)throw Error('Academic access is not assigned to this account.');
 const {tab,section}=await searchParams;
 const allowed:AcademicTab[]=[...canAcademics?['programmes' as const]:[],...canAcademics&&context.permissions.includes('people.view')?['admissions' as const]:[],'settings'];
 const selected=allowed.includes(tab as AcademicTab)?tab as AcademicTab:allowed[0];
 const setting=section==='names'&&canAcademics?'names':section==='years'&&canDirectory?'years':canDirectory?'choices':'names';
 return <AcademicsWorkspace key={selected+'_'+setting} permissions={context.permissions} initialTab={selected} initialSetting={setting}/>;
}
