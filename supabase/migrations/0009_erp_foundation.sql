-- ERP foundation: canonical master data, versioned rules, approvals, audit events
-- and enrollment integrity. This migration intentionally adds foundations without
-- forcing every future module into the first release.

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  name_bn text,
  area text,
  district text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index schools_name_normalized_uq
  on public.schools (lower(btrim(name)));

alter table public.students
  add column school_id uuid references public.schools(id);

create index students_school_id_idx on public.students(school_id);

create table public.business_rule_versions (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null,
  version integer not null check (version > 0),
  status text not null default 'DRAFT'
    check (status in ('DRAFT','ACTIVE','RETIRED')),
  value jsonb not null,
  effective_from date not null default current_date,
  effective_to date,
  notes text,
  created_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (rule_key, version),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index business_rule_one_active_uq
  on public.business_rule_versions(rule_key)
  where status = 'ACTIVE';

insert into public.business_rule_versions
  (rule_key, version, status, value, notes, approved_at)
values
  (
    'academics.batch_capacity_policy',
    1,
    'ACTIVE',
    '{"max_students":12}'::jsonb,
    'Initial Sohoj Academy maximum-students-per-batch policy.',
    now()
  ),
  (
    'teacher_compensation.default_policy',
    1,
    'ACTIVE',
    '{
      "teaching_pool_percent":30,
      "teaching_pool_max_percent":40,
      "student_acquisition_percent":50,
      "retention_3_month_percent":15,
      "retention_6_month_percent":20
    }'::jsonb,
    'Initial Revenue Sharing policy. Future changes must create a new version.',
    now()
  );

create type public.approval_status as enum (
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED'
);

create table public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  workflow_type text not null,
  entity_type text not null,
  entity_id text not null,
  requested_action text not null,
  status public.approval_status not null default 'PENDING',
  payload_snapshot jsonb,
  request_note text,
  requested_by uuid not null references public.profiles(id),
  requested_at timestamptz not null default now(),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  decision_note text,
  correlation_id uuid not null default gen_random_uuid(),
  check (
    (status = 'PENDING' and decided_by is null and decided_at is null)
    or status <> 'PENDING'
  )
);

create unique index approval_request_pending_entity_uq
  on public.approval_requests(workflow_type, entity_type, entity_id, requested_action)
  where status = 'PENDING';

