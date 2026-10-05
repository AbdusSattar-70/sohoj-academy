-- Generated from supabase/schema/platform/01_academy_divisions_and_access.sql; edit the source, then run pnpm db:baseline.
-- Fresh first-version foundation. Applied to an EMPTY application schema only.
create table public.academies (
 id uuid primary key default gen_random_uuid(), singleton boolean not null default true unique check(singleton),
 name text not null check(length(btrim(name)) between 2 and 160), timezone text not null default 'Asia/Dhaka',
 currency text not null default 'BDT' check(currency='BDT'), setup_completed_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.operating_divisions (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 code text not null check(code in('SCHOOL','COACHING','TRAINING')), name text not null,
 name_bn text not null, is_active boolean not null default true, unique(academy_id,code)
);
create table public.campuses (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 code text not null, name text not null, is_active boolean not null default true, unique(academy_id,code)
);
create table public.account_profiles (
 id uuid primary key references auth.users(id), academy_id uuid not null references public.academies,
 display_name text not null check(length(btrim(display_name)) between 2 and 160),
 is_active boolean not null default true, created_at timestamptz not null default now(), unique(id,academy_id)
);
create table public.access_roles (
 code text primary key check(code in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT','REFERRER')),
 permissions text[] not null default '{}'
);
create table public.account_roles (
 profile_id uuid not null references public.account_profiles, role_code text not null references public.access_roles,
 primary key(profile_id,role_code)
);
create table public.activity_events (
 id bigint generated always as identity primary key, occurred_at timestamptz not null default clock_timestamp(),
 actor_profile_id uuid references public.account_profiles, actor_name text, actor_roles text[],
 action text not null, entity_type text not null, entity_id text not null, reason text,
 before_data jsonb, after_data jsonb, request_id uuid
);
create index activity_events_time_idx on public.activity_events(occurred_at desc,id desc);
create index activity_events_entity_idx on public.activity_events(entity_type,entity_id,id desc);
create table public.operation_requests (
 actor_id uuid not null references public.account_profiles, request_id uuid not null,
 command text not null, payload jsonb not null, result jsonb not null,
 created_at timestamptz not null default now(), primary key(actor_id,request_id)
);

create function public.current_academy_id() returns uuid language sql stable security definer
set search_path=public,pg_temp as $$
 select academy_id from public.account_profiles where id=auth.uid() and is_active
$$;
create function public.can_operate(permission text) returns boolean language sql stable security definer
set search_path=public,pg_temp as $$
 select exists(select 1 from public.account_profiles p join public.account_roles a on a.profile_id=p.id
 join public.access_roles r on r.code=a.role_code
 where p.id=auth.uid() and p.is_active and permission=any(r.permissions))
$$;
create function public.require_operation(permission text) returns uuid language plpgsql stable security definer
set search_path=public,pg_temp as $$
begin
 if not public.can_operate(permission) then raise exception 'You do not have permission for this action.' using errcode='42501'; end if;
 return public.current_academy_id();
end $$;
create function public.record_activity(action_value text,entity_value text,id_value text,reason_value text,
 before_value jsonb,after_value jsonb,request_value uuid default null) returns void
language sql security definer set search_path=public,pg_temp as $$
 insert into public.activity_events(actor_profile_id,actor_name,actor_roles,action,entity_type,entity_id,reason,before_data,after_data,request_id)
 select p.id,p.display_name,array(select role_code from public.account_roles where profile_id=p.id order by role_code),
 action_value,entity_value,id_value,reason_value,before_value,after_value,request_value
 from public.account_profiles p where p.id=auth.uid() and p.is_active
$$;
create function public.reject_record_delete() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin raise exception 'Keep history: mark this record inactive instead of deleting it.'; end $$;
create function public.reject_evidence_change() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin raise exception 'Recorded evidence cannot be changed or deleted.'; end $$;
create trigger activity_immutable before update or delete on public.activity_events for each row execute function public.reject_evidence_change();
create trigger request_immutable before update or delete on public.operation_requests for each row execute function public.reject_evidence_change();

-- Installation/bootstrap is server/SQL-editor only; never an anonymous signup path.
create function public.initialize_academy(admin_email text,admin_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare user_id uuid; academy uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('sohoj-initial-admin',0));
 if exists(select 1 from public.account_roles where role_code='ADMIN') then
  raise exception 'An administrator already exists. Use the verified access workflow.';
 end if;
 if length(btrim(admin_name)) not between 2 and 160 then raise exception 'Enter the administrator name.'; end if;
 select id into user_id from auth.users where lower(email)=lower(btrim(admin_email)) and email_confirmed_at is not null;
 if user_id is null then raise exception 'Create and verify your own Auth account before bootstrap.'; end if;
 select id into academy from public.academies;
 if academy is null then raise exception 'Apply the essential foundation seed first.'; end if;
 insert into public.account_profiles(id,academy_id,display_name) values(user_id,academy,btrim(admin_name));
 insert into public.account_roles values(user_id,'ADMIN');
 insert into public.activity_events(actor_profile_id,actor_name,actor_roles,action,entity_type,entity_id,reason)
 values(user_id,btrim(admin_name),array['ADMIN'],'BOOTSTRAP','ACCOUNT',user_id::text,'Initial verified academy administrator');
 return user_id;
end $$;

-- No table is ever initially open to client mutations.
do $$ declare relation text; begin
 foreach relation in array array['academies','operating_divisions','campuses','account_profiles','access_roles','account_roles','activity_events','operation_requests'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
  execute format('create trigger preserve_record before delete on public.%I for each row execute function public.reject_record_delete()',relation);
 end loop;
end $$;
create policy academy_read on public.academies for select to authenticated using(id=public.current_academy_id());
create policy division_read on public.operating_divisions for select to authenticated using(academy_id=public.current_academy_id());
create policy campus_read on public.campuses for select to authenticated using(academy_id=public.current_academy_id());
create policy profile_read on public.account_profiles for select to authenticated using(id=auth.uid() or public.can_operate('access.manage'));
create policy role_read on public.account_roles for select to authenticated using(profile_id=auth.uid() or public.can_operate('access.manage'));
create policy role_directory_read on public.access_roles for select to authenticated using(public.current_academy_id() is not null);
create policy activity_read on public.activity_events for select to authenticated using(public.can_operate('activity.view'));
grant select on public.academies,public.operating_divisions,public.campuses,public.account_profiles,public.account_roles,public.access_roles,public.activity_events to authenticated;
revoke all on function public.current_academy_id(),public.can_operate(text),public.require_operation(text),public.record_activity(text,text,text,text,jsonb,jsonb,uuid),public.reject_record_delete(),public.reject_evidence_change(),public.initialize_academy(text,text) from public,anon,authenticated;
grant execute on function public.current_academy_id(),public.can_operate(text) to authenticated;
grant execute on function public.initialize_academy(text,text) to service_role;
