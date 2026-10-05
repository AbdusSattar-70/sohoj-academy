import {requireAcademyPermission} from '@/modules/academy/queries';
import {PeopleWorkspace} from '@/modules/academy/components/people-workspace';
export default async function Page(){const context=await requireAcademyPermission('people.view');return <PeopleWorkspace permissions={context.permissions}/>;}
