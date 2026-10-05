-- Generated from supabase/schema/people/10_access_requests_and_identity_entry.sql; edit the source, then run pnpm db:baseline.
-- Staff/referrer identity is created only through a reviewed request, not a generic People form.
create table public.access_requests (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 request_no bigint generated always as identity unique, email text not null unique,
 full_name text not null, mobile text, requested_role text not null references public.access_roles,
 purpose text not null, status text not null default 'NEW' check(status in('NEW','VERIFIED','INVITED','ACTIVE','DECLINED')),
 approved_role text references public.access_roles, person_id uuid references public.people,
 profile_id uuid references public.account_profiles, note text, revision integer not null default 1,
 created_at timestamptz not null default now(), reviewed_at timestamptz
);
alter table public.access_requests enable row level security;
revoke all on public.access_requests from anon,authenticated;
create trigger preserve_record before delete on public.access_requests for each row execute function public.reject_record_delete();
create function public.request_academy_access(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare mail text:=lower(btrim(p_input->>'email')); name_value text:=btrim(p_input->>'full_name'); academy uuid;
begin
 if mail is null or length(mail)>200 or mail !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
 or coalesce(length(name_value),0) not between 2 and 160 or coalesce(length(btrim(p_input->>'purpose')),0) not between 5 and 500
 or coalesce(p_input->>'requested_role','') not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT','REFERRER')
 or (coalesce(p_input->>'mobile','')<>'' and p_input->>'mobile' !~ '^01[3-9][0-9]{8}$') then raise exception 'Check your name, email, role and purpose.'; end if;
 select id into academy from public.academies;
 perform pg_advisory_xact_lock(hashtextextended(mail,0));
 -- Repeated requests cannot rewrite another applicant or disclose account existence.
 if not exists(select 1 from public.access_requests where email=mail) then
  if (select count(*) from public.access_requests where created_at>now()-interval '1 hour')>=100 then raise exception 'Please try again later.'; end if;
  insert into public.access_requests(academy_id,email,full_name,mobile,requested_role,purpose)
  values(academy,mail,name_value,nullif(btrim(p_input->>'mobile'),''),p_input->>'requested_role',btrim(p_input->>'purpose'));
 end if;
 return jsonb_build_object('received',true);
end $$;
create function public.list_access_requests(p_page integer default 1,p_history boolean default false) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('access.manage'); result jsonb;
begin
 if p_page is null or p_page not between 1 and 100000 then raise exception 'Invalid page.'; end if;
 -- Only a verified signed-in Auth identity can complete its own invitation.
 update public.access_requests r set status='ACTIVE',revision=r.revision+1
 from auth.users u where r.academy_id=academy and r.status='INVITED' and r.profile_id=u.id and u.email_confirmed_at is not null and u.last_sign_in_at is not null;
 with matched as(select * from public.access_requests where academy_id=academy and (p_history or status in('NEW','VERIFIED','INVITED'))),
 paged as(select * from matched order by created_at desc,id limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged)) from paged),'[]')) into result;
 return result;
