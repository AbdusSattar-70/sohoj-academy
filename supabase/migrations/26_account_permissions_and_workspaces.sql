-- Generated from supabase/schema/access/26_account_permissions_and_workspaces.sql; edit the source, then run pnpm db:baseline.
-- Admin-configured responsibilities and workspace assignments; no public self-grants.
alter table public.access_roles add column revision int not null default 1;
alter table public.account_profiles add column access_revision int not null default 1;
create table public.account_workspaces(
 profile_id uuid not null references public.account_profiles,
 division_id uuid not null references public.operating_divisions,
 primary key(profile_id,division_id)
);
alter table public.account_workspaces enable row level security;
revoke all on public.account_workspaces from public,anon,authenticated;
-- Preserve current verified accounts during this upgrade. Admin may narrow assignments immediately.
insert into public.account_workspaces select p.id,d.id from public.account_profiles p join public.operating_divisions d on d.academy_id=p.academy_id;
update public.access_roles set permissions=permissions||array['academics.teach','academics.review'] where code='ADMIN';
update public.access_roles set permissions=permissions||array['academics.teach'] where code='TEACHER';
create function public.require_account_admin() returns uuid language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if public.current_academy_id() is null or not exists(select 1 from public.account_roles where profile_id=auth.uid() and role_code='ADMIN') then raise exception 'Only an academy administrator can configure account access.' using errcode='42501';end if;
 return public.current_academy_id();
end $$;
create function public.can_use_workspace(p_division uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.operating_divisions d where d.id=p_division and d.academy_id=public.current_academy_id() and d.is_active and (exists(select 1 from public.account_roles where profile_id=auth.uid() and role_code='ADMIN') or exists(select 1 from public.account_workspaces where profile_id=auth.uid() and division_id=d.id)))
$$;
create function public.account_access_settings(p_query text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_account_admin();result jsonb;
begin
 if p_page is null or p_page not between 1 and 10000 or p_query is null or length(p_query)>160 then raise exception 'Choose a valid search and page.';end if;
 with matched as(select p.id,p.display_name,p.is_active,p.access_revision revision,u.email,
 case when person.staff_no is not null then 'SA-STF-'||lpad(person.staff_no::text,greatest(5,length(person.staff_no::text)),'0') end staff_id,
 array(select role_code from public.account_roles where profile_id=p.id order by role_code) roles,
 array(select division_id from public.account_workspaces where profile_id=p.id order by division_id) workspaces
 from public.account_profiles p join auth.users u on u.id=p.id left join public.person_accounts pa on pa.profile_id=p.id left join public.people person on person.id=pa.person_id where p.academy_id=aid and (p_query='' or position(lower(btrim(p_query)) in lower(p.display_name||' '||coalesce(u.email,'')||' '||coalesce(person.staff_no::text,'')))>0)),
 paged as(select * from matched order by display_name,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(paged) order by display_name,id) from paged),'[]'),'total',(select count(*) from matched),'page',p_page,'pageSize',25) into result;
 return result||jsonb_build_object('roles',(select jsonb_agg(to_jsonb(r) order by code) from public.access_roles r),'divisions',(select jsonb_agg(jsonb_build_object('id',id,'name',name,'nameBn',name_bn,'code',code) order by code) from public.operating_divisions where academy_id=aid and is_active));
end $$;
create function public.save_account_access(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_account_admin();cmd text:=p_input->>'action';prior jsonb;old jsonb;result jsonb;target uuid;role_value text;perms text[];roles text[];workspaces uuid[];current_revision int;
 allowed text[]:=array['people.view','people.manage','directory.view','directory.manage','activity.view','academics.view','academics.manage','academics.teach','academics.review','fees.manage'];
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
-- Assignment rows are mutable configuration; their before/after changes are preserved in activity_events.
drop trigger preserve_record on public.account_roles;
-- Context is the permitted switcher list, never an unfiltered client directory.
create or replace function public.academy_account_context() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('profileId',p.id,'academyId',p.academy_id,'name',p.display_name,'academyName',a.name,
 'staffId',(select 'SA-STF-'||lpad(person.staff_no::text,greatest(5,length(person.staff_no::text)),'0') from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and person.staff_no is not null),
 'roles',coalesce((select jsonb_agg(role_code order by role_code) from public.account_roles where profile_id=p.id),'[]'),
 'permissions',coalesce((select jsonb_agg(permission order by permission) from(select distinct unnest(r.permissions) permission from public.account_roles ar join public.access_roles r on r.code=ar.role_code where ar.profile_id=p.id)s),'[]'),
 'divisions',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'nameBn',d.name_bn,'code',d.code) order by d.code) from public.operating_divisions d where public.can_use_workspace(d.id)),'[]'))
 from public.account_profiles p join public.academies a on a.id=p.academy_id where p.id=auth.uid() and p.is_active and public.current_academy_id() is not null
$$;
revoke all on function public.require_account_admin(),public.can_use_workspace(uuid),public.account_access_settings(text,integer),public.save_account_access(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.account_access_settings(text,integer),public.save_account_access(uuid,jsonb) to authenticated;
