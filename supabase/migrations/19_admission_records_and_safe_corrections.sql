-- Academy rolls are generated at student creation, never entered on an application.
alter table public.students add column academy_roll bigint generated always as identity;
create unique index student_academy_roll_unique on public.students(academy_roll);

alter function public.admission_case_detail(uuid) rename to admission_case_detail_core;
revoke all on function public.admission_case_detail_core(uuid) from public,anon,authenticated;
create or replace function public.admission_case_detail(p_admission_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 result:=public.admission_case_detail_core(p_admission_id);
 return result||(select jsonb_build_object('academyRoll',s.academy_roll::text,'discountPercent',a.selected_discount_percent,'discountReason',a.discount_reason,'additionalDetails',
 jsonb_build_object('father_name',a.identity_snapshot->>'father_name','mother_name',a.identity_snapshot->>'mother_name',
 'birth_registration',a.identity_snapshot->>'birth_registration','permanent_address',a.identity_snapshot->>'permanent_address',
 'emergency_contact',a.identity_snapshot->>'emergency_contact','emergency_mobile',a.identity_snapshot->>'emergency_mobile',
 'previous_result',a.identity_snapshot->>'previous_result','learning_needs',a.identity_snapshot->>'learning_needs'))
 from public.admission_cases a left join public.students s on s.id=a.student_id where a.id=p_admission_id);
end $$;
revoke all on function public.admission_case_detail(uuid) from public,anon;
grant execute on function public.admission_case_detail(uuid) to authenticated;

-- Preserve optional family/support information without publishing it as master data.
alter function public.create_staff_admission_intake(jsonb) rename to create_staff_admission_intake_core;
revoke all on function public.create_staff_admission_intake_core(jsonb) from public,anon,authenticated;
create or replace function public.create_staff_admission_intake(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; extras jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if octet_length(p_input::text)>10000 then raise exception 'Application is too long.'; end if;
 if not exists(select 1 from public.organizations where code='SOHOJ' and setup_completed_at is not null and is_active) then raise exception 'Complete academy setup before starting admissions.'; end if;
 result:=public.create_staff_admission_intake_core(p_input);
 extras:=jsonb_build_object('father_name',left(p_input->>'father_name',160),'mother_name',left(p_input->>'mother_name',160),
 'birth_registration',left(p_input->>'birth_registration',40),'permanent_address',left(p_input->>'permanent_address',300),
 'emergency_contact',left(p_input->>'emergency_contact',160),'emergency_mobile',left(p_input->>'emergency_mobile',30),
 'previous_result',left(p_input->>'previous_result',200),'learning_needs',left(p_input->>'learning_needs',500));
 update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(extras)
 where id=(result->>'admission_id')::uuid;
 return result;
end $$;
revoke all on function public.create_staff_admission_intake(jsonb) from public,anon;
grant execute on function public.create_staff_admission_intake(jsonb) to authenticated;

-- Preserve the public statement while carrying all relevant information into the draft.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.create_prospect_admission(jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'result:=public.admission_command(p_input);',
 $enrich$if not exists(select 1 from public.organizations where id=o.organization_id and setup_completed_at is not null and is_active) then raise exception 'Complete academy setup before starting admissions.'; end if;
 result:=public.admission_command(p_input);
 update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(jsonb_build_object(
 'guardian_address',coalesce(p.guardian_address,p.application_snapshot->>'guardian_address'),
 'alternate_mobile',p.alternate_mobile,'student_name_bn',p.student_name_bn,
 'date_of_birth',coalesce(p.date_of_birth::text,p.application_snapshot->>'date_of_birth'),
 'gender',coalesce(p.gender,p.application_snapshot->>'gender'),
 'school_roll',coalesce(p.school_roll,p.application_snapshot->>'school_roll'),
 'father_name',p.application_snapshot->>'father_name','mother_name',p.application_snapshot->>'mother_name',
 'emergency_contact',p.application_snapshot->>'emergency_contact','emergency_mobile',p.application_snapshot->>'emergency_mobile',
 'learning_needs',p.application_snapshot->>'learning_needs'))
 where id=(result->>'id')::uuid;$enrich$);
 execute definition;
end $migration$;

-- Matching the partial unique index is required for safe idempotent discount posting.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.apply_invoice_discounts(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'where discount_id is not null','where kind=''DISCOUNT'' and discount_id is not null');
 execute definition;
end $migration$;

create or replace function public.edit_staff_record(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare s public.staff; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('staff.manage') then raise exception 'Staff management permission required.'; end if;
 if length(btrim(coalesce(p_input->>'full_name',''))) not between 2 and 160 or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Staff name and correction reason required.'; end if;
 select * into s from public.staff where id=(p_input->>'id')::uuid for update;
 if s.id is null then raise exception 'Staff not found.'; end if;
 before_data:=to_jsonb(s);
 update public.staff set full_name=btrim(p_input->>'full_name'),mobile=nullif(btrim(p_input->>'mobile'),''),
  address=case when p_input ? 'address' then nullif(btrim(p_input->>'address'),'') else address end,notes=case when p_input ? 'notes' then nullif(btrim(p_input->>'notes'),'') else notes end where id=s.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'STAFF',s.id::text,'CORRECT_DETAILS',p_input->>'reason',before_data,p_input);
 return jsonb_build_object('id',s.id);
end $$;
revoke all on function public.edit_staff_record(jsonb) from public,anon;
grant execute on function public.edit_staff_record(jsonb) to authenticated;

-- Permanent identities and financial evidence cannot be deleted, including via RLS ALL policies.
create or replace function public.prevent_permanent_record_delete()
returns trigger language plpgsql set search_path=public as $$
begin raise exception 'Do not delete this record. Use edit, inactive, withdrawal or a recorded financial correction.'; end $$;
do $migration$
declare table_name text;
begin
 foreach table_name in array array['organizations','branches','profiles','staff','schools','academic_years','classes','academic_groups','subjects','programs','students','guardians','prospects','batches','enrollments','admission_cases','admission_invoices','admission_invoice_lines','admission_payments','invoice_credits','admission_physical_consent_receipts','staff_access_requests'] loop
 execute format('create trigger preserve_permanent_record before delete on public.%I for each row execute function public.prevent_permanent_record_delete()',table_name);
 end loop;
end $migration$;
