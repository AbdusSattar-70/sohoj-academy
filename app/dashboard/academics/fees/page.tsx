import {requireAcademyPermission} from '@/modules/academy/queries';
import {OfferingWorkspace} from '@/modules/academy/components/offering-workspace';
export default async function Page(){const context=await requireAcademyPermission('fees.manage');return <OfferingWorkspace area="fees" permissions={context.permissions}/>;}
