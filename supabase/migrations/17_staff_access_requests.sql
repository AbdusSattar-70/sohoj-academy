create table public.staff_access_requests(
 id uuid primary key default gen_random_uuid(), full_name text not null,
 email text not null, mobile text not null, requested_role text not null check(requested_role in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT')),
 purpose text not null, status text not null default 'PENDING' check(status in('PENDING','VERIFIED','INVITED','DECLINED','INACTIVE')),
 assigned_role text check(assigned_role in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT')),
 profile_id uuid references public.profiles(id), reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
 invitation_sent_at timestamptz, review_note text, created_at timestamptz not null default now());
create unique index staff_access_open_email on public.staff_access_requests(lower(email)) where status in('PENDING','VERIFIED','INVITED');
alter table public.staff_access_requests enable row level security;
create policy staff_requests_read on public.staff_access_requests for select to authenticated using(public.has_permission('system.users.manage'));
revoke all on public.staff_access_requests from anon,authenticated;
grant select on public.staff_access_requests to authenticated;

create or replace function public.request_staff_access(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare email_value text:=lower(btrim(coalesce(p_input->>'email',''))); count_recent integer;
begin
 if octet_length(p_input::text)>3000 or length(btrim(coalesce(p_input->>'full_name',''))) not between 2 and 160
 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(email_value)>254
 or coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$'
 or p_input->>'requested_role' not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT')
 or length(btrim(coalesce(p_input->>'purpose',''))) not between 5 and 500 then raise exception 'Enter valid contact details, role and purpose.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(email_value,5));
 if (select count(*) from public.staff_access_requests where email=email_value and created_at>now()-interval '1 hour')>=3 then
  return jsonb_build_object('received',true);
 end if;
 insert into public.staff_access_requests(full_name,email,mobile,requested_role,purpose)
 values(btrim(p_input->>'full_name'),email_value,p_input->>'mobile',p_input->>'requested_role',btrim(p_input->>'purpose'))
 on conflict do nothing;
 -- Identical response prevents disclosure of existing staff addresses.
 return jsonb_build_object('received',true);
end $$;
revoke all on function public.request_staff_access(jsonb) from public;
grant execute on function public.request_staff_access(jsonb) to anon,authenticated;

create or replace function public.review_staff_access(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.staff_access_requests; role_value text:=p_input->>'assigned_role'; user_id uuid;
begin
 if auth.uid() is null or not public.has_permission('system.users.manage') then raise exception 'User management permission required.'; end if;
 if not exists(select 1 from public.user_role_assignments a join public.system_roles ro on ro.id=a.role_id
 where a.profile_id=auth.uid() and a.is_active and ro.code='ADMIN' and ro.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date)) then raise exception 'Super admin verification required.'; end if;
 select * into r from public.staff_access_requests where id=(p_input->>'id')::uuid for update;
 if r.id is null then raise exception 'Request not found.'; end if;
 if p_input->>'action'='DECLINE' then
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be declined.'; end if;
  update public.staff_access_requests set status='DECLINED',reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='VERIFY' then
  if role_value not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT') then raise exception 'Choose a role.'; end if;
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be verified.'; end if;
  update public.staff_access_requests set status='VERIFIED',assigned_role=role_value,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='COMPLETE_INVITATION' then
  if r.status not in('VERIFIED','INVITED') then raise exception 'Verify the request before inviting.'; end if;
  -- Identity is resolved from the verified request email, never an arbitrary caller ID.
  select id into user_id from auth.users where lower(email)=r.email;
  if user_id is null then raise exception 'Supabase invitation has not created the user yet.'; end if;
  insert into public.profiles(id,display_name) values(user_id,r.full_name) on conflict(id) do nothing;
  insert into public.staff(profile_id,full_name,email,mobile,created_by)
   values(user_id,r.full_name,r.email,r.mobile,auth.uid()) on conflict(profile_id) do nothing;
  if not exists(select 1 from public.system_roles where code=r.assigned_role and is_active) then raise exception 'Assigned role is unavailable.'; end if;
  insert into public.user_role_assignments(profile_id,role_id,assigned_by)
   select user_id,id,auth.uid() from public.system_roles where code=r.assigned_role and is_active
   on conflict do nothing;
  update public.staff_access_requests set status='INVITED',profile_id=user_id,invitation_sent_at=now() where id=r.id;
 else raise exception 'Unsupported staff verification action.';
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason)
 values(auth.uid(),'STAFF_ACCESS_REQUEST',r.id::text,p_input->>'action',coalesce(p_input->>'reason','Verified staff invitation'));
 return jsonb_build_object('id',r.id);
end $$;
revoke all on function public.review_staff_access(jsonb) from public,anon;
grant execute on function public.review_staff_access(jsonb) to authenticated;
