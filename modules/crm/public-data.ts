import {databaseId} from '@/lib/database-id';
import 'server-only';
import {z} from 'zod';
import {academyClient} from '@/modules/academy/client';
const option=z.object({id:z.string(),name:z.string()});
export const catalogueSchema=z.array(z.object({id:databaseId,code:z.string(),title:z.string(),division:z.string(),classCode:z.string().nullable(),startsOn:z.string(),endsOn:z.string(),content:z.record(z.string(),z.unknown()),acceptingApplications:z.boolean(),activeBatches:z.number(),openSeats:z.number(),subjects:z.array(option.extend({nameBn:z.string().nullable()})),fees:z.object({currency:z.string(),cycle:z.string(),dueDay:z.number(),components:z.array(z.object({name:z.string(),amount:z.number(),chargeType:z.string(),recurrence:z.string()}))})}));
const choices=z.object({classes:z.array(option),programmes:z.array(option),subjects:z.array(option),schools:z.array(z.object({id:z.string(),label:z.string()})),sources:z.array(z.object({code:z.string(),name:z.string()})),relationships:z.array(z.object({code:z.string(),name:z.string()}))});
export async function publicCatalogue(){const {data,error}=await(await academyClient()).rpc('public_current_programmes');if(error)return null;return catalogueSchema.parse(data);}
export async function publicChoices(){const {data,error}=await(await academyClient()).rpc('public_application_choices');if(error)throw new Error('Registration choices could not be loaded.');return choices.parse(data);}
