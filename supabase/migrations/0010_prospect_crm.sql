-- Prospect / Student Bank CRM foundation and public interest registration.
-- Public visitors submit through a controlled RPC; they do not receive direct
-- write access to CRM tables or canonical master data.

create sequence if not exists public.prospect_number_seq start 1;

create or replace function public.generate_prospect_no()
returns text
language sql
as $$
  select 'PR-' || lpad(nextval('public.prospect_number_seq')::text, 6, '0');
$$;

create type public.prospect_status as enum (
  'NEW',
  'CONTACTED',
  'COUNSELLING',
  'TRIAL_SCHEDULED',
  'TRIAL_ATTENDED',
  'REGISTERED',
  'CONVERTED',
  'FUTURE_FOLLOW_UP',
  'LOST'
);

create table public.lead_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  code text not null unique,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index lead_sources_name_normalized_uq
  on public.lead_sources(lower(btrim(name)));

insert into public.lead_sources(name, code) values
  ('Walk-in', 'WALK_IN'),
  ('Facebook / Social Media', 'SOCIAL'),
  ('Teacher Referral', 'TEACHER_REFERRAL'),
  ('Student Referral', 'STUDENT_REFERRAL'),
  ('Guardian Referral', 'GUARDIAN_REFERRAL'),
  ('School Visit', 'SCHOOL_VISIT'),
  ('Miking / Leaflet', 'OFFLINE_CAMPAIGN'),
  ('Other', 'OTHER')
on conflict (code) do nothing;

create table public.prospects (
  id uuid primary key default gen_random_uuid(),
  prospect_no text not null unique default public.generate_prospect_no(),
  student_name text not null check (char_length(btrim(student_name)) >= 2),
  student_name_bn text,
  guardian_name text not null check (char_length(btrim(guardian_name)) >= 2),
  guardian_relationship text,
  mobile text not null check (char_length(btrim(mobile)) >= 10),
  alternate_mobile text,
  school_id uuid references public.schools(id),
  school_name_snapshot text,
  current_class_id uuid references public.classes(id),
  area text,
  preferred_schedule text,
  preferred_days text,
  trial_interest boolean not null default false,
  status public.prospect_status not null default 'NEW',
  source_id uuid references public.lead_sources(id),
  referral_note text,
  notes text,
  consent_to_contact boolean not null default true,
  submitted_via text not null default 'PUBLIC_WEB',
  assigned_to uuid references public.profiles(id),
  next_follow_up date,
  lost_reason text,
  converted_student_id uuid references public.students(id),
  converted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'CONVERTED' and converted_student_id is not null and converted_at is not null)
    or status <> 'CONVERTED'
  )
);

create index prospects_mobile_idx on public.prospects(mobile);
create index prospects_status_created_idx on public.prospects(status, created_at desc);
create index prospects_class_idx on public.prospects(current_class_id);
create index prospects_school_idx on public.prospects(school_id);
create index prospects_source_idx on public.prospects(source_id);

create table public.prospect_program_interests (
  prospect_id uuid not null references public.prospects(id),
  program_id uuid not null references public.programs(id),
  created_at timestamptz not null default now(),
  primary key (prospect_id, program_id)
);

create table public.prospect_subject_interests (
  prospect_id uuid not null references public.prospects(id),
  subject_id uuid not null references public.subjects(id),
  created_at timestamptz not null default now(),
  primary key (prospect_id, subject_id)
);

