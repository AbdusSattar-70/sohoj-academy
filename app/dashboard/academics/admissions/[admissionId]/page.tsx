import {requireAcademyPermission} from '@/modules/academy/queries';
import {admissionCase,admissionOptions,admissionBilling} from '@/modules/admissions/actions';
import {AdmissionCaseDesk} from '@/modules/admissions/case-desk';
export default async function Page({params}:{params:Promise<{admissionId:string}>}){const context=await requireAcademyPermission('admissions.view'),data=await admissionCase((await params).admissionId);return <AdmissionCaseDesk initial={data} options={data.status==='DRAFT'?await admissionOptions('',1,data.run_id??undefined):undefined} permissions={context.permissions} invoices={data.status==='ADMITTED'&&context.permissions.includes('billing.view')?await admissionBilling(data.id):undefined}/>;}
