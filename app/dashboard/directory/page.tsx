import {requireAcademyPermission} from '@/modules/academy/queries';
import {DirectoryWorkspace} from '@/modules/academy/components/directory-workspace';
export default async function Page(){const context=await requireAcademyPermission('directory.view');return <DirectoryWorkspace canManage={context.permissions.includes('directory.manage')}/>;}
