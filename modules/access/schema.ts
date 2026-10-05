import {z} from 'zod';
import {databaseId} from '@/lib/database-id';
export const roles=['ADMIN','OPERATOR','TEACHER','ACCOUNTANT','REFERRER'] as const;
export const accessInput=z.object({full_name:z.string().trim().min(2).max(160),email:z.email().max(200).transform(v=>v.toLowerCase().trim()),mobile:z.string().trim().regex(/^$|^01[3-9][0-9]{8}$/).default(''),requested_role:z.enum(roles),purpose:z.string().trim().min(5).max(500),website:z.string().max(200).default('')});
export const accessRow=z.object({id:databaseId,request_no:z.number(),email:z.string(),full_name:z.string(),mobile:z.string().nullable(),requested_role:z.enum(roles),purpose:z.string(),status:z.enum(['NEW','VERIFIED','INVITED','ACTIVE','DECLINED']),approved_role:z.enum(roles).nullable(),person_id:databaseId.nullable(),profile_id:databaseId.nullable(),note:z.string().nullable(),revision:z.number(),created_at:z.string()});
export type AccessRequest=z.infer<typeof accessRow>;
export const reviewInput=z.object({id:databaseId,revision:z.number().int().positive(),request_id:z.uuid(),decision:z.enum(['VERIFY','DECLINE']),role:z.enum(roles),person_id:databaseId.optional(),new_identity_confirmed:z.boolean(),reason:z.string().trim().min(5).max(1000)});
