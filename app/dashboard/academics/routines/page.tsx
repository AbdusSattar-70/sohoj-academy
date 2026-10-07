import {requireAcademyPermission} from '@/modules/academy/queries';
import {loadAcademicRoutines} from '@/modules/academics/actions';
import {RoutineDesk} from '@/modules/academics/routine-desk';
export default async function Page(){await requireAcademyPermission('academics.view');return <RoutineDesk initial={await loadAcademicRoutines()}/>;}