end $$;
create function public.review_access_request(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('access.manage'); row public.access_requests; identity uuid:=nullif(p_input->>'person_id','')::uuid; saved jsonb; role_value text:=p_input->>'role'; req uuid:=(p_input->>'request_id')::uuid; prior jsonb;
begin
 prior:=public.lookup_operation(req,'REVIEW_ACCESS',p_input);if prior is not null then return prior;end if;
 select * into row from public.access_requests where id=(p_input->>'id')::uuid and academy_id=academy for update;
 if not found or row.revision is distinct from (p_input->>'revision')::integer or row.status not in('NEW','VERIFIED') then raise exception 'Request changed. Reload the list.'; end if;
 if coalesce(length(btrim(p_input->>'reason')),0) not between 5 and 1000 then raise exception 'Record the verification reason.'; end if;
 if p_input->>'decision'='DECLINE' then
  update public.access_requests set status='DECLINED',note=p_input->>'reason',reviewed_at=now(),revision=revision+1 where id=row.id;
 else
  if role_value is null or role_value not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT','REFERRER') then raise exception 'Choose a permitted role.'; end if;
  if row.person_id is not null and identity is distinct from row.person_id then raise exception 'This request already has an identity. Keep it for retry.'; end if;
  if identity is not null then
   perform 1 from public.people where id=identity and academy_id=academy and is_active for update;
   if not found then raise exception 'Choose an active existing identity.'; end if;
   if exists(select 1 from public.person_accounts where person_id=identity) then raise exception 'This person already has an account. Manage its existing access.'; end if;
  else
   if p_input->>'new_identity_confirmed' is distinct from 'true' then raise exception 'Check existing identities before creating a new person.'; end if;
   saved:=public.save_person(jsonb_build_object('request_id',gen_random_uuid(),'full_name',row.full_name,'mobile',coalesce(row.mobile,''),'email',row.email,'reason',p_input->>'reason'));
   identity:=(saved->>'id')::uuid;
  end if;
  update public.access_requests set status='VERIFIED',approved_role=role_value,person_id=identity,note=p_input->>'reason',reviewed_at=now(),revision=revision+1 where id=row.id;
 end if;
 select to_jsonb(r) into saved from public.access_requests r where id=row.id;
 return public.finish_operation(req,'REVIEW_ACCESS',p_input,saved,'ACCESS_REQUEST',row.id,null);
end $$;
create function public.complete_access_setup(p_request_id uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('access.manage'); row public.access_requests; account uuid; other public.person_accounts; role_value text;
begin
 select * into row from public.access_requests where id=p_request_id and academy_id=academy for update;
 if not found or row.status not in('VERIFIED','INVITED','ACTIVE') or row.person_id is null then raise exception 'Verify the request first.'; end if;
 select id into account from auth.users where lower(email)=row.email;
 if account is null then raise exception 'Account setup is not ready. Retry sending instructions.'; end if;
 if not exists(select 1 from public.people where id=row.person_id and academy_id=academy and is_active) then raise exception 'Reactivate the linked person before granting access.'; end if;
 if exists(select 1 from public.account_profiles where id=account and not is_active) then raise exception 'This account is inactive. Review its access before reactivation.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(account::text,0));
 select * into other from public.person_accounts where profile_id=account or person_id=row.person_id;
 if found and (other.profile_id<>account or other.person_id<>row.person_id or other.academy_id<>academy) then raise exception 'The account or person is already linked elsewhere.'; end if;
 if exists(select 1 from public.account_profiles where id=account and academy_id<>academy) then raise exception 'Account belongs to another academy.'; end if;
 -- Existing login accounts require explicit linking through this reviewed request; no Auth metadata grants roles.
 insert into public.account_profiles(id,academy_id,display_name) values(account,academy,row.full_name) on conflict(id) do nothing;
 insert into public.person_accounts values(account,row.person_id,academy) on conflict(profile_id) do nothing;
 insert into public.account_roles values(account,row.approved_role) on conflict do nothing;
 role_value:=case when row.approved_role='REFERRER' then 'REFERRER' when row.approved_role='TEACHER' then 'TEACHER' else 'STAFF' end;
 insert into public.person_responsibilities values(row.person_id,academy,role_value,true) on conflict(person_id,responsibility) do update set is_active=true;
 if role_value='TEACHER' then insert into public.person_responsibilities values(row.person_id,academy,'STAFF',true) on conflict(person_id,responsibility) do update set is_active=true; end if;
 if row.status='VERIFIED' then
  update public.access_requests set status='INVITED',profile_id=account,revision=revision+1 where id=row.id;
  perform public.record_activity('GRANT_ACCESS','ACCESS_REQUEST',row.id::text,row.note,null,jsonb_build_object('person_id',row.person_id,'profile_id',account,'role',row.approved_role));
 end if;
 return jsonb_build_object('ready',true);
end $$;
-- Preserve edit RPCs; new identities must originate from their workflow.
create or replace function public.save_person_profile(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage'); req uuid:=(p_input->>'request_id')::uuid; prior jsonb; saved jsonb; identity uuid; responsibility_value text; roles text[];
begin
 if nullif(p_input->>'id','') is null then raise exception 'Create staff/referrers through access requests; students/guardians through admission.'; end if;
 prior:=public.lookup_operation(req,'SAVE_PERSON_PROFILE',p_input);if prior is not null then return prior;end if;
 if jsonb_typeof(p_input->'responsibilities') is distinct from 'array' or jsonb_array_length(p_input->'responsibilities')>5 then raise exception 'Choose valid responsibilities.'; end if;
 select coalesce(array_agg(distinct value),'{}') into roles from jsonb_array_elements_text(p_input->'responsibilities');
 if not roles<@array['STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER'] then raise exception 'Choose valid responsibilities.'; end if;
 if 'TEACHER'=any(roles) and not 'STAFF'=any(roles) then roles:=roles||'STAFF';end if;
 saved:=public.save_person(p_input||jsonb_build_object('request_id',gen_random_uuid()));identity:=(saved->>'id')::uuid;
 if not 'STUDENT'=any(roles) and exists(select 1 from public.batch_seats where person_id=identity and is_active) then raise exception 'Keep Student responsibility while an active placement exists.';end if;
 if not 'GUARDIAN'=any(roles) and exists(select 1 from public.person_relationships where related_person_id=identity and is_active) then raise exception 'Keep Guardian responsibility while a relationship exists.';end if;
 update public.person_responsibilities set is_active=false where person_id=identity;
 foreach responsibility_value in array roles loop insert into public.person_responsibilities values(identity,academy,responsibility_value,true) on conflict(person_id,responsibility) do update set is_active=true;end loop;
 saved:=public.person_profile(identity);return public.finish_operation(req,'SAVE_PERSON_PROFILE',p_input,saved,'PERSON',identity,null);
end $$;
revoke all on function public.save_person(jsonb) from authenticated;
revoke all on function public.request_academy_access(jsonb),public.list_access_requests(integer,boolean),public.review_access_request(jsonb),public.complete_access_setup(uuid) from public,anon,authenticated;
grant execute on function public.request_academy_access(jsonb) to anon,authenticated;
grant execute on function public.list_access_requests(integer,boolean),public.review_access_request(jsonb),public.complete_access_setup(uuid) to authenticated;
create function public.access_setup_request(p_request_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('access.manage'); result jsonb;
begin
 select to_jsonb(r) into result from public.access_requests r where id=p_request_id and academy_id=academy and status in('VERIFIED','INVITED','ACTIVE');
 if result is null then raise exception 'Verify the request first.';end if;return result;
end $$;
revoke all on function public.access_setup_request(uuid) from public,anon;
grant execute on function public.access_setup_request(uuid) to authenticated;
create function public.search_people_by_role(p_query text default '',p_page integer default 1,p_responsibility text default '') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb; needle text:=lower(btrim(p_query));
begin
 if p_page is null or p_page not between 1 and 100000 or needle is null or length(needle)>160 or p_responsibility is null or p_responsibility not in('','STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER') then raise exception 'Invalid person search.';end if;
 with matched as(select id,person_no,full_name,mobile,email,is_active,revision from public.people p where academy_id=academy and
 (needle='' or position(needle in lower(full_name))>0 or position(needle in coalesce(mobile,''))>0 or position(needle in lower(coalesce(email,'')))>0 or person_no::text=needle) and
 (p_responsibility='' or exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility=p_responsibility and r.is_active))),
 paged as(select * from matched order by full_name,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by full_name,id) from paged),'[]')) into result;return result;
