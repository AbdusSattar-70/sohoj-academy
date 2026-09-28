-- Link Staff identities to Auth profiles.
--
-- create_staff_member() never set staff.profile_id, so a Staff record (e.g. a
-- Teacher) stayed unlinked even when that person signed in. my_erp_context()
-- then returned no staff identity and assigned sessions never appeared.
--
-- Linking rule (conservative):
--   * the Auth user's email is confirmed and equals the Staff email (case-insensitive)
--   * the Auth user has a profile and is not already linked to another Staff record
--   * exactly one ACTIVE / ON_LEAVE unlinked Staff record uses that email

create or replace function public.link_staff_profile_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(nullif(btrim(coalesce(p_email, '')), ''));
  v_user_id uuid;
  v_staff_ids uuid[];
begin
  if v_email is null then
    return null;
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_email
    and u.email_confirmed_at is not null
  order by u.created_at asc
  limit 1;

  if v_user_id is null
     or not exists (select 1 from public.profiles where id = v_user_id)
     or exists (select 1 from public.staff where profile_id = v_user_id) then
    return null;
  end if;

  select array_agg(s.id) into v_staff_ids
  from public.staff s
  where s.profile_id is null
    and lower(s.email) = v_email
    and s.status in ('ACTIVE', 'ON_LEAVE');

  if coalesce(array_length(v_staff_ids, 1), 0) <> 1 then
    return null;
  end if;

  update public.staff
  set profile_id = v_user_id
  where id = v_staff_ids[1]
    and profile_id is null;

  insert into public.audit_events(entity_type, entity_id, action, reason, metadata)
  values (
    'STAFF',
    v_staff_ids[1]::text,
    'LINK_PROFILE',
    'Linked to Auth profile by confirmed email match.',
    jsonb_build_object('profile_id', v_user_id, 'email', v_email)
  );

  return v_staff_ids[1];
end;
$$;

revoke all on function public.link_staff_profile_by_email(text) from public, anon, authenticated;

-- Staff created or edited after the person already has a login.
create or replace function public.staff_link_profile_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.link_staff_profile_by_email(new.email);
  return null;
end;
$$;

drop trigger if exists staff_link_profile on public.staff;
create trigger staff_link_profile
after insert or update of email, status on public.staff
for each row
when (new.profile_id is null and new.email is not null)
execute function public.staff_link_profile_trigger();

-- Person signs up / confirms their email after the Staff record exists.
-- Named so it fires after on_auth_user_created (which creates the profile).
create or replace function public.auth_user_link_staff_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null then
    perform public.link_staff_profile_by_email(new.email);
  end if;
  return null;
end;
$$;

drop trigger if exists on_auth_user_link_staff on auth.users;
create trigger on_auth_user_link_staff
after insert or update of email, email_confirmed_at on auth.users
for each row
execute function public.auth_user_link_staff_trigger();

-- Backfill existing unlinked Staff records.
do $backfill$
declare
  v_email text;
begin
  for v_email in
    select distinct lower(email)
    from public.staff
    where profile_id is null
      and email is not null
      and status in ('ACTIVE', 'ON_LEAVE')
  loop
    perform public.link_staff_profile_by_email(v_email);
  end loop;
end;
$backfill$;
