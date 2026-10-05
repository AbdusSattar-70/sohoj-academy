import {requireAcademyPermission} from '@/modules/academy/queries';
import {ProgrammesWorkspace} from '@/modules/academy/components/programmes-workspace';
export default async function Page(){const context=await requireAcademyPermission('academics.view');return <ProgrammesWorkspace canManage={context.permissions.includes('academics.manage')} canCreateDirectory={context.permissions.includes('directory.manage')}/>;}
