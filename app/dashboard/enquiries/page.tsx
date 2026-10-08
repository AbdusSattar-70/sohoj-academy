import {requireAcademyPermission} from '@/modules/academy/queries';
import {Enquiries} from '@/modules/crm/enquiries';
import {loadEnquiries} from '@/modules/crm/queries';
export default async function Page(){const context=await requireAcademyPermission('people.view');return <Enquiries canAdmit={context.permissions.includes('admissions.manage')} initial={await loadEnquiries()}/>;}