create table public.prospect_followups (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null references public.prospects(id),
  occurred_at timestamptz not null default now(),
  followup_type text not null check (
    followup_type in ('CALL','MEETING','SMS','WHATSAPP','TRIAL','OTHER')
  ),
  outcome text,
  notes text not null,
  next_follow_up date,
  recorded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create index prospect_followups_prospect_idx
  on public.prospect_followups(prospect_id, occurred_at desc);

alter table public.lead_sources enable row level security;
alter table public.prospects enable row level security;
alter table public.prospect_program_interests enable row level security;
alter table public.prospect_subject_interests enable row level security;
alter table public.prospect_followups enable row level security;

grant select on public.lead_sources to authenticated, anon;
grant select, insert, update on public.lead_sources to authenticated;
grant select, insert, update on public.prospects to authenticated;
grant select, insert, update on public.prospect_program_interests to authenticated;
grant select, insert, update on public.prospect_subject_interests to authenticated;
grant select, insert, update on public.prospect_followups to authenticated;

revoke delete on public.lead_sources from authenticated;
revoke delete on public.prospects from authenticated;
revoke delete on public.prospect_program_interests from authenticated;
revoke delete on public.prospect_subject_interests from authenticated;
revoke delete on public.prospect_followups from authenticated;

create policy "public read active lead sources" on public.lead_sources
for select to anon using (is_active);

create policy "staff read lead sources" on public.lead_sources
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin operator manage lead sources" on public.lead_sources
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator read prospects" on public.prospects
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator manage prospects" on public.prospects
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator read prospect program interests"
on public.prospect_program_interests
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator manage prospect program interests"
on public.prospect_program_interests
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator read prospect subject interests"
on public.prospect_subject_interests
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator manage prospect subject interests"
on public.prospect_subject_interests
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator read prospect followups" on public.prospect_followups
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'));

create policy "admin operator manage prospect followups" on public.prospect_followups
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (
  public.current_role() in ('ADMIN','OPERATOR')
  and recorded_by = auth.uid()
);

-- Public pages may read only active, non-sensitive master data needed by the form.
grant select on public.classes, public.programs, public.subjects, public.schools to anon;

create policy "public read classes" on public.classes
for select to anon using (true);

create policy "public read active programs" on public.programs
for select to anon using (is_active);

create policy "public read active subjects" on public.subjects
for select to anon using (is_active);

create policy "public read active schools" on public.schools
for select to anon using (is_active);

create or replace function public.submit_public_interest(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prospect public.prospects;
  v_class_id uuid;
  v_school_id uuid;
  v_source_id uuid;
  v_program_id uuid;
  v_subject_id uuid;
  v_student_name text := btrim(coalesce(p_payload->>'student_name',''));
  v_guardian_name text := btrim(coalesce(p_payload->>'guardian_name',''));
  v_mobile text := btrim(coalesce(p_payload->>'mobile',''));
begin
  if char_length(v_student_name) < 2 then
    raise exception 'Student name is required.';
  end if;

  if char_length(v_guardian_name) < 2 then
    raise exception 'Guardian name is required.';
  end if;

  if char_length(v_mobile) < 10 then
    raise exception 'A valid mobile number is required.';
  end if;

  if coalesce((p_payload->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Consent to contact is required.';
  end if;

  if nullif(p_payload->>'class_id','') is not null then
    v_class_id := (p_payload->>'class_id')::uuid;
    if not exists(select 1 from public.classes where id=v_class_id) then
      raise exception 'Selected class is not available.';
    end if;
  end if;

  if nullif(p_payload->>'school_id','') is not null then
    v_school_id := (p_payload->>'school_id')::uuid;
    if not exists(select 1 from public.schools where id=v_school_id and is_active) then
      raise exception 'Selected school is not available.';
    end if;
  end if;

  if nullif(p_payload->>'source_id','') is not null then
    v_source_id := (p_payload->>'source_id')::uuid;
    if not exists(select 1 from public.lead_sources where id=v_source_id and is_active) then
      raise exception 'Selected source is not available.';
    end if;
  end if;

  if exists (
    select 1
    from public.prospects p
    where regexp_replace(p.mobile, '\D', '', 'g') = regexp_replace(v_mobile, '\D', '', 'g')
      and lower(btrim(p.student_name)) = lower(v_student_name)
      and p.created_at >= now() - interval '10 minutes'
  ) then
    raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
  end if;

  insert into public.prospects(
    student_name,
    student_name_bn,
    guardian_name,
    guardian_relationship,
    mobile,
    alternate_mobile,
    school_id,
    school_name_snapshot,
    current_class_id,
    area,
    preferred_schedule,
    preferred_days,
    trial_interest,
    source_id,
    referral_note,
    notes,
    consent_to_contact,
    submitted_via
  )
  values (
    v_student_name,
    nullif(btrim(coalesce(p_payload->>'student_name_bn','')), ''),
    v_guardian_name,
    nullif(btrim(coalesce(p_payload->>'guardian_relationship','')), ''),
    v_mobile,
    nullif(btrim(coalesce(p_payload->>'alternate_mobile','')), ''),
    v_school_id,
    nullif(btrim(coalesce(p_payload->>'school_name_snapshot','')), ''),
    v_class_id,
    nullif(btrim(coalesce(p_payload->>'area','')), ''),
    nullif(btrim(coalesce(p_payload->>'preferred_schedule','')), ''),
    nullif(btrim(coalesce(p_payload->>'preferred_days','')), ''),
    coalesce((p_payload->>'trial_interest')::boolean, false),
    v_source_id,
    nullif(btrim(coalesce(p_payload->>'referral_note','')), ''),
    nullif(btrim(coalesce(p_payload->>'notes','')), ''),
    true,
    'PUBLIC_WEB'
  )
  returning * into v_prospect;

  for v_program_id in
    select distinct value::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'program_ids','[]'::jsonb))
  loop
    if not exists(select 1 from public.programs where id=v_program_id and is_active) then
      raise exception 'One selected program is not available.';
    end if;

    insert into public.prospect_program_interests(prospect_id, program_id)
    values(v_prospect.id, v_program_id)
    on conflict do nothing;
  end loop;

  for v_subject_id in
    select distinct value::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'subject_ids','[]'::jsonb))
  loop
    if not exists(select 1 from public.subjects where id=v_subject_id and is_active) then
      raise exception 'One selected subject is not available.';
    end if;

    insert into public.prospect_subject_interests(prospect_id, subject_id)
    values(v_prospect.id, v_subject_id)
    on conflict do nothing;
  end loop;

  insert into public.audit_events(
    correlation_id,
    actor_id,
    actor_role,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    gen_random_uuid(),
    null,
    null,
    'PROSPECT',
    v_prospect.id::text,
    'PUBLIC_INTEREST_SUBMITTED',
    jsonb_build_object(
      'prospect_no', v_prospect.prospect_no,
      'status', v_prospect.status,
      'submitted_via', v_prospect.submitted_via
    ),
    jsonb_build_object('channel','PUBLIC_WEB')
  );

  return jsonb_build_object(
    'prospect_id', v_prospect.id,
    'prospect_no', v_prospect.prospect_no,
    'status', v_prospect.status
  );
end;
$$;

revoke all on function public.submit_public_interest(jsonb) from public;
grant execute on function public.submit_public_interest(jsonb) to anon, authenticated;
