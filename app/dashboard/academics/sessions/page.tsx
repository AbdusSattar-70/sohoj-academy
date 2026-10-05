import {requireAcademyPermission} from '@/modules/academy/queries';
import {loadAcademicDesk} from '@/modules/academics/actions';
import {SessionDesk} from '@/modules/academics/session-desk';
export default async function Page(){await requireAcademyPermission('academics.view');return <SessionDesk initial={await loadAcademicDesk()}/>;}
