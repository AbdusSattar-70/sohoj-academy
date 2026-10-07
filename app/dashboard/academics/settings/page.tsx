import {notFound,redirect} from 'next/navigation';
import {academyContext,requireAcademyPermission} from '@/modules/academy/queries';
import {DirectoryWorkspace} from '@/modules/academy/components/directory-workspace';
import {ProgrammesWorkspace} from '@/modules/academy/components/programmes-workspace';
import {YearWorkspace} from '@/modules/academy/components/year-workspace';
import {AcademicSettingsHome} from '@/modules/academics/settings-home';
import {academicSettingsSections} from '@/modules/academics/settings-sections';
import {SettingGuide} from '@/modules/academics/setting-guide';
import {SettingsRegister,type SettingsRegisterKind} from '@/modules/academics/settings-register';
import {TeacherSettings} from '@/modules/academics/teacher-settings';
import {loadAcademicChoices,loadAcademicSettings} from '@/modules/academics/actions';
import {LocalizedText} from '@/components/shared/localized-text';
export default async function Page({searchParams}:{searchParams:Promise<{section?:string}>}){
 const context=await academyContext();if(!context)redirect('/auth/sign-in?next=/dashboard/academics/settings');
 const {section}=await searchParams;
 if(!section)return <AcademicSettingsHome permissions={context.permissions}/>;
 const item=academicSettingsSections.find(x=>x.id===section);if(!item)notFound();
 await requireAcademyPermission(item.permission);
 let content:React.ReactNode;
 if(item.id==='years')content=<YearWorkspace canManage={context.permissions.includes('directory.manage')}/>;
 else if(item.id==='names')content=<ProgrammesWorkspace canManage={context.permissions.includes('academics.manage')} canCreateDirectory={context.permissions.includes('directory.manage')}/>;
 else if(item.id==='subjects'||item.id==='groups'||item.id==='schools')content=<DirectoryWorkspace fixedKind={item.id==='subjects'?'SUBJECT':item.id==='groups'?'GROUP':'INSTITUTION'} canManage={context.permissions.includes('directory.manage')}/>;
 else if(item.id==='choices')content=<DirectoryWorkspace allowedKinds={['AREA','RELATIONSHIP','MAJOR','PROGRAMME_TYPE','DISCOUNT_REASON','LEAD_SOURCE','EXPENSE_CATEGORY']} canManage={context.permissions.includes('directory.manage')}/>;
 else if(item.id==='teachers')content=<TeacherSettings initial={await loadAcademicChoices('QUALIFICATIONS')}/>;
 else{
  const sections:Record<string,SettingsRegisterKind>={rooms:'ROOMS',availability:'WINDOWS',holidays:'CLOSURES',contacts:'CONTACTS',emails:'EMAILS'};
  const kind=sections[item.id];content=<SettingsRegister kind={kind} initial={await loadAcademicSettings(kind)}/>;
 }
 return <section key={item.id} className="space-y-5"><h1 className="text-3xl font-semibold"><LocalizedText en={item.en} bn={item.bn}/></h1><SettingGuide section={item.id}/>{content}</section>;
}
