-- Sohoj Academy ERP v2
-- CRM / Student Bank and Student Core.

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

create type public.student_status as enum (
  'ACTIVE',
  'INACTIVE',
  'WITHDRAWN',
  'GRADUATED',
  'ARCHIVED'
);

create type public.enrollment_status as enum (
  'ACTIVE',
  'COMPLETED',
  'WITHDRAWN',
  'CANCELLED'
);

create sequence public.prospect_no_seq start 1;
create sequence public.student_no_seq start 1;

create or replace function public.generate_prospect_no()
returns text
language sql
as $$
  select 'PR-' || lpad(nextval('public.prospect_no_seq')::text, 6, '0');
$$;

create or replace function public.generate_student_no()
returns text
language sql
as $$
  select 'SA-' || lpad(nextval('public.student_no_seq')::text, 6, '0');
$$;

-- ---------------------------------------------------------------------------
-- CRM / Student Bank
-- ---------------------------------------------------------------------------

create table public.prospects (
  id uuid primary key default gen_random_uuid(),
  prospect_no text not null unique default public.generate_prospect_no(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  student_name text not null,
  student_name_bn text,
  guardian_name text not null,
  guardian_relationship_id uuid references public.guardian_relationships(id),
  guardian_relationship_snapshot text,
  mobile text not null,
  alternate_mobile text,
  current_class_id uuid references public.classes(id),
  school_id uuid references public.schools(id),
  school_name_snapshot text,
  area_id uuid references public.areas(id),
  area_snapshot text,
  preferred_schedule text,
  preferred_days text[] not null default '{}',
  trial_interest boolean not null default false,
  source_id uuid references public.lead_sources(id),
  referral_note text,
  notes text,
  consent_to_contact boolean not null default false,
  status public.prospect_status not null default 'NEW',
  assigned_to_staff_id uuid references public.staff(id),
  next_follow_up_at timestamptz,
  lost_reason text,
  converted_student_id uuid,
  converted_at timestamptz,
  submitted_via text not null default 'PUBLIC_WEB',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index prospects_status_idx on public.prospects(status, created_at desc);
create index prospects_mobile_idx on public.prospects(regexp_replace(mobile, '\D', '', 'g'));
create index prospects_followup_idx on public.prospects(next_follow_up_at)
where next_follow_up_at is not null;

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
  followup_type text not null,
  occurred_at timestamptz not null default now(),
  outcome text,
  notes text not null,
  next_follow_up_at timestamptz,
  recorded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Student master / guardian / enrollment
-- ---------------------------------------------------------------------------

create table public.students (
  id uuid primary key default gen_random_uuid(),
  student_no text not null unique default public.generate_student_no(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  full_name text not null,
  name_bn text,
  gender text,
  date_of_birth date,
  school_id uuid references public.schools(id),
  school_name_snapshot text,
  school_roll text,
  status public.student_status not null default 'ACTIVE',
  created_from_prospect_id uuid unique references public.prospects(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.prospects
  add constraint prospects_converted_student_fkey
  foreign key (converted_student_id) references public.students(id);

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  full_name text not null,
  mobile text not null,
  alternate_mobile text,
  email text,
  address text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index guardians_mobile_idx
on public.guardians(regexp_replace(mobile, '\D', '', 'g'));

create table public.student_guardians (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  guardian_id uuid not null references public.guardians(id),
  relationship_id uuid references public.guardian_relationships(id),
  relationship_snapshot text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (student_id, guardian_id)
);

create unique index one_primary_guardian_per_student
on public.student_guardians(student_id)
where is_primary;

create table public.batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  program_id uuid references public.programs(id),
  code text not null,
  name text not null,
  capacity integer not null default 12,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (capacity > 0),
  unique (organization_id, academic_year_id, code)
);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  program_id uuid references public.programs(id),
  batch_id uuid references public.batches(id),
  admission_date date not null default current_date,
  status public.enrollment_status not null default 'ACTIVE',
  ended_on date,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ended_on is null or ended_on >= admission_date)
);

create unique index one_active_enrollment_per_student_year
on public.enrollments(student_id, academic_year_id)
where status = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- Timestamps and batch integrity
-- ---------------------------------------------------------------------------

create trigger prospects_set_updated_at
before update on public.prospects
for each row execute function public.set_updated_at();

create trigger students_set_updated_at
before update on public.students
for each row execute function public.set_updated_at();

create trigger guardians_set_updated_at
before update on public.guardians
for each row execute function public.set_updated_at();

create trigger batches_set_updated_at
before update on public.batches
for each row execute function public.set_updated_at();

create trigger enrollments_set_updated_at
before update on public.enrollments
for each row execute function public.set_updated_at();

create or replace function public.enforce_batch_policy()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_max integer;
begin
  select coalesce((payload->>'max_students')::integer, 12)
    into v_max
  from public.business_rule_versions
  where domain='academics'
    and rule_key='batch_capacity_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  v_max := coalesce(v_max, 12);

  if new.capacity > v_max then
    raise exception 'Batch capacity exceeds the active academy policy maximum of %.', v_max;
  end if;

  return new;
end;
$$;

create trigger batches_capacity_policy
before insert or update of capacity on public.batches
for each row execute function public.enforce_batch_policy();

create or replace function public.enforce_enrollment_batch_integrity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_batch public.batches;
  v_occupied integer;
begin
  if new.status <> 'ACTIVE' or new.batch_id is null then
    return new;
  end if;

  select * into v_batch
  from public.batches
  where id = new.batch_id
    and is_active
  for update;

  if v_batch.id is null then
    raise exception 'Selected batch is not available.';
  end if;

  if new.organization_id <> v_batch.organization_id
     or new.academic_year_id <> v_batch.academic_year_id
     or new.class_id <> v_batch.class_id
     or new.program_id is distinct from v_batch.program_id then
    raise exception 'Enrollment does not match the selected batch academic context.';
  end if;

  select count(*)::integer into v_occupied
  from public.enrollments e
  where e.batch_id = new.batch_id
    and e.status = 'ACTIVE'
    and e.id <> new.id;

  if v_occupied >= v_batch.capacity then
    raise exception 'Selected batch is full (%/%).', v_occupied, v_batch.capacity;
  end if;

  return new;
end;
$$;

create trigger enrollments_batch_integrity
before insert or update of batch_id,status,academic_year_id,class_id,program_id
on public.enrollments
for each row execute function public.enforce_enrollment_batch_integrity();

-- ---------------------------------------------------------------------------
-- Public interest registration
-- ---------------------------------------------------------------------------

create or replace function public.submit_public_interest(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org public.organizations;
  v_branch public.branches;
  v_prospect public.prospects;
  v_class public.classes;
  v_school public.schools;
  v_source public.lead_sources;
  v_relationship public.guardian_relationships;
  v_program_id uuid;
  v_subject_id uuid;
  v_school_name text;
  v_relationship_text text;
  v_mobile text;
  v_correlation_id uuid := gen_random_uuid();
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Interest request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'student_name','')), '') is null then
    raise exception 'Student name is required.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'guardian_name','')), '') is null then
    raise exception 'Guardian name is required.';
  end if;

  v_mobile := nullif(btrim(coalesce(p_payload->>'mobile','')), '');

  if v_mobile is null or length(regexp_replace(v_mobile, '\D', '', 'g')) < 10 then
    raise exception 'A valid mobile number is required.';
  end if;

  if coalesce((p_payload->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Consent to contact is required.';
  end if;

  select * into v_org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  select * into v_branch
  from public.branches
  where organization_id=v_org.id and code='MAIN' and is_active
  limit 1;

  begin
    select * into v_class
    from public.classes
    where id=(p_payload->>'class_id')::uuid
      and organization_id=v_org.id
      and is_active;
  exception when others then
    raise exception 'Selected class is not available.';
  end;

  if v_class.id is null then
    raise exception 'Selected class is not available.';
  end if;

  if exists (
    select 1
    from public.prospects p
    where regexp_replace(p.mobile, '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and p.current_class_id=v_class.id
      and p.created_at > now() - interval '10 minutes'
  ) then
    raise exception 'A similar interest request was submitted recently.';
  end if;

  v_school_name := nullif(btrim(coalesce(p_payload->>'school_name_snapshot','')), '');

  if nullif(p_payload->>'school_id','') is not null then
    begin
      select * into v_school
      from public.schools
      where id=(p_payload->>'school_id')::uuid
        and organization_id=v_org.id
        and is_active;
    exception when others then
      raise exception 'Selected school is not available.';
    end;

    if v_school.id is null then
      raise exception 'Selected school is not available.';
    end if;

    v_school_name := coalesce(v_school_name, v_school.name);
  elsif v_school_name is not null then
    select * into v_school
    from public.schools
    where organization_id=v_org.id
      and lower(btrim(name))=lower(v_school_name)
      and is_active
    order by is_verified desc, created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools(
        organization_id,
        name,
        is_verified,
        is_active
      )
      values(
        v_org.id,
        v_school_name,
        false,
        true
      )
      returning * into v_school;
    end if;

    v_school_name := v_school.name;
  end if;

  if nullif(p_payload->>'source_code','') is not null then
    select * into v_source
    from public.lead_sources
    where organization_id=v_org.id
      and code=upper(p_payload->>'source_code')
      and is_active;

    if v_source.id is null then
      raise exception 'Selected source is not available.';
    end if;
  end if;

  v_relationship_text := nullif(btrim(coalesce(p_payload->>'guardian_relationship','')), '');

  if v_relationship_text is not null then
    select * into v_relationship
    from public.guardian_relationships
    where organization_id=v_org.id
      and upper(code)=upper(v_relationship_text)
      and is_active
    limit 1;
  end if;

  insert into public.prospects(
    organization_id,
    branch_id,
    student_name,
    student_name_bn,
    guardian_name,
    guardian_relationship_id,
    guardian_relationship_snapshot,
    mobile,
    alternate_mobile,
    current_class_id,
    school_id,
    school_name_snapshot,
    area_snapshot,
    preferred_schedule,
    preferred_days,
    trial_interest,
    source_id,
    referral_note,
    notes,
    consent_to_contact,
    submitted_via
  )
  values(
    v_org.id,
    v_branch.id,
    btrim(p_payload->>'student_name'),
    nullif(btrim(coalesce(p_payload->>'student_name_bn','')), ''),
    btrim(p_payload->>'guardian_name'),
    v_relationship.id,
    v_relationship_text,
    v_mobile,
    nullif(btrim(coalesce(p_payload->>'alternate_mobile','')), ''),
    v_class.id,
    v_school.id,
    v_school_name,
    nullif(btrim(coalesce(p_payload->>'area','')), ''),
    nullif(btrim(coalesce(p_payload->>'preferred_schedule','')), ''),
    case
      when nullif(btrim(coalesce(p_payload->>'preferred_days','')), '') is null
        then '{}'::text[]
      else string_to_array(p_payload->>'preferred_days', ',')
    end,
    coalesce((p_payload->>'trial_interest')::boolean, false),
    v_source.id,
    nullif(btrim(coalesce(p_payload->>'referral_note','')), ''),
    nullif(btrim(coalesce(p_payload->>'notes','')), ''),
    true,
    'PUBLIC_WEB'
  )
  returning * into v_prospect;

  for v_program_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'program_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.programs
      where id=v_program_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected program is not available.';
    end if;

    insert into public.prospect_program_interests(prospect_id,program_id)
    values(v_prospect.id,v_program_id)
    on conflict do nothing;
  end loop;

  for v_subject_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'subject_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.subjects
      where id=v_subject_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected subject is not available.';
    end if;

    insert into public.prospect_subject_interests(prospect_id,subject_id)
    values(v_prospect.id,v_subject_id)
    on conflict do nothing;
  end loop;

  insert into public.audit_events(
    correlation_id,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    'PROSPECT',
    v_prospect.id::text,
    'CREATE_PUBLIC_INTEREST',
    jsonb_build_object(
      'prospect_no',v_prospect.prospect_no,
      'student_name',v_prospect.student_name,
      'current_class_id',v_prospect.current_class_id,
      'source_id',v_prospect.source_id,
      'trial_interest',v_prospect.trial_interest
    ),
    jsonb_build_object('submitted_via','PUBLIC_WEB')
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no
  );
end;
$$;

revoke all on function public.submit_public_interest(jsonb) from public;
grant execute on function public.submit_public_interest(jsonb) to anon,authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.prospects enable row level security;
alter table public.prospect_program_interests enable row level security;
alter table public.prospect_subject_interests enable row level security;
alter table public.prospect_followups enable row level security;
alter table public.students enable row level security;
alter table public.guardians enable row level security;
alter table public.student_guardians enable row level security;
alter table public.batches enable row level security;
alter table public.enrollments enable row level security;

grant select,insert,update on public.prospects,public.prospect_program_interests,
  public.prospect_subject_interests,public.prospect_followups to authenticated;

grant select,insert,update on public.students,public.guardians,
  public.student_guardians,public.batches,public.enrollments to authenticated;

create policy prospects_view
on public.prospects for select to authenticated
using (public.has_permission('crm.prospects.view'));

create policy prospects_manage_insert
on public.prospects for insert to authenticated
with check (public.has_permission('crm.prospects.manage'));

create policy prospects_manage_update
on public.prospects for update to authenticated
using (public.has_permission('crm.prospects.manage'))
with check (public.has_permission('crm.prospects.manage'));

create policy prospect_program_interests_view
on public.prospect_program_interests for select to authenticated
using (public.has_permission('crm.prospects.view'));

create policy prospect_program_interests_manage
on public.prospect_program_interests for all to authenticated
using (public.has_permission('crm.prospects.manage'))
with check (public.has_permission('crm.prospects.manage'));

create policy prospect_subject_interests_view
on public.prospect_subject_interests for select to authenticated
using (public.has_permission('crm.prospects.view'));

create policy prospect_subject_interests_manage
on public.prospect_subject_interests for all to authenticated
using (public.has_permission('crm.prospects.manage'))
with check (public.has_permission('crm.prospects.manage'));

create policy prospect_followups_view
on public.prospect_followups for select to authenticated
using (public.has_permission('crm.prospects.view'));

create policy prospect_followups_manage
on public.prospect_followups for all to authenticated
using (public.has_permission('crm.followups.manage'))
with check (
  public.has_permission('crm.followups.manage')
  and recorded_by=auth.uid()
);

create policy students_view
on public.students for select to authenticated
using (public.has_permission('students.view'));

create policy students_manage_insert
on public.students for insert to authenticated
with check (public.has_permission('students.manage'));

create policy students_manage_update
on public.students for update to authenticated
using (public.has_permission('students.manage'))
with check (public.has_permission('students.manage'));

create policy guardians_view
on public.guardians for select to authenticated
using (public.has_permission('students.view'));

create policy guardians_manage
on public.guardians for all to authenticated
using (public.has_permission('students.manage'))
with check (public.has_permission('students.manage'));

create policy student_guardians_view
on public.student_guardians for select to authenticated
using (public.has_permission('students.view'));

create policy student_guardians_manage
on public.student_guardians for all to authenticated
using (public.has_permission('students.manage'))
with check (public.has_permission('students.manage'));

create policy batches_view
on public.batches for select to authenticated
using (public.has_permission('academics.view') or public.has_permission('admissions.view'));

create policy batches_manage
on public.batches for all to authenticated
using (public.has_permission('academics.manage'))
with check (public.has_permission('academics.manage'));

create policy enrollments_view
on public.enrollments for select to authenticated
using (public.has_permission('students.view') or public.has_permission('admissions.view'));

create policy enrollments_manage
on public.enrollments for all to authenticated
using (public.has_permission('students.manage') or public.has_permission('admissions.create'))
with check (public.has_permission('students.manage') or public.has_permission('admissions.create'));

revoke delete on public.prospects,public.prospect_program_interests,
  public.prospect_subject_interests,public.prospect_followups,
  public.students,public.guardians,public.student_guardians,
  public.batches,public.enrollments from authenticated;
