alter table public.organizations add column setup_identity_confirmed_at timestamptz;
create or replace function public.save_academy_identity(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare org public.organizations; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Academy setup permission required.'; end if;
 if length(btrim(coalesce(p_input->>'name',''))) not between 2 and 160 then raise exception 'Enter an academy name.'; end if;
 if length(btrim(coalesce(p_input->>'branch_name',''))) not between 2 and 160 then raise exception 'Enter the campus name.'; end if;
 select * into org from public.organizations where code='SOHOJ' for update;
 before_data:=to_jsonb(org);
 update public.organizations set name=btrim(p_input->>'name'),setup_identity_confirmed_at=now() where id=org.id;
 update public.branches set name=btrim(p_input->>'branch_name') where organization_id=org.id and code='MAIN';
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ACADEMY',org.id::text,'CONFIRM_IDENTITY','Confirmed academy name and campus',before_data,p_input);
 return jsonb_build_object('id',org.id);
end $$;
revoke all on function public.save_academy_identity(jsonb) from public,anon;
grant execute on function public.save_academy_identity(jsonb) to authenticated;

do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.academy_setup_status()'::regprocedure) into definition;
 definition:=replace(definition,'o.id is not null and exists','o.id is not null and o.setup_identity_confirmed_at is not null and exists');
 execute definition;
 select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
 definition:=replace(definition,$old$ if p_input->>'action' not in('SAVE_DISCOUNT','FINALIZE','RETURN_TO_DRAFT') then$old$,
 $new$ if p_input->>'action' in('CREATE','READY','ACCEPT','BILL','FINALIZE') and not exists(select 1 from public.organizations where code='SOHOJ' and is_active and setup_completed_at is not null) then raise exception 'Complete academy setup before processing admissions.'; end if;
 if p_input->>'action' in('ACCEPT','BILL') and not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
 if p_input->>'action'='ACCEPT' and not (public.admission_review_checks((p_input->>'admission_id')::uuid)->>'hasConsent')::boolean then raise exception 'Receive signed consent for the current details.'; end if;
 if p_input->>'action' not in('SAVE_DISCOUNT','FINALIZE','RETURN_TO_DRAFT') then$new$);
 definition:=replace(definition,$old$if pct<>0 and p_input->>'discount_reason' not in$old$, $new$if pct<>0 and coalesce(p_input->>'discount_reason','') not in$new$);
 execute definition;
end $migration$;

create or replace function public.admission_directory_options()
returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Sign in required.'; end if;
 if not public.has_permission('admissions.view') then return jsonb_build_object('schools','[]'::jsonb,'relationships','[]'::jsonb); end if;
 return jsonb_build_object('schools',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.schools where is_active),'[]'::jsonb),
 'relationships',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.guardian_relationships where is_active),'[]'::jsonb));
end $$;
revoke all on function public.admission_directory_options() from public,anon;
grant execute on function public.admission_directory_options() to authenticated;
create or replace function public.create_admission_directory_choice(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare org uuid; result jsonb; name_value text:=btrim(coalesce(p_input->>'name',''));
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if length(name_value) not between 2 and 160 then raise exception 'Enter a name of 2 to 160 characters.'; end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(lower(name_value),6));
 if p_input->>'entity'='school' then
  select jsonb_build_object('id',id,'name',name) into result from public.schools where organization_id=org and lower(name)=lower(name_value) and is_active limit 1;
  if result is null then insert into public.schools(organization_id,name,is_verified,is_active) values(org,name_value,true,true) returning jsonb_build_object('id',id,'name',name) into result; end if;
 elsif p_input->>'entity'='relationship' then
  select jsonb_build_object('id',id,'name',name) into result from public.guardian_relationships where organization_id=org and lower(name)=lower(name_value) and is_active limit 1;
  if result is null then insert into public.guardian_relationships(organization_id,code,name,is_active) values(org,'REL_'||replace(gen_random_uuid()::text,'-',''),name_value,true) returning jsonb_build_object('id',id,'name',name) into result; end if;
 else raise exception 'Only school and guardian relationship can be created during admission.';
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values(auth.uid(),upper(p_input->>'entity'),result->>'id','SELECT_OR_CREATE_FOR_ADMISSION','Verified missing directory option during admission',result);
 return result;
end $$;
revoke all on function public.create_admission_directory_choice(jsonb) from public,anon;
grant execute on function public.create_admission_directory_choice(jsonb) to authenticated;

-- Staff identity and role remain aligned after a verified invitation.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.review_staff_access(jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'update public.staff_access_requests set status=''INVITED''',
 $assignment$insert into public.staff_role_assignments(staff_id,staff_role_id,is_primary,assigned_by)
   select s.id,role.id,true,auth.uid() from public.staff s join public.staff_roles role on role.code=r.assigned_role and role.is_active
   where s.profile_id=user_id and not exists(select 1 from public.staff_role_assignments old where old.staff_id=s.id and old.is_primary and old.effective_to is null);
  update public.staff_access_requests set status='INVITED'$assignment$);
 execute definition;
 -- Inactive offerings may have their descriptive identity corrected, but academic
 -- context stays frozen once used, exactly as for active offerings.
 select pg_get_functiondef('public.update_programme_offering(jsonb)'::regprocedure) into definition;
 definition:=replace(definition,$old$if v_row.status='RETIRED' then raise exception 'Retired offerings are read-only.'; end if;$old$,'');
 definition:=replace(definition,$old$if v_row.status='ACTIVE' and ($old$,$new$if v_row.status in('ACTIVE','RETIRED') and ($new$);
 execute definition;
end $migration$;
-- All application writes use permission-checked, audited RPCs. RLS still protects reads.
revoke insert,update,delete on public.students,public.guardians,public.student_guardians,
 public.staff,public.profiles,public.batches,public.enrollments from authenticated,anon;
