import {requireAcademyPermission} from '@/modules/academy/queries';
import {RequestWorkspace} from '@/modules/access/request-workspace';
export default async function Page(){await requireAcademyPermission('access.manage');return <RequestWorkspace/>;}
