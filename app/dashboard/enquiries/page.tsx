import {Enquiries} from '@/modules/crm/enquiries';
import {loadEnquiries} from '@/modules/crm/queries';
export default async function Page(){return <Enquiries initial={await loadEnquiries()}/>;}
