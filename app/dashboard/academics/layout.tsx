import {redirect} from 'next/navigation';
import {academyContext} from '@/modules/academy/queries';
import {AcademicNavigation} from '@/modules/academics/academic-navigation';
export default async function Layout({children}:{children:React.ReactNode}){
 const context=await academyContext();if(!context)redirect('/auth/sign-in?next=/dashboard/academics');
 if(!context.permissions.some(x=>x==='academics.view'||x==='directory.view'||x==='admissions.view'))throw Error('Academic access is not assigned.');
 return <AcademicNavigation permissions={context.permissions}>{children}</AcademicNavigation>;
}
