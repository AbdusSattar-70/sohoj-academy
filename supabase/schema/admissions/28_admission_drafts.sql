-- Staff-assisted intake is an admission application, never a fabricated CRM enquiry.
update public.access_roles set permissions=permissions||array['admissions.view','admissions.manage','billing.view','billing.manage'] where code='ADMIN';
update public.access_roles set permissions=permissions||array['admissions.view','admissions.manage','billing.view','billing.manage'] where code='OPERATOR';
update public.access_roles set permissions=permissions||array['billing.view','billing.manage'] where code='ACCOUNTANT';
create table public.student_admissions(
 id uuid primary key default gen_random_uuid(),admission_no bigint generated always as identity unique,
 academy_id uuid not null references public.academies,division_id uuid not null references public.operating_divisions,
 run_id uuid references public.programme_runs,batch_id uuid references public.teaching_batches,
 enquiry_id uuid references public.enquiries,details jsonb not null default '{}' check(jsonb_typeof(details)='object' and octet_length(details::text)<=32000),
 fee_snapshot jsonb,discount_percent int not null default 0 check(discount_percent in(0,5,10,15,20,25,30)),discount_reason text,
 status text not null default 'DRAFT' check(status in('DRAFT','ADMITTED','CANCELLED')),
 student_id uuid references public.people,guardian_id uuid references public.people,referrer_id uuid references public.people,
 enrollment_id uuid references public.academic_batch_enrollments,roll_no int,admitted_at timestamptz,
 created_by uuid not null references public.account_profiles,created_at timestamptz not null default now(),revision int not null default 1
);
create unique index one_enquiry_admission on public.student_admissions(enquiry_id) where enquiry_id is not null and status<>'CANCELLED';
create unique index admission_batch_roll on public.student_admissions(batch_id,roll_no) where roll_no is not null;
create index admissions_workspace on public.student_admissions(division_id,status,created_at desc,id);
alter table public.student_admissions enable row level security;
revoke all on public.student_admissions from public,anon,authenticated;
create trigger preserve_admission before delete on public.student_admissions for each row execute function public.reject_record_delete();
create function public.admission_fee_snapshot(p_run uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('revision',f.revision,'cycle',f.cycle,'dueDay',f.due_day,'allowedDiscounts',f.allowed_discounts,'components',coalesce((select jsonb_agg(jsonb_build_object('code',c.code,'name',c.name,'amount',c.amount,'type',c.charge_type,'recurrence',c.recurrence) order by c.code) from public.run_fee_components c where c.run_id=f.run_id and c.is_active),'[]')) from public.run_fee_settings f where f.run_id=p_run and f.academy_id=public.current_academy_id()
$$;
create function public.admission_options(p_query text default '',p_page integer default 1,p_run uuid default null) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.view');workspace uuid:=public.current_workspace_id();
begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid search and page.';end if;
 return jsonb_build_object('runs',coalesce((select jsonb_agg(to_jsonb(x)) from(select r.id,r.title,r.code,r.class_code,r.guardian_rule,r.starts_on,r.ends_on,r.default_weekdays,public.admission_fee_snapshot(r.id) fees from public.workspace_runs r where r.is_active and(r.id=p_run or p_query='' or r.title ilike '%'||p_query||'%' or r.code ilike '%'||p_query||'%') order by (r.id=p_run) desc nulls last,r.title,r.id limit 25 offset(p_page-1)*25)x),'[]'),
 'batches',case when p_run is not null then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'capacity',b.capacity,'occupied',(select count(*) from public.batch_seats where batch_id=b.id and is_active),'slots',b.planned_slots) order by b.name,b.id) from public.workspace_batches b where b.run_id=p_run and b.is_active),'[]') else '[]'::jsonb end,
 'referrers',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'mobile',p.mobile) order by p.full_name) from public.people p where p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility='REFERRER' and r.is_active)),'[]'));