end $$;
revoke all on function public.search_people_by_role(text,integer,text) from public,anon;
grant execute on function public.search_people_by_role(text,integer,text) to authenticated;
create or replace function public.academy_account_context() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('profileId',p.id,'academyId',p.academy_id,'name',p.display_name,
 'academyName',a.name,'roles',coalesce((select jsonb_agg(role_code order by role_code) from public.account_roles where profile_id=p.id),'[]'),
 'permissions',coalesce((select jsonb_agg(permission order by permission) from (select distinct unnest(r.permissions) permission from public.account_roles ar join public.access_roles r on r.code=ar.role_code where ar.profile_id=p.id)s),'[]'),
 'divisions',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'nameBn',d.name_bn,'code',d.code) order by d.code) from public.operating_divisions d where d.academy_id=p.academy_id and d.is_active),'[]'))
 from public.account_profiles p join public.academies a on a.id=p.academy_id where p.id=auth.uid() and p.is_active
 and not exists(select 1 from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and not person.is_active)
$$;
-- A linked inactive identity cannot continue using an otherwise active login profile.
create or replace function public.can_operate(permission text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.account_profiles p join public.account_roles a on a.profile_id=p.id join public.access_roles r on r.code=a.role_code
 where p.id=auth.uid() and p.is_active and permission=any(r.permissions)
 and not exists(select 1 from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and not person.is_active))
$$;
create or replace function public.current_academy_id() returns uuid language sql stable security definer set search_path=public,pg_temp as $$
 select p.academy_id from public.account_profiles p where p.id=auth.uid() and p.is_active
 and not exists(select 1 from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and not person.is_active)
$$;
create function public.protect_current_account_identity() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if old.is_active and not new.is_active and exists(select 1 from public.person_accounts where person_id=old.id and profile_id=auth.uid()) then raise exception 'You cannot deactivate your own signed-in identity.';end if;
 return new;
end $$;
create trigger protect_signed_in_identity before update of is_active on public.people for each row execute function public.protect_current_account_identity();
revoke all on function public.protect_current_account_identity() from public,anon,authenticated;
