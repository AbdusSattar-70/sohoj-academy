'use server';
import {databaseId} from '@/lib/database-id';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import { academyClient } from './client';
import { academyContext } from './queries';
import { commandSchemas, pageSchema,personListRow,directoryListRow,programmeRow,runListRow,setupSchema,personSchema,kinds } from './schema';
import type { Command } from './schema';
import type { Json } from '@/types/academy-rpc';
export type MutationResult = {ok:true;data:Json} | {ok:false;code:'invalid'|'permission'|'conflict'|'unavailable';message:string;fields?:Record<string,string>};
const writes = {person:'save_person_profile',directory:'save_directory_entry',programme:'save_programme',run:'save_programme_run',fees:'save_run_fees',batch:'save_teaching_batch',year:'save_academic_year',personActive:'set_person_active',runActive:'set_programme_run_active'} as const;
const permissions:Record<Command,string> = {person:'people.manage',directory:'directory.manage',programme:'academics.manage',run:'academics.manage',fees:'fees.manage',batch:'academics.manage',year:'directory.manage',personActive:'people.manage',runActive:'academics.manage'};
export async function mutateAcademy(command:Command,input:unknown):Promise<MutationResult> {
  if(!Object.hasOwn(commandSchemas,command)) return {ok:false,code:'invalid',message:'Choose a valid action.'};
  const parsed = commandSchemas[command].safeParse(input);
  if(!parsed.success) return {ok:false,code:'invalid',message:'Check the highlighted details.',fields:Object.fromEntries(parsed.error.issues.map(i=>[i.path.join('.'),i.message]))};
  try {
    const context = await academyContext();
    if(!context?.permissions.includes(permissions[command])) return {ok:false,code:'permission',message:'You do not have permission for this action.'};
    const {data,error} = await (await academyClient()).rpc(writes[command],{p_input:parsed.data as Json});
    if(error) {
      if(['42501'].includes(error.code)) return {ok:false,code:'permission',message:'You do not have permission for this action.'};
      if(['23505'].includes(error.code)) return {ok:false,code:'conflict',message:'A matching record already exists. Search and select it or edit the existing record.'};
      if(['P0001'].includes(error.code)) return {ok:false,code:'invalid',message:error.message};
      if(['23514','23502','22P02','22007','22008','22003'].includes(error.code)) return {ok:false,code:'invalid',message:'Check the required fields, dates and amounts.'};
      return {ok:false,code:'unavailable',message:'The result could not be confirmed. Retry the unchanged request.'};
    }
    if(data===null) return {ok:false,code:'unavailable',message:'The result could not be confirmed. Retry the unchanged request.'};
    revalidatePath('/dashboard','layout');
    return {ok:true,data};
  } catch { return {ok:false,code:'unavailable',message:'The result could not be confirmed. Retry the unchanged request.'}; }
}
const searchInput = z.object({query:z.string().max(160).default(''),page:z.number().int().min(1).max(100000).default(1),responsibility:z.enum(['','STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER']).default(''),kind:z.enum([...kinds,'PROGRAMME']).optional(),includeInactive:z.boolean().default(false),division:databaseId.optional()});
export async function searchAcademy(target:'people'|'directory'|'programmes'|'runs',input:unknown) {
  if(!['people','directory','programmes','runs'].includes(target)) throw new Error('Invalid search.');
  const value=searchInput.parse(input),context=await academyContext();
  const permission=target==='people'?'people.view':target==='directory'?'directory.view':'academics.view';
  if(!context?.permissions.includes(permission)) throw new Error('Search access denied.');
  const db=await academyClient();
  if(target==='people') { const {data,error}=await db.rpc('search_people_by_role',{p_query:value.query,p_page:value.page,p_responsibility:value.responsibility});if(error)throw Error('Search failed. Please retry.');return pageSchema(personListRow).parse(data); }
  if(target==='directory') { if(!value.kind||value.kind==='PROGRAMME')throw Error('Choose a directory.');const {data,error}=await db.rpc('search_directory',{p_kind:value.kind,p_query:value.query,p_page:value.page,p_include_inactive:value.includeInactive});if(error)throw Error('Search failed. Please retry.');return pageSchema(directoryListRow).parse(data); }
  if(target==='programmes') {const {data,error}=await db.rpc('search_programme_definitions',{p_query:value.query,p_page:value.page});if(error)throw Error('Search failed. Please retry.');return pageSchema(programmeRow).parse(data);}
  const {data,error}=await db.rpc('list_current_programmes',{p_query:value.query,p_page:value.page,p_division_id:value.division});if(error)throw Error('Search failed. Please retry.');return pageSchema(runListRow).parse(data);
}
export async function fetchRunSetup(id:string,page=1) {
  databaseId.parse(id);z.number().int().min(1).max(100000).parse(page);
  if(!(await academyContext())?.permissions.includes('academics.view'))throw Error('Access denied.');
  const {data,error}=await (await academyClient()).rpc('programme_run_setup',{p_run_id:id,p_batch_page:page});if(error)throw Error('Could not load the programme. Please retry.');return setupSchema.parse(data);
}
export async function fetchPerson(id:string) {
  databaseId.parse(id);if(!(await academyContext())?.permissions.includes('people.view'))throw Error('Access denied.');
  const {data,error}=await (await academyClient()).rpc('person_profile',{p_person_id:id});if(error)throw Error('Could not load the person. Please retry.');return personSchema.parse(data);
}

// Advisory identity matching never creates, merges or grants an account.
export async function findPersonMatches(input:unknown) {
 const value=z.object({full_name:z.string().trim().max(160),mobile:z.string().trim().max(11),email:z.string().trim().max(200),exclude_id:databaseId.optional()}).parse(input);
 if(!(await academyContext())?.permissions.includes('people.view'))throw Error('Access denied.');
 const {data,error}=await (await academyClient()).rpc('find_person_matches',{p_input:value});
 if(error)throw Error('Matching is unavailable.');
 return z.array(personListRow).parse(data);
}
