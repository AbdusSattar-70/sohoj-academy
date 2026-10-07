import {requireAcademyPermission} from '@/modules/academy/queries';
import {databaseId} from '@/lib/database-id';
import {loadPlacements} from '@/modules/academics/actions';
import {PlacementDesk} from '@/modules/academics/placement-desk';
export default async function Page({params}:{params:Promise<{batchId:string}>}){await requireAcademyPermission('academics.manage');const id=databaseId.parse((await params).batchId);return <PlacementDesk initial={await loadPlacements(id)} batchId={id}/>;}
