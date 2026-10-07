import {requireAcademyPermission} from '@/modules/academy/queries';
import {bangladeshToday} from '@/modules/academics/class-time';
import {loadTeachingHours} from '@/modules/academics/actions';
import {TeachingHours} from '@/modules/academics/teaching-hours';
export default async function Page(){await requireAcademyPermission('academics.view');const through=bangladeshToday(),from=through.slice(0,7)+'-01';return <TeachingHours initial={await loadTeachingHours(from,through)} from={from} through={through}/>;}
