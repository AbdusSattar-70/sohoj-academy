import { z } from 'zod';
export const kinds = ['INSTITUTION','AREA','RELATIONSHIP','SUBJECT','MAJOR','GROUP','PROGRAMME_TYPE','EXPENSE_CATEGORY','DISCOUNT_REASON','LEAD_SOURCE'] as const;
export const responsibilities = ['STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER'] as const;
const id = z.string().uuid();
const optionalId = z.union([id,z.literal('')]).optional();
const text = z.string().trim();
const emptyText = text;
const request = { request_id:id, reason:text.min(5).max(1000) };
const edit = { id:optionalId, revision:z.number().int().min(0).optional() };
const address = z.object({ line:emptyText.max(500).default(''), locality:emptyText.max(160).default('') });
export const personInput = z.object({ ...request,...edit,full_name:text.min(2).max(160),full_name_bn:emptyText.max(160).default(''),
 mobile:emptyText.regex(/^$|^01[3-9][0-9]{8}$/).default(''),email:z.union([z.literal(''),z.string().email()]).default(''),
 date_of_birth:emptyText,present_address:address,permanent_address:address,same_address:z.boolean(),responsibilities:z.array(z.enum(responsibilities)).max(5) });
export const directoryInput = z.object({ ...request,...edit,kind:z.enum(kinds),code:emptyText.max(80).default(''),name:text.min(2).max(160),name_bn:emptyText.max(160).default(''),
 locality:emptyText.max(160).default(''),institution_type:z.enum(['SCHOOL','COLLEGE','MADRASA','UNIVERSITY','OTHER','']).default(''),
 eiin:emptyText.regex(/^$|^[0-9]{6}$/).default(''),source_url:emptyText.max(1000).default(''),verified_on:emptyText,is_verified:z.boolean().default(false),is_active:z.boolean().default(true),sort_order:z.number().int().default(0) });
export const programmeInput = z.object({ ...request,...edit,name:text.min(2).max(160),name_bn:emptyText.max(160).default(''),programme_type_id:id,is_active:z.boolean().default(true) });
export const runInput = z.object({ ...request,...edit,programme_id:id,division_id:id,campus_id:id,academic_year_id:optionalId,class_code:emptyText,
 code:emptyText.max(80).default(''),title:emptyText.max(240).default(''),starts_on:text.min(10),ends_on:text.min(10),guardian_rule:z.enum(['MINOR_REQUIRED','REQUIRED','OPTIONAL']),
 is_active:z.boolean(),website_visible:z.boolean(),applications_open:z.boolean(),application_opens_on:emptyText,application_closes_on:emptyText,
 subject_ids:z.array(id).max(100),public_content:z.object({description:emptyText.max(3000).default(''),schedule:emptyText.max(500).default(''),requirements:emptyText.max(1000).default(''),policy:emptyText.max(1000).default('')}) });
export const feeInput = z.object({ ...request,run_id:id,revision:z.number().int().min(0),cycle:z.enum(['MONTHLY','TERM','COURSE']),due_day:z.number().int().min(1).max(28),
 allowed_discounts:z.array(z.union([z.literal(5),z.literal(10),z.literal(15),z.literal(20),z.literal(25),z.literal(30)])),
 components:z.array(z.object({code:text.min(2).max(80),name:text.min(2).max(120),amount:z.number().finite().min(0),charge_type:z.enum(['TUITION','ADMISSION','EXAM','MATERIAL','OTHER']),recurrence:z.enum(['PER_CYCLE','ONE_TIME'])})).min(1).max(20) });
