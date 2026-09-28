-- Phase 2: versioned, reviewed public offering content.
-- Existing programme_offerings columns remain the current live contract until a
-- published version is selected. Each version is immutable after publication.

create table public.programme_offering_public_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.programme_offerings(id) on delete cascade,
  version integer not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'PENDING_REVIEW', 'PUBLISHED', 'RETIRED')),
  content jsonb not null check (jsonb_typeof(content) = 'object'),
  change_reason text not null check (length(btrim(change_reason)) between 5 and 500),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  submitted_by uuid references public.profiles(id),
  submitted_at timestamptz,
  published_by uuid references public.profiles(id),
  published_at timestamptz,
  unique (offering_id, version)
);

create unique index programme_offering_public_one_published
  on public.programme_offering_public_versions(offering_id)
  where status = 'PUBLISHED';
create index programme_offering_public_versions_history_idx
  on public.programme_offering_public_versions(offering_id, version desc);

alter table public.programme_offering_public_versions enable row level security;
grant select on public.programme_offering_public_versions to authenticated;
revoke insert, update, delete on public.programme_offering_public_versions from anon, authenticated;
create policy programme_offering_public_versions_staff_read
on public.programme_offering_public_versions for select to authenticated
using (public.has_permission('academics.view'));

create or replace function public.create_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  offering uuid := nullif(p_input->>'offering_id', '')::uuid;
  reason text := btrim(coalesce(p_input->>'reason', ''));
  content jsonb := p_input->'content';
  next_version integer;
  created programme_offering_public_versions;
begin
  if actor is null or not public.has_permission('academics.manage') then
    raise exception 'Offering management permission required.';
  end if;
  if offering is null or length(reason) not between 5 and 500 or jsonb_typeof(content) <> 'object' then
    raise exception 'Offering, reason and public content are required.';
  end if;
  if not exists (select 1 from public.programme_offerings where id = offering) then
    raise exception 'Programme offering not found.';
  end if;
  select coalesce(max(version), 0) + 1 into next_version
  from public.programme_offering_public_versions
  where offering_id = offering;
  insert into public.programme_offering_public_versions(offering_id, version, content, change_reason, created_by)
  values (offering, next_version, content, reason, actor)
  returning * into created;
  return jsonb_build_object('id', created.id, 'version', created.version, 'status', created.status);
end;
$$;

create or replace function public.submit_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare actor uuid := auth.uid(); v programme_offering_public_versions;
begin
  if actor is null or not public.has_permission('academics.manage') then raise exception 'Offering management permission required.'; end if;
  select * into v from public.programme_offering_public_versions
  where id = (p_input->>'version_id')::uuid for update;
  if not found or v.status <> 'DRAFT' then raise exception 'Only a draft version can be submitted.'; end if;
  update public.programme_offering_public_versions
  set status = 'PENDING_REVIEW', submitted_by = actor, submitted_at = now()
  where id = v.id;
  return jsonb_build_object('id', v.id, 'version', v.version, 'status', 'PENDING_REVIEW');
end;
$$;

create or replace function public.publish_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare actor uuid := auth.uid(); v programme_offering_public_versions; old_id uuid;
begin
  if actor is null or not public.has_permission('academics.manage') then raise exception 'Offering management permission required.'; end if;
  select * into v from public.programme_offering_public_versions
  where id = (p_input->>'version_id')::uuid for update;
  if not found or v.status <> 'PENDING_REVIEW' then raise exception 'Only a submitted version can be published.'; end if;
  if v.submitted_by = actor then raise exception 'The author cannot publish their own public content.'; end if;
  select id into old_id from public.programme_offering_public_versions
  where offering_id = v.offering_id and status = 'PUBLISHED' for update;
  update public.programme_offering_public_versions set status = 'RETIRED' where id = old_id;
  update public.programme_offering_public_versions
  set status = 'PUBLISHED', published_by = actor, published_at = now()
  where id = v.id;
  update public.programme_offerings set
    showcase_title = v.content->>'showcase_title', showcase_title_bn = v.content->>'showcase_title_bn',
    showcase_description = v.content->>'showcase_description', showcase_description_bn = v.content->>'showcase_description_bn',
    showcase_eyebrow = v.content->>'showcase_eyebrow', showcase_eyebrow_bn = v.content->>'showcase_eyebrow_bn',
    public_schedule = v.content->>'public_schedule', public_schedule_bn = v.content->>'public_schedule_bn',
    public_requirements = v.content->>'public_requirements', public_requirements_bn = v.content->>'public_requirements_bn',
    admission_policy = v.content->>'admission_policy', admission_policy_bn = v.content->>'admission_policy_bn',
    updated_at = now()
  where id = v.offering_id;
  return jsonb_build_object('id', v.id, 'version', v.version, 'status', 'PUBLISHED');
end;
$$;

revoke all on function public.create_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.create_programme_offering_public_version(jsonb) to authenticated;
revoke all on function public.submit_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.submit_programme_offering_public_version(jsonb) to authenticated;
revoke all on function public.publish_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.publish_programme_offering_public_version(jsonb) to authenticated;
