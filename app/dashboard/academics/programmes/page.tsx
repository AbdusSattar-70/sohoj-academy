import {requireAcademyPermission} from '@/modules/academy/queries';
import {OfferingWorkspace} from '@/modules/academy/components/offering-workspace';
export default async function Page(){const context=await requireAcademyPermission('academics.view');return <OfferingWorkspace permissions={context.permissions}/>;}
