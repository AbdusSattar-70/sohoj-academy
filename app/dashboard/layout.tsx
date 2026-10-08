import {LogoutButton} from '@/modules/access/logout-button';
import {cookies} from 'next/headers';
import {redirect} from 'next/navigation';
import {academyContext} from '@/modules/academy/queries';
import {verifiedAcademyUser} from '@/modules/academy/client';
import {WorkspaceShell} from '@/modules/academy/components/workspace-shell';
export default async function Layout({children}:{children:React.ReactNode}) {
 if(!await verifiedAcademyUser())redirect('/auth/sign-in?next=/dashboard');
 const context=await academyContext();
 if(!context)return <main className="p-8"><h1>Academy access is not configured</h1><p>An administrator must assign your academy account before you can use this workspace.</p><LogoutButton/></main>;
 return <WorkspaceShell initialDivision={(await cookies()).get('sohoj-workspace')?.value??''} accountId={context.profileId} staffId={context.staffId} roles={context.roles} name={context.name} academyName={context.academyName} divisions={context.divisions} permissions={context.permissions}>{children}</WorkspaceShell>;
}
