import {redirect} from 'next/navigation';
import {academyContext} from '@/modules/academy/queries';
import {PermissionSettings} from '@/modules/access/permission-settings';
import {loadAccessSettings} from '@/modules/access/permission-actions';
export default async function Page(){if(!(await academyContext())?.roles.includes('ADMIN'))redirect('/dashboard/settings');return <PermissionSettings initial={await loadAccessSettings()}/>;}