create table public.audit_events (
  id bigint generated always as identity primary key,
  correlation_id uuid not null default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  actor_role public.app_role,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  before_data jsonb,
  after_data jsonb,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index audit_events_entity_idx
  on public.audit_events(entity_type, entity_id, occurred_at desc);
create index audit_events_actor_idx
  on public.audit_events(actor_id, occurred_at desc);
create index audit_events_correlation_idx
  on public.audit_events(correlation_id);

create or replace function public.record_audit_event(
  p_entity_type text,
  p_entity_id text,
  p_action text,
  p_before_data jsonb default null,
  p_after_data jsonb default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_correlation_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_user uuid := auth.uid();
  v_role public.app_role;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role from public.profiles where id = v_user;

  insert into public.audit_events (
    correlation_id, actor_id, actor_role, entity_type, entity_id,
    action, before_data, after_data, reason, metadata
  )
  values (
    coalesce(p_correlation_id, gen_random_uuid()), v_user, v_role,
    p_entity_type, p_entity_id, p_action,
    p_before_data, p_after_data, p_reason, coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.record_audit_event(
  text,text,text,jsonb,jsonb,text,jsonb,uuid
) to authenticated;

-- Active rule values are immutable. Retire an active version and create a new
-- version instead of editing the historical policy value in place.
create or replace function public.protect_active_business_rule()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'ACTIVE' and (
    new.rule_key is distinct from old.rule_key
    or new.version is distinct from old.version
    or new.value is distinct from old.value
    or new.effective_from is distinct from old.effective_from
  ) then
    raise exception 'Active business-rule values are immutable. Retire this version and create a new version.';
  end if;
  return new;
end;
$$;

create trigger protect_active_business_rule_update
before update on public.business_rule_versions
for each row execute function public.protect_active_business_rule();

-- Batch capacity is enforced using the active versioned academy policy.
create or replace function public.enforce_batch_capacity_policy()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_max integer;
begin
  select (value->>'max_students')::integer
    into v_max
  from public.business_rule_versions
  where rule_key = 'academics.batch_capacity_policy'
    and status = 'ACTIVE'
    and effective_from <= current_date
    and (effective_to is null or effective_to >= current_date)
  order by version desc
  limit 1;

  if v_max is null then
    raise exception 'No active batch-capacity policy is configured.';
  end if;

  if new.capacity > v_max then
    raise exception 'Batch capacity % exceeds the active academy maximum of %.', new.capacity, v_max;
  end if;

  return new;
end;
$$;

create trigger enforce_batch_capacity_policy_trigger
before insert or update of capacity on public.batches
for each row execute function public.enforce_batch_capacity_policy();

-- Enrollment must match its selected batch and the batch cannot overfill.
create or replace function public.enforce_enrollment_batch_integrity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_batch public.batches;
  v_active_count integer;
begin
  if not new.is_active or new.batch_id is null then
    return new;
  end if;

  select * into v_batch from public.batches where id = new.batch_id;
  if v_batch.id is null then
    raise exception 'Selected batch does not exist.';
  end if;

  if new.academic_year_id <> v_batch.academic_year_id
     or new.class_id <> v_batch.class_id
     or (v_batch.program_id is not null and new.program_id is distinct from v_batch.program_id) then
    raise exception 'Enrollment academic year/class/program does not match the selected batch.';
  end if;

  select count(*)
    into v_active_count
  from public.enrollments e
  where e.batch_id = new.batch_id
    and e.is_active
    and e.id <> new.id;

  if v_active_count >= v_batch.capacity then
    raise exception 'Selected batch is full (%/%).', v_active_count, v_batch.capacity;
  end if;

  return new;
end;
$$;

create trigger enforce_enrollment_batch_integrity_trigger
before insert or update of batch_id, academic_year_id, class_id, program_id, is_active
on public.enrollments
for each row execute function public.enforce_enrollment_batch_integrity();

alter table public.enrollments
  add constraint enrollment_discount_not_above_fee
  check (discount <= monthly_fee) not valid;

-- RLS and privileges.
alter table public.schools enable row level security;
alter table public.business_rule_versions enable row level security;
alter table public.approval_requests enable row level security;
alter table public.audit_events enable row level security;

grant select, insert, update on public.schools to authenticated;
grant select, insert, update on public.business_rule_versions to authenticated;
grant select, insert, update on public.approval_requests to authenticated;
grant select on public.audit_events to authenticated;

create policy "staff read schools" on public.schools
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "admin operator manage schools" on public.schools
for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "authenticated read active business rules" on public.business_rule_versions
for select to authenticated
using (status = 'ACTIVE' or public.current_role() = 'ADMIN');

create policy "admin manage business rule versions" on public.business_rule_versions
for all to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read approval requests" on public.approval_requests
for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff submit approval requests" on public.approval_requests
for insert to authenticated
with check (
  public.current_role() in ('ADMIN','OPERATOR','TEACHER')
  and requested_by = auth.uid()
);

create policy "admin decide approval requests" on public.approval_requests
for update to authenticated
using (public.current_role() = 'ADMIN')
with check (public.current_role() = 'ADMIN');

create policy "staff read relevant audit events" on public.audit_events
for select to authenticated
using (
  public.current_role() in ('ADMIN','OPERATOR')
  or actor_id = auth.uid()
);

revoke delete on public.schools from authenticated;
revoke delete on public.business_rule_versions from authenticated;
revoke delete on public.approval_requests from authenticated;
revoke insert, update, delete on public.audit_events from authenticated;
