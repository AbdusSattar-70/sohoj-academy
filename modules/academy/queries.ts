import 'server-only';
import { cache } from 'react';
import { redirect } from 'next/navigation';
import { academyClient,verifiedAcademyUser } from './client';
import { contextSchema,choicesSchema,personSchema } from './schema';

export const academyContext = cache(async () => {
  if (!await verifiedAcademyUser()) return null;
  const db = await academyClient();
  const {data,error} = await db.rpc('academy_account_context');
  if(error) throw new Error(error.code === 'PGRST202' ? 'Academy schema is not installed. Follow docs/SETUP.md.' : 'Could not load your academy access. Please retry.');
  return data ? contextSchema.parse(data) : null;
});
export async function requireAcademyPermission(permission:string) {
  const context = await academyContext();
  if(!context) redirect('/auth/sign-in?next=/dashboard');
  if(!context.permissions.includes(permission)) throw new Error('This workspace needs a permitted academy responsibility.');
  return context;
}
export async function setupChoices() {
  await requireAcademyPermission('academics.view');
  const {data,error} = await (await academyClient()).rpc('academy_setup_choices');
  if(error) throw new Error('Could not load setup choices. Please retry.');
  return choicesSchema.parse(data);
}
export async function loadPerson(id:string) {
  await requireAcademyPermission('people.view');
  const {data,error} = await (await academyClient()).rpc('person_profile',{p_person_id:id});
  if(error) throw new Error('Could not load this person. Please retry.');
  return personSchema.parse(data);
}
