-- Generated from supabase/schema/people/17_staff_identity.sql; edit the source, then run pnpm db:baseline.
alter table public.people add column staff_no bigint unique;
create sequence public.staff_identity_number;
create function public.assign_staff_identity() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.responsibility in ('STAFF','TEACHER') then
  update public.people set staff_no=nextval('public.staff_identity_number') where id=new.person_id and academy_id=new.academy_id and staff_no is null;
 end if;
 return new;
end $$;
revoke all on function public.assign_staff_identity() from public,anon,authenticated;
revoke all on sequence public.staff_identity_number from public,anon,authenticated;
create trigger assign_staff_identity after insert or update on public.person_responsibilities for each row execute function public.assign_staff_identity();
update public.people p set staff_no=nextval('public.staff_identity_number') where staff_no is null and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility in('STAFF','TEACHER'));
create function public.protect_staff_identity() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if old.staff_no is not null and new.staff_no is distinct from old.staff_no then raise exception 'Staff identity cannot be changed.'; end if;
 return new;
end $$;
revoke all on function public.protect_staff_identity() from public,anon,authenticated;
create trigger protect_staff_identity before update on public.people for each row execute function public.protect_staff_identity();
create or replace function public.academy_account_context() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('profileId',p.id,'academyId',p.academy_id,'name',p.display_name,
 'staffId',(select 'SA-STF-'||case when length(person.staff_no::text)<5 then lpad(person.staff_no::text,5,'0') else person.staff_no::text end from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and person.staff_no is not null),'academyName',a.name,'roles',coalesce((select jsonb_agg(role_code order by role_code) from public.account_roles where profile_id=p.id),'[]'),
 'permissions',coalesce((select jsonb_agg(permission order by permission) from (select distinct unnest(r.permissions) permission from public.account_roles ar join public.access_roles r on r.code=ar.role_code where ar.profile_id=p.id)s),'[]'),
 'divisions',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'nameBn',d.name_bn,'code',d.code) order by d.code) from public.operating_divisions d where d.academy_id=p.academy_id and d.is_active),'[]'))
 from public.account_profiles p join public.academies a on a.id=p.academy_id where p.id=auth.uid() and p.is_active
 and not exists(select 1 from public.person_accounts pa join public.people person on person.id=pa.person_id where pa.profile_id=p.id and not person.is_active)
$$;

-- Bootstrap administrators predate the reviewed person-account workflow.
do $$ declare profile record; identity uuid; begin
 for profile in select p.* from public.account_profiles p where exists(select 1 from public.account_roles ar where ar.profile_id=p.id and ar.role_code='ADMIN') and not exists(select 1 from public.person_accounts pa where pa.profile_id=p.id) loop
  insert into public.people(academy_id,full_name,email) values(profile.academy_id,profile.display_name,(select email from auth.users where id=profile.id)) returning id into identity;
  insert into public.person_accounts values(profile.id,identity,profile.academy_id);
  insert into public.person_responsibilities values(identity,profile.academy_id,'STAFF',true);
 end loop;
end $$;
create or replace function public.initialize_academy(admin_email text,admin_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare user_id uuid; academy uuid; identity uuid;
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
 insert into public.people(academy_id,full_name,email) values(academy,btrim(admin_name),lower(btrim(admin_email))) returning id into identity;
 insert into public.person_accounts values(user_id,identity,academy);
 insert into public.person_responsibilities values(identity,academy,'STAFF',true);
 insert into public.activity_events(actor_profile_id,actor_name,actor_roles,action,entity_type,entity_id,reason)
 values(user_id,btrim(admin_name),array['ADMIN'],'BOOTSTRAP','ACCOUNT',user_id::text,'Initial verified academy administrator');
 return user_id;
end $$;