end $$;
create function public.admission_person_search(p_query text,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.manage');
begin
 if p_query is null or length(btrim(p_query)) not between 2 and 160 or p_page is null or p_page not between 1 and 10000 then raise exception 'Enter at least two characters.';end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from(select p.id,p.full_name,p.full_name_bn,p.mobile,p.email,p.date_of_birth,p.present_address,p.permanent_address,p.student_no from public.people p where p.academy_id=aid and p.is_active and(lower(p.full_name) like '%'||lower(btrim(p_query))||'%' or p.mobile like '%'||btrim(p_query)||'%' or lower(coalesce(p.email,'')) like '%'||lower(btrim(p_query))||'%') order by p.full_name,p.id limit 25 offset(p_page-1)*25)x),'[]');
end $$;
alter table public.people add column student_no bigint unique;
create sequence public.student_identity_number;
create function public.assign_student_identity() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.responsibility='STUDENT' then update public.people set student_no=nextval('public.student_identity_number') where id=new.person_id and student_no is null;end if;return new;
end $$;
create trigger assign_student_identity after insert or update on public.person_responsibilities for each row execute function public.assign_student_identity();
update public.people p set student_no=nextval('public.student_identity_number') where student_no is null and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility='STUDENT');
create function public.protect_student_identity() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin if old.student_no is not null and new.student_no is distinct from old.student_no then raise exception 'Student identity cannot change.';end if;return new;end $$;
create trigger protect_student_identity before update of student_no on public.people for each row execute function public.protect_student_identity();
create function public.save_admission_draft(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.manage');workspace uuid:=public.current_workspace_id();original public.student_admissions;saved public.student_admissions;prior jsonb;run uuid:=nullif(p_input->>'runId','')::uuid;batch uuid:=nullif(p_input->>'batchId','')::uuid;enquiry uuid:=nullif(p_input->>'enquiryId','')::uuid;rid uuid:=nullif(p_input->>'id','')::uuid;source_division uuid;
begin
 if workspace is null then raise exception 'Select a workspace.';end if;
 perform public.check_change_reason(p_input->>'reason');
 if jsonb_typeof(p_input->'details') is distinct from 'object' or octet_length((p_input->'details')::text)>32000 then raise exception 'Check the application details.';end if;
 if rid is not null then select * into original from public.student_admissions where id=rid and academy_id=aid and division_id=workspace for update;if not found then raise exception 'Admission not found in this workspace.';end if;end if;
 if run is not null then perform public.require_workspace_run(run);end if;
 prior:=public.lookup_operation(p_request_id,'SAVE_ADMISSION',p_input);if prior is not null then return prior;end if;
 if original.id is not null and(original.status<>'DRAFT' or original.revision is distinct from(p_input->>'revision')::int) then raise exception 'Admission changed or is already confirmed. Refresh before editing.';end if;
 if batch is not null and not exists(select 1 from public.workspace_batches where id=batch and run_id=run and is_active) then raise exception 'Choose an active batch in the selected programme.';end if;
 if enquiry is not null then
  if not exists(select 1 from public.enquiries where id=enquiry and academy_id=aid) then raise exception 'Application not found.';end if;
  select r.division_id into source_division from public.enquiries e left join public.programme_runs r on r.id::text=e.payload->>'offeringId' where e.id=enquiry;
  if source_division is distinct from workspace and not exists(select 1 from public.account_roles where profile_id=auth.uid() and role_code='ADMIN') then raise exception 'This application needs administrator routing.';end if;
  if original.id is not null and original.enquiry_id is distinct from enquiry then raise exception 'Keep the original application source.';end if;
 end if;
 insert into public.student_admissions(id,academy_id,division_id,run_id,batch_id,enquiry_id,details,fee_snapshot,discount_percent,discount_reason,created_by)
 values(coalesce(rid,gen_random_uuid()),aid,workspace,run,batch,coalesce(original.enquiry_id,enquiry),p_input->'details',public.admission_fee_snapshot(run),coalesce((p_input->>'discountPercent')::int,0),nullif(btrim(p_input->>'discountReason'),''),auth.uid())
 on conflict(id) do update set run_id=excluded.run_id,batch_id=excluded.batch_id,details=excluded.details,fee_snapshot=excluded.fee_snapshot,discount_percent=excluded.discount_percent,discount_reason=excluded.discount_reason,revision=student_admissions.revision+1 returning * into saved;
 return public.finish_operation(p_request_id,'SAVE_ADMISSION',p_input,jsonb_build_object('id',saved.id),'ADMISSION',saved.id,to_jsonb(original));
end $$;
create function public.admission_case(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.view');item public.student_admissions;
begin
 select * into item from public.student_admissions where id=p_id and academy_id=aid and division_id=public.current_workspace_id();if not found then raise exception 'Admission not found in this workspace.';end if;
 return to_jsonb(item)||jsonb_build_object('runTitle',(select title from public.programme_runs where id=item.run_id),'batchName',(select name from public.teaching_batches where id=item.batch_id),'studentNumber',(select 'SA-'||lpad(student_no::text,greatest(6,length(student_no::text)),'0') from public.people where id=item.student_id),'enquiry',case when item.enquiry_id is not null then(select payload from public.enquiries where id=item.enquiry_id) else null end);
end $$;
create function public.admission_register(p_query text default '',p_page integer default 1,p_status text default 'DRAFT') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.view');workspace uuid:=public.current_workspace_id();result jsonb;
begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 10000 or p_status not in('DRAFT','ADMITTED','CANCELLED','') then raise exception 'Choose a valid search, status and page.';end if;
 with matched as(select a.id,a.admission_no,a.created_at,a.status,a.details->>'studentName' name,r.title programme,b.name batch,a.roll_no,
 case when p.student_no is not null then 'SA-'||lpad(p.student_no::text,greatest(6,length(p.student_no::text)),'0') end student_number
 from public.student_admissions a left join public.programme_runs r on r.id=a.run_id left join public.teaching_batches b on b.id=a.batch_id left join public.people p on p.id=a.student_id where a.academy_id=aid and a.division_id=workspace and(p_status='' or a.status=p_status) and(p_query='' or a.details->>'studentName' ilike '%'||p_query||'%' or a.details->>'guardianMobile' like '%'||p_query||'%' or a.admission_no::text=p_query)),paged as(select * from matched order by created_at desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(paged) order by created_at desc,id) from paged),'[]'),'total',(select count(*) from matched),'page',p_page) into result;return result;
