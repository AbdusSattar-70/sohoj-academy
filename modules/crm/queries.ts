'use server';
import {databaseId} from '@/lib/database-id';
import {z} from 'zod';
import {requireAcademyPermission} from '@/modules/academy/queries';
import {academyClient} from '@/modules/academy/client';
const schema=z.object({total:z.number(),page:z.number(),pageSize:z.number(),rows:z.array(z.object({id:databaseId,enquiry_no:z.number(),status:z.string(),created_at:z.string(),payload:z.object({studentName:z.string(),guardianName:z.string(),mobile:z.string()})}))});
export type EnquiryPage=z.infer<typeof schema>;
export async function loadEnquiries(query='',page=1):Promise<EnquiryPage>{await requireAcademyPermission('people.view');z.string().max(160).parse(query);z.number().int().min(1).max(100000).parse(page);const {data,error}=await(await academyClient()).rpc('search_enquiries',{p_query:query,p_page:page});if(error)throw new Error('Applications could not be loaded.');return schema.parse(data);}
