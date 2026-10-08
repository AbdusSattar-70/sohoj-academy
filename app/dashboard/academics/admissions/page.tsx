import {redirect} from 'next/navigation';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {admissionRegister,admissionOptions,admissionEnquiry} from '@/modules/admissions/actions';
import {AdmissionRegister} from '@/modules/admissions/register';
export default async function Page({searchParams}:{searchParams:Promise<{enquiry?:string}>}){
 const context=await requireAcademyPermission('admissions.view'),query=await searchParams;
 let prefill:Record<string,unknown>|undefined;
 if(query.enquiry){const source=await admissionEnquiry(query.enquiry);if(source.admissionId)redirect('/dashboard/academics/admissions/'+source.admissionId);const p=source.payload;prefill={studentName:p.studentName??'',studentNameBn:p.studentNameBn??'',guardianName:p.guardianName??'',guardianMobile:p.mobile??'',presentAddress:p.guardianAddress??p.area??''};}
 return <AdmissionRegister initial={await admissionRegister()} canManage={context.permissions.includes('admissions.manage')} canCreate={context.permissions.includes('directory.manage')} prefill={prefill} enquiryId={query.enquiry} initialOptions={query.enquiry?await admissionOptions():undefined}/>;
}