export const batchInput = z.object({ ...request,...edit,run_id:id,code:emptyText.max(80).default(''),name:text.min(2).max(160),capacity:z.number().int().min(1).max(200),is_active:z.boolean() });
export const yearInput = z.object({ ...request,...edit,name:text.min(2).max(80),starts_on:text.min(10),ends_on:text.min(10),is_active:z.boolean() });
export const activeInput = z.object({ ...request,id,revision:z.number().int().positive(),is_active:z.boolean() });
export const commandSchemas = { person:personInput,directory:directoryInput,programme:programmeInput,run:runInput,fees:feeInput,batch:batchInput,year:yearInput,personActive:activeInput,runActive:activeInput };
export type Command = keyof typeof commandSchemas;
export const contextSchema = z.object({profileId:id,academyId:id,name:z.string(),academyName:z.string(),roles:z.array(z.string()),permissions:z.array(z.string())});
export type AcademyContext = z.infer<typeof contextSchema>;
export const choiceSchema = z.object({id,name:z.string(),name_bn:z.string().nullable().optional(),nameBn:z.string().nullable().optional()});
export type Choice = z.infer<typeof choiceSchema>;
export const directoryRow = directoryInput.omit({request_id:true,reason:true,id:true}).extend({id,revision:z.number(),code:z.string(),name_bn:z.string().nullable(),institution_type:z.string().nullable(),eiin:z.string().nullable()});
// Read contracts are distinct from full editor inputs; optional persisted fields may be null.
export const personSchema = z.object({id,person_no:z.number(),full_name:z.string(),full_name_bn:z.string().nullable(),mobile:z.string().nullable(),email:z.string().nullable(),date_of_birth:z.string().nullable(),
 present_address:z.record(z.string(),z.unknown()),permanent_address:z.record(z.string(),z.unknown()),is_active:z.boolean(),revision:z.number(),responsibilities:z.array(z.enum(responsibilities))});
export type Person = z.infer<typeof personSchema>;
export const personListRow = personSchema.pick({id:true,person_no:true,full_name:true,mobile:true,email:true,is_active:true,revision:true});
export const directoryListRow = z.object({id,code:z.string(),name:z.string(),name_bn:z.string().nullable(),kind:z.enum(kinds),locality:z.string(),institution_type:z.string().nullable(),eiin:z.string().nullable(),source_url:z.string().nullable(),verified_on:z.string().nullable(),is_verified:z.boolean(),is_active:z.boolean(),revision:z.number(),sort_order:z.number()});
export type DirectoryEntry = z.infer<typeof directoryListRow>;
export const programmeRow = z.object({id,name:z.string(),name_bn:z.string().nullable(),programme_type_id:id,is_active:z.boolean(),revision:z.number()});
export const runRow = z.object({id,academy_id:id,division_id:id,campus_id:id,programme_id:id,academic_year_id:id.nullable(),class_code:z.string().nullable(),code:z.string(),title:z.string(),starts_on:z.string(),ends_on:z.string(),guardian_rule:z.enum(['MINOR_REQUIRED','REQUIRED','OPTIONAL']),is_active:z.boolean(),website_visible:z.boolean(),applications_open:z.boolean(),application_opens_on:z.string().nullable(),application_closes_on:z.string().nullable(),public_content:z.record(z.string(),z.unknown()),revision:z.number()});
export type Run = z.infer<typeof runRow>;
export const runListRow = runRow.extend({division_name:z.string(),division_code:z.string(),programme_name:z.string(),campus_name:z.string(),active_batches:z.number()});
export const feeComponent = z.object({id,code:z.string(),name:z.string(),amount:z.number(),charge_type:z.enum(['TUITION','ADMISSION','EXAM','MATERIAL','OTHER']),recurrence:z.enum(['PER_CYCLE','ONE_TIME']),is_active:z.boolean()});
export const setupSchema = z.object({run:runRow,feeSettings:z.object({run_id:id,cycle:z.enum(['MONTHLY','TERM','COURSE']),due_day:z.number(),allowed_discounts:z.array(z.number()),revision:z.number()}).nullable(),components:z.array(feeComponent),subjectIds:z.array(id),batchPage:z.number(),batchPageSize:z.number(),batchTotal:z.number(),batches:z.array(z.object({id,run_id:id,code:z.string(),name:z.string(),capacity:z.number(),occupied:z.number(),is_active:z.boolean(),revision:z.number()}))});
export type RunSetup = z.infer<typeof setupSchema>;
export const choicesSchema = z.object({divisions:z.array(z.object({id,code:z.string(),name:z.string(),nameBn:z.string()})),campuses:z.array(choiceSchema),years:z.array(z.object({id,name:z.string(),starts_on:z.string(),ends_on:z.string(),is_active:z.boolean(),revision:z.number()})),classes:z.array(z.object({code:z.string(),name:z.string(),nameBn:z.string()}))});
export type SetupChoices = z.infer<typeof choicesSchema>;
export function pageSchema<T extends z.ZodType>(row:T) { return z.object({total:z.number().int().nonnegative(),page:z.number().int().positive(),pageSize:z.number().int().positive(),rows:z.array(row)}); }