end $$;
create function public.admission_enquiry(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('admissions.manage');item public.enquiries;source_division uuid;
begin
 select * into item from public.enquiries where id=p_id and academy_id=aid;if not found then raise exception 'Application not found.';end if;
 select division_id into source_division from public.programme_runs where id::text=item.payload->>'offeringId';
 if source_division is distinct from public.current_workspace_id() and not exists(select 1 from public.account_roles where profile_id=auth.uid() and role_code='ADMIN') then raise exception 'This application needs administrator routing.';end if;
 return jsonb_build_object('payload',item.payload,'admissionId',(select id from public.student_admissions where enquiry_id=item.id and status<>'CANCELLED'));
end $$;
revoke all on function public.admission_fee_snapshot(uuid),public.assign_student_identity(),public.protect_student_identity() from public,anon,authenticated;
revoke all on sequence public.student_identity_number from public,anon,authenticated;
revoke all on function public.admission_options(text,integer,uuid),public.admission_person_search(text,integer),public.save_admission_draft(uuid,jsonb),public.admission_case(uuid),public.admission_register(text,integer,text),public.admission_enquiry(uuid) from public,anon;
grant execute on function public.admission_options(text,integer,uuid),public.admission_person_search(text,integer),public.save_admission_draft(uuid,jsonb),public.admission_case(uuid),public.admission_register(text,integer,text),public.admission_enquiry(uuid) to authenticated;

create or replace function public.save_account_access(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_account_admin();cmd text:=p_input->>'action';prior jsonb;old jsonb;result jsonb;target uuid;role_value text;perms text[];roles text[];workspaces uuid[];current_revision int;
 allowed text[]:=array['people.view','people.manage','directory.view','directory.manage','activity.view','academics.view','academics.manage','academics.teach','academics.review','fees.manage','admissions.view','admissions.manage','billing.view','billing.manage'];
begin
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'account-access',0));
 perform public.check_change_reason(p_input->>'reason');
 prior:=public.lookup_operation(p_request_id,'ACCOUNT_ACCESS',p_input);if prior is not null then return prior;end if;
 if cmd='ROLE' then
  role_value:=p_input->>'role';
  if role_value not in('OPERATOR','TEACHER','ACCOUNTANT','REFERRER') then raise exception 'Administrator recovery access is protected.';end if;
  if jsonb_typeof(p_input->'permissions') is distinct from 'array' then raise exception 'Select permitted responsibilities.';end if;
  perms:=array(select distinct value from jsonb_array_elements_text(p_input->'permissions'));
  if not perms<@allowed then raise exception 'Unknown or protected permission.';end if;
  if (perms&&array['academics.manage','academics.teach','academics.review','fees.manage']) and not 'academics.view'=any(perms) then raise exception 'Enable academic viewing before its actions.';end if;
  if 'academics.review'=any(perms) and not 'academics.manage'=any(perms) then raise exception 'Report review currently requires class management access.';end if;
  if 'admissions.manage'=any(perms) and not 'admissions.view'=any(perms) then raise exception 'Enable admission viewing before editing.';end if;
  if 'billing.manage'=any(perms) and not 'billing.view'=any(perms) then raise exception 'Enable billing viewing before collection.';end if;
  if 'people.manage'=any(perms) and not 'people.view'=any(perms) then raise exception 'Enable people viewing before editing.';end if;
  if 'directory.manage'=any(perms) and not 'directory.view'=any(perms) then raise exception 'Enable directory viewing before editing.';end if;
  select to_jsonb(r),r.revision into old,current_revision from public.access_roles r where code=role_value for update;
  if current_revision is distinct from (p_input->>'revision')::int then raise exception 'Role changed. Refresh before editing.';end if;
  update public.access_roles set permissions=perms,revision=revision+1 where code=role_value returning to_jsonb(access_roles) into result;
  perform public.record_activity('UPDATE_ROLE_ACCESS','ACCESS_ROLE',role_value,p_input->>'reason',old,result,p_request_id);
 elsif cmd='ACCOUNT' then
  target:=(p_input->>'id')::uuid;
  select to_jsonb(p),p.access_revision into old,current_revision from public.account_profiles p where id=target and academy_id=aid for update;
  if old is null or current_revision is distinct from (p_input->>'revision')::int then raise exception 'Account changed. Refresh before editing.';end if;
  if exists(select 1 from public.account_roles where profile_id=target and role_code='ADMIN') then raise exception 'Administrator recovery access is protected.';end if;
  if jsonb_typeof(p_input->'roles') is distinct from 'array' or jsonb_typeof(p_input->'workspaces') is distinct from 'array' or jsonb_typeof(p_input->'active') is distinct from 'boolean' then raise exception 'Select roles, workspaces and account status.';end if;
  roles:=array(select distinct value from jsonb_array_elements_text(p_input->'roles'));
  workspaces:=array(select distinct value::uuid from jsonb_array_elements_text(p_input->'workspaces'));
  if not roles<@array['OPERATOR','TEACHER','ACCOUNTANT','REFERRER'] or cardinality(roles)=0 then raise exception 'Choose one or more operational roles.';end if;
  if exists(select 1 from unnest(workspaces) w where not exists(select 1 from public.operating_divisions where id=w and academy_id=aid and is_active)) then raise exception 'Select academy workspaces.';end if;
  if (p_input->>'active')::boolean and cardinality(workspaces)=0 then raise exception 'An active account needs at least one workspace.';end if;
  old:=old||jsonb_build_object('roles',array(select role_code from public.account_roles where profile_id=target),'workspaces',array(select division_id from public.account_workspaces where profile_id=target));
  delete from public.account_roles where profile_id=target;
  insert into public.account_roles select target,unnest(roles);
  delete from public.account_workspaces where profile_id=target;
  insert into public.account_workspaces select target,unnest(workspaces);
  update public.account_profiles set is_active=(p_input->>'active')::boolean,access_revision=access_revision+1 where id=target returning to_jsonb(account_profiles) into result;
  result:=result||jsonb_build_object('roles',roles,'workspaces',workspaces);
  perform public.record_activity('UPDATE_ACCOUNT_ACCESS','ACCOUNT',target::text,p_input->>'reason',old,result,p_request_id);
 else raise exception 'Choose a role or account change.';end if;
 insert into public.operation_requests(actor_id,request_id,command,payload,result) values(auth.uid(),p_request_id,'ACCOUNT_ACCESS',p_input,result);
 return result;
end $$;
notify pgrst,'reload schema';
