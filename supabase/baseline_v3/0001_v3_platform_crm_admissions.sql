-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 01
-- Generated from the reviewed V2 schema history for application on a CLEAN database.
-- No production/test data migration is included.
-- Apply baseline parts in filename order.

-- ============================================================
-- SOURCE: 0001_v2_platform.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Platform, identity, permissions, audit, approvals, business rules and master data.
-- This is a clean baseline intended for a destructive development reset.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.profile_status as enum ('ACTIVE','SUSPENDED','ARCHIVED');
create type public.staff_status as enum (
  'ACTIVE',
  'ON_LEAVE',
  'RESIGNED',
  'TERMINATED',
  'ARCHIVED'
);
create type public.approval_status as enum (
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED'
);
create type public.rule_status as enum ('DRAFT','ACTIVE','RETIRED');

-- ---------------------------------------------------------------------------
-- Organization and branch foundation
-- ---------------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  timezone text not null default 'Asia/Dhaka',
  currency_code text not null default 'BDT',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  address text,
  timezone text not null default 'Asia/Dhaka',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

-- ---------------------------------------------------------------------------
-- Authentication profile and permission-based RBAC
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  status public.profile_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.system_roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_system boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.system_roles(id),
  permission_id uuid not null references public.permissions(id),
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.user_role_assignments (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id),
  role_id uuid not null references public.system_roles(id),
  branch_id uuid references public.branches(id),
  effective_from date not null default current_date,
  effective_to date,
  is_active boolean not null default true,
  assigned_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index user_role_open_assignment_uniq
on public.user_role_assignments(
  profile_id,
  role_id,
  coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)
)
where is_active and effective_to is null;

-- ---------------------------------------------------------------------------
-- Staff is the canonical employee/teacher identity.
-- ---------------------------------------------------------------------------

create sequence public.staff_no_seq start 1;

create or replace function public.generate_staff_no()
returns text
language sql
as $$
  select 'SA-STF-' || lpad(nextval('public.staff_no_seq')::text, 6, '0');
$$;

create table public.staff (
  id uuid primary key default gen_random_uuid(),
  staff_no text not null unique default public.generate_staff_no(),
  profile_id uuid unique references public.profiles(id),
  branch_id uuid references public.branches(id),
  full_name text not null,
  mobile text,
  alternate_mobile text,
  email text,
  address text,
  emergency_contact_name text,
  emergency_contact_mobile text,
  joined_on date,
  left_on date,
  status public.staff_status not null default 'ACTIVE',
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (left_on is null or joined_on is null or left_on >= joined_on)
);

create table public.staff_roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  is_teaching_role boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.staff_role_assignments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  staff_role_id uuid not null references public.staff_roles(id),
  branch_id uuid references public.branches(id),
  effective_from date not null default current_date,
  effective_to date,
  is_primary boolean not null default false,
  assigned_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index staff_primary_open_role_uniq
on public.staff_role_assignments(staff_id)
where is_primary and effective_to is null;

-- ---------------------------------------------------------------------------
-- Universal audit and approval engine
-- ---------------------------------------------------------------------------

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  actor_profile_id uuid references public.profiles(id),
  actor_staff_id uuid references public.staff(id),
  actor_role_code text,
  branch_id uuid references public.branches(id),
  entity_type text not null,
  entity_id text not null,
  action text not null,
  reason text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb
);

create index audit_events_entity_idx
on public.audit_events(entity_type, entity_id, occurred_at desc);

create index audit_events_correlation_idx
on public.audit_events(correlation_id);

create table public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null default gen_random_uuid(),
  workflow_type text not null,
  entity_type text not null,
  entity_id text not null,
  requested_action text not null,
  payload_snapshot jsonb not null default '{}'::jsonb,
  request_note text,
  status public.approval_status not null default 'PENDING',
  requested_by uuid not null references public.profiles(id),
  requested_at timestamptz not null default now(),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now(),
  check (
    (status = 'PENDING' and decided_by is null and decided_at is null)
    or status <> 'PENDING'
  )
);

create index approval_requests_pending_idx
on public.approval_requests(status, requested_at)
where status = 'PENDING';

-- ---------------------------------------------------------------------------
-- Versioned business rules
-- ---------------------------------------------------------------------------

create table public.business_rule_versions (
  id uuid primary key default gen_random_uuid(),
  domain text not null,
  rule_key text not null,
  version integer not null,
  status public.rule_status not null default 'DRAFT',
  effective_from date not null default current_date,
  effective_to date,
  payload jsonb not null,
  change_reason text not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique (domain, rule_key, version)
);

create unique index one_active_business_rule
on public.business_rule_versions(domain, rule_key)
where status = 'ACTIVE';

-- ---------------------------------------------------------------------------
-- Canonical master data
-- ---------------------------------------------------------------------------

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (organization_id, name)
);

create unique index one_active_academic_year_per_org
on public.academic_years(organization_id)
where is_active;

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  parent_id uuid references public.areas(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index areas_name_parent_uniq
on public.areas(
  organization_id,
  lower(name),
  coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  area_id uuid references public.areas(id),
  name text not null,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index schools_search_idx on public.schools(lower(name));

create table public.lead_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.guardian_relationships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, code)
);

-- ---------------------------------------------------------------------------
-- Generic timestamps and integrity helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

create trigger branches_set_updated_at
before update on public.branches
for each row execute function public.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger staff_set_updated_at
before update on public.staff
for each row execute function public.set_updated_at();

create trigger schools_set_updated_at
before update on public.schools
for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email,''), '@', 1), ''),
      'User'
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Existing Auth users also receive a profile during a clean reset.
insert into public.profiles(id, display_name)
select
  u.id,
  coalesce(
    nullif(u.raw_user_meta_data ->> 'full_name', ''),
    nullif(split_part(coalesce(u.email,''), '@', 1), ''),
    'User'
  )
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Permission helpers
-- ---------------------------------------------------------------------------

create or replace function public.has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_role_assignments ura
    join public.system_roles sr on sr.id = ura.role_id
    join public.role_permissions rp on rp.role_id = sr.id
    join public.permissions p on p.id = rp.permission_id
    join public.profiles pr on pr.id = ura.profile_id
    where ura.profile_id = auth.uid()
      and ura.is_active
      and (ura.effective_to is null or ura.effective_to >= current_date)
      and ura.effective_from <= current_date
      and sr.is_active
      and pr.status = 'ACTIVE'
      and p.code = p_permission_code
  );
$$;

create or replace function public.my_erp_context()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile_id', p.id,
    'display_name', p.display_name,
    'status', p.status,
    'staff_id', s.id,
    'staff_no', s.staff_no,
    'staff_name', s.full_name,
    'roles', coalesce((
      select jsonb_agg(distinct sr.code order by sr.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct pe.code order by pe.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      join public.role_permissions rp on rp.role_id = sr.id
      join public.permissions pe on pe.id = rp.permission_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb)
  )
  from public.profiles p
  left join public.staff s on s.profile_id = p.id
  where p.id = auth.uid();
$$;

-- SQL-editor-only bootstrap helper. It is intentionally not granted to API roles.
create or replace function public.bootstrap_admin(
  p_email text,
  p_full_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user auth.users;
  v_profile public.profiles;
  v_role public.system_roles;
  v_staff public.staff;
  v_staff_role public.staff_roles;
  v_branch public.branches;
begin
  select * into v_user
  from auth.users
  where lower(email) = lower(btrim(p_email))
  order by created_at asc
  limit 1;

  if v_user.id is null then
    raise exception 'Auth user not found for email %', p_email;
  end if;

  insert into public.profiles(id, display_name, status)
  values (
    v_user.id,
    coalesce(
      nullif(btrim(p_full_name), ''),
      nullif(v_user.raw_user_meta_data ->> 'full_name', ''),
      split_part(v_user.email, '@', 1)
    ),
    'ACTIVE'
  )
  on conflict (id) do update
  set
    display_name = excluded.display_name,
    status = 'ACTIVE',
    updated_at = now()
  returning * into v_profile;

  select * into v_role
  from public.system_roles
  where code = 'ADMIN';

  select * into v_staff_role
  from public.staff_roles
  where code = 'ADMINISTRATION';

  select * into v_branch
  from public.branches
  where code = 'MAIN'
  order by created_at asc
  limit 1;

  select * into v_staff
  from public.staff
  where profile_id = v_profile.id;

  if v_staff.id is null then
    insert into public.staff(
      profile_id,
      branch_id,
      full_name,
      email,
      joined_on,
      status
    )
    values (
      v_profile.id,
      v_branch.id,
      v_profile.display_name,
      v_user.email,
      current_date,
      'ACTIVE'
    )
    returning * into v_staff;
  end if;

  insert into public.user_role_assignments(
    profile_id,
    role_id,
    branch_id,
    is_active
  )
  values (
    v_profile.id,
    v_role.id,
    null,
    true
  )
  on conflict do nothing;

  insert into public.staff_role_assignments(
    staff_id,
    staff_role_id,
    branch_id,
    effective_from,
    is_primary
  )
  select
    v_staff.id,
    v_staff_role.id,
    v_branch.id,
    current_date,
    true
  where not exists (
    select 1
    from public.staff_role_assignments sra
    where sra.staff_id = v_staff.id
      and sra.staff_role_id = v_staff_role.id
      and sra.effective_to is null
  );

  return jsonb_build_object(
    'profile_id', v_profile.id,
    'staff_id', v_staff.id,
    'staff_no', v_staff.staff_no,
    'role', 'ADMIN'
  );
end;
$$;

revoke all on function public.bootstrap_admin(text,text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Approval maker-checker and business-rule immutability
-- ---------------------------------------------------------------------------

create or replace function public.enforce_approval_decision()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status <> 'PENDING' and new.status is distinct from old.status then
    raise exception 'A decided approval request cannot be decided again.';
  end if;

  if new.status = 'APPROVED' and old.requested_by = new.decided_by then
    raise exception 'Maker-checker violation: requester cannot approve their own request.';
  end if;

  if new.status in ('APPROVED','REJECTED','CANCELLED') then
    if new.decided_by is null then
      raise exception 'Decision actor is required.';
    end if;
    if new.decided_at is null then
      new.decided_at := now();
    end if;
  end if;

  return new;
end;
$$;

create trigger approval_requests_decision_guard
before update of status on public.approval_requests
for each row execute function public.enforce_approval_decision();

create or replace function public.protect_active_business_rule()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Business rule versions are never deleted.';
  end if;

  if old.status = 'ACTIVE' and (
    new.domain is distinct from old.domain
    or new.rule_key is distinct from old.rule_key
    or new.version is distinct from old.version
    or new.payload is distinct from old.payload
    or new.effective_from is distinct from old.effective_from
  ) then
    raise exception 'Active business rule content is immutable. Retire it and create a new version.';
  end if;

  return new;
end;
$$;

create trigger business_rule_version_guard
before update or delete on public.business_rule_versions
for each row execute function public.protect_active_business_rule();

-- ---------------------------------------------------------------------------
-- Seed organization, branch, roles, permissions and current business rules
-- ---------------------------------------------------------------------------

insert into public.organizations(code,name)
values ('SOHOJ','Sohoj Academy');

insert into public.branches(organization_id,code,name,address)
select id,'MAIN','Main Campus','Gopalpur Bazar, Narundi Road, Jamalpur Sadar'
from public.organizations
where code='SOHOJ';

insert into public.system_roles(code,name,description)
values
  ('ADMIN','Administrator','Full ERP administration with approval and audit access.'),
  ('ACADEMIC_DIRECTOR','Academic Director','Academic planning, review and approval authority.'),
  ('OPERATOR','Operator','Admissions, CRM, routine operations and fee collection.'),
  ('TEACHER','Teacher','Teaching, attendance, assessment and class-log workflows.'),
  ('ACCOUNTANT','Accountant','Finance, billing, reconciliation and accounting workflows.'),
  ('GUARDIAN','Guardian','Reserved for the future Guardian portal.'),
  ('STUDENT','Student','Reserved for the future Student portal.');

insert into public.permissions(code,name,description)
values
  ('dashboard.view','View dashboard','Access ERP dashboard.'),
  ('action_center.view','View Action Center','View tasks and exceptions requiring action.'),
  ('crm.prospects.view','View prospects','View CRM prospects and timelines.'),
  ('crm.prospects.manage','Manage prospects','Create/update prospects and outcomes.'),
  ('crm.followups.manage','Manage follow-ups','Record CRM follow-ups.'),
  ('admissions.view','View admissions','View admissions.'),
  ('admissions.create','Create admissions','Create admission workflows.'),
  ('admissions.approve','Approve admissions','Approve controlled admission exceptions.'),
  ('students.view','View students','View student master data.'),
  ('students.manage','Manage students','Manage student lifecycle data.'),
  ('academics.view','View academics','View academic operations.'),
  ('academics.manage','Manage academics','Manage academic master/operational data.'),
  ('academics.curriculum.manage','Manage curriculum','Manage curriculum and syllabus plans.'),
  ('academics.sessions.manage','Manage sessions','Manage routines and class sessions.'),
  ('academics.attendance.record','Record attendance','Create attendance drafts.'),
  ('academics.attendance.approve','Approve attendance','Approve/finalize attendance.'),
  ('academics.assessments.record','Record results','Create assessment/result drafts.'),
  ('academics.assessments.approve','Approve results','Approve/finalize assessment results.'),
  ('academics.coverage.manage','Manage coverage','Manage coverage gaps and recovery.'),
  ('finance.view','View finance','View financial records and reports.'),
  ('finance.billing.manage','Manage billing','Manage fee plans, charges and allocations.'),
  ('finance.payments.post','Post payments','Post official student payments.'),
  ('finance.payments.reverse','Reverse payments','Request/approve controlled payment corrections.'),
  ('finance.discounts.approve','Approve discounts','Approve controlled discounts/scholarships.'),
  ('finance.advances.manage','Manage advances','Manage staff/vendor advances and settlements.'),
  ('finance.advances.approve','Approve advances','Approve staff/vendor advances.'),
  ('staff.view','View staff','View Staff directory and workload.'),
  ('staff.manage','Manage staff','Manage Staff identities and assignments.'),
  ('staff.leave.manage','Manage leave','Create/manage leave and availability.'),
  ('staff.leave.approve','Approve leave','Approve staff leave.'),
  ('staff.compensation.view','View compensation','View compensation statements.'),
  ('staff.compensation.manage','Manage compensation','Manage compensation rules and settlements.'),
  ('staff.compensation.approve','Approve compensation','Approve compensation adjustments/settlements.'),
  ('assets.view','View assets','View assets and maintenance.'),
  ('assets.manage','Manage assets','Manage assets and lifecycle.'),
  ('procurement.view','View procurement','View vendors and procurement.'),
  ('procurement.manage','Manage procurement','Manage procurement workflows.'),
  ('procurement.approve','Approve procurement','Approve procurement workflows.'),
  ('accounting.view','View accounting','View accounting reports.'),
  ('accounting.manage','Manage accounting','Manage journals and financial accounts.'),
  ('analytics.view','View analytics','View management analytics.'),
  ('system.master_data.manage','Manage master data','Manage controlled master data.'),
  ('system.rules.view','View business rules','View versioned business rules.'),
  ('system.rules.manage','Manage business rules','Create/retire rule versions.'),
  ('system.users.manage','Manage user access','Manage user-role assignments.'),
  ('audit.view','View audit trail','View immutable audit history.'),
  ('approvals.view','View approvals','View approval requests.'),
  ('approvals.decide','Decide approvals','Approve/reject permitted workflows.');

-- ADMIN gets all permissions.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
cross join public.permissions p
where r.code='ADMIN';

-- Academic Director.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code = any(array[
  'dashboard.view','action_center.view','crm.prospects.view',
  'students.view','academics.view','academics.manage',
  'academics.curriculum.manage','academics.sessions.manage',
  'academics.attendance.record','academics.attendance.approve',
  'academics.assessments.record','academics.assessments.approve',
  'academics.coverage.manage','staff.view','staff.leave.manage',
  'staff.leave.approve','analytics.view','approvals.view',
  'approvals.decide','audit.view'
])
where r.code='ACADEMIC_DIRECTOR';

-- Operator.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code = any(array[
  'dashboard.view','action_center.view',
  'crm.prospects.view','crm.prospects.manage','crm.followups.manage',
  'admissions.view','admissions.create',
  'students.view','students.manage',
  'academics.view','academics.attendance.record',
  'finance.view','finance.payments.post',
  'staff.view'
])
where r.code='OPERATOR';

-- Teacher.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code = any(array[
  'dashboard.view','action_center.view','students.view',
  'academics.view','academics.attendance.record',
  'academics.assessments.record','staff.view',
  'staff.compensation.view'
])
where r.code='TEACHER';

-- Accountant.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code = any(array[
  'dashboard.view','action_center.view','finance.view',
  'finance.billing.manage','finance.payments.post',
  'finance.advances.manage','accounting.view','accounting.manage',
  'staff.view','staff.compensation.view','analytics.view'
])
where r.code='ACCOUNTANT';

insert into public.staff_roles(code,name,is_teaching_role)
values
  ('ADMINISTRATION','Administration',false),
  ('ACADEMIC_DIRECTOR','Academic Director',false),
  ('OPERATOR','Operator',false),
  ('TEACHER','Teacher',true),
  ('ACCOUNTING','Accounting',false),
  ('COUNSELLOR','Counsellor',false),
  ('SUPPORT','Support Staff',false);

insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
select id,'2026','2026-01-01','2026-12-31',true
from public.organizations where code='SOHOJ';

insert into public.classes(organization_id,code,name,sort_order)
select o.id,v.code,v.name,v.sort_order
from public.organizations o
cross join (values
  ('CLASS_8','Class 8',8),
  ('CLASS_9','Class 9',9),
  ('CLASS_10','Class 10',10)
) as v(code,name,sort_order)
where o.code='SOHOJ';

insert into public.programs(organization_id,code,name,description)
select o.id,v.code,v.name,v.description
from public.organizations o
cross join (values
  ('ANNUAL_EXAM_READINESS','Annual Exam Readiness','Structured exam-readiness and gap-recovery programme.'),
  ('SSC_A_PLUS','SSC A+ Preparation','Science-group SSC A+ preparation programme.')
) as v(code,name,description)
where o.code='SOHOJ';

insert into public.subjects(organization_id,code,name)
select o.id,v.code,v.name
from public.organizations o
cross join (values
  ('BANGLA','Bangla'),
  ('ENGLISH','English'),
  ('MATHEMATICS','Mathematics'),
  ('GENERAL_SCIENCE','General Science'),
  ('PHYSICS','Physics'),
  ('CHEMISTRY','Chemistry'),
  ('BIOLOGY','Biology'),
  ('ICT','ICT')
) as v(code,name)
where o.code='SOHOJ';

insert into public.lead_sources(organization_id,code,name)
select o.id,v.code,v.name
from public.organizations o
cross join (values
  ('WALK_IN','Walk-in'),
  ('SOCIAL','Social Media'),
  ('TEACHER_REFERRAL','Teacher Referral'),
  ('STUDENT_REFERRAL','Student Referral'),
  ('GUARDIAN_REFERRAL','Guardian Referral'),
  ('SCHOOL_VISIT','School Visit'),
  ('OFFLINE_CAMPAIGN','Offline Campaign'),
  ('OTHER','Other')
) as v(code,name)
where o.code='SOHOJ';

insert into public.guardian_relationships(organization_id,code,name)
select o.id,v.code,v.name
from public.organizations o
cross join (values
  ('FATHER','Father'),
  ('MOTHER','Mother'),
  ('BROTHER','Brother'),
  ('SISTER','Sister'),
  ('GRANDFATHER','Grandfather'),
  ('GRANDMOTHER','Grandmother'),
  ('UNCLE','Uncle'),
  ('AUNT','Aunt'),
  ('OTHER_GUARDIAN','Other Guardian')
) as v(code,name)
where o.code='SOHOJ';

insert into public.payment_methods(organization_id,code,name)
select o.id,v.code,v.name
from public.organizations o
cross join (values
  ('CASH','Cash'),
  ('BANK','Bank'),
  ('MOBILE_BANKING','Mobile Banking')
) as v(code,name)
where o.code='SOHOJ';

insert into public.business_rule_versions(
  domain,rule_key,version,status,effective_from,payload,change_reason
)
values
  (
    'academics',
    'batch_capacity_policy',
    1,
    'ACTIVE',
    '2026-01-01',
    '{"max_students":12}'::jsonb,
    'Initial Sohoj Academy batch-capacity policy.'
  ),
  (
    'teacher_compensation',
    'default_policy',
    1,
    'ACTIVE',
    '2026-01-01',
    '{
      "teaching_pool_percent":30,
      "teaching_pool_review_max_percent":40,
      "acquisition_bonus_percent":50,
      "retention_3_month_percent":15,
      "retention_6_month_percent":20
    }'::jsonb,
    'Initial management-approved teacher compensation policy.'
  );

-- ---------------------------------------------------------------------------
-- Row Level Security and API grants
-- ---------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.branches enable row level security;
alter table public.profiles enable row level security;
alter table public.system_roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_role_assignments enable row level security;
alter table public.staff enable row level security;
alter table public.staff_roles enable row level security;
alter table public.staff_role_assignments enable row level security;
alter table public.audit_events enable row level security;
alter table public.approval_requests enable row level security;
alter table public.business_rule_versions enable row level security;
alter table public.academic_years enable row level security;
alter table public.classes enable row level security;
alter table public.programs enable row level security;
alter table public.subjects enable row level security;
alter table public.areas enable row level security;
alter table public.schools enable row level security;
alter table public.lead_sources enable row level security;
alter table public.guardian_relationships enable row level security;
alter table public.payment_methods enable row level security;

grant usage on schema public to anon, authenticated;

grant select on public.classes,public.programs,public.subjects,public.schools,public.lead_sources to anon;
grant select on public.organizations,public.branches,public.academic_years,
  public.classes,public.programs,public.subjects,public.areas,public.schools,
  public.lead_sources,public.guardian_relationships,public.payment_methods,
  public.staff,public.staff_roles,public.staff_role_assignments,
  public.business_rule_versions,public.approval_requests,public.audit_events,
  public.profiles to authenticated;

grant select,insert,update on public.user_role_assignments to authenticated;
grant select,insert,update on public.staff to authenticated;
grant select,insert,update on public.staff_role_assignments to authenticated;
grant select,insert,update on public.approval_requests to authenticated;
grant select,insert,update on public.business_rule_versions to authenticated;
grant select,insert,update on public.academic_years,public.classes,public.programs,
  public.subjects,public.areas,public.schools,public.lead_sources,
  public.guardian_relationships,public.payment_methods to authenticated;

grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.my_erp_context() to authenticated;

create policy organizations_authenticated_read
on public.organizations for select to authenticated
using (true);

create policy branches_authenticated_read
on public.branches for select to authenticated
using (true);

create policy profiles_read
on public.profiles for select to authenticated
using (
  id = auth.uid()
  or public.has_permission('system.users.manage')
  or public.has_permission('staff.view')
);

create policy user_roles_admin_read
on public.user_role_assignments for select to authenticated
using (
  profile_id = auth.uid()
  or public.has_permission('system.users.manage')
);

create policy user_roles_admin_write
on public.user_role_assignments for insert to authenticated
with check (public.has_permission('system.users.manage'));

create policy user_roles_admin_update
on public.user_role_assignments for update to authenticated
using (public.has_permission('system.users.manage'))
with check (public.has_permission('system.users.manage'));

create policy staff_permission_read
on public.staff for select to authenticated
using (public.has_permission('staff.view') or profile_id = auth.uid());

create policy staff_permission_insert
on public.staff for insert to authenticated
with check (public.has_permission('staff.manage'));

create policy staff_permission_update
on public.staff for update to authenticated
using (public.has_permission('staff.manage'))
with check (public.has_permission('staff.manage'));

create policy staff_roles_authenticated_read
on public.staff_roles for select to authenticated
using (true);

create policy staff_role_assignments_read
on public.staff_role_assignments for select to authenticated
using (public.has_permission('staff.view'));

create policy staff_role_assignments_insert
on public.staff_role_assignments for insert to authenticated
with check (public.has_permission('staff.manage'));

create policy staff_role_assignments_update
on public.staff_role_assignments for update to authenticated
using (public.has_permission('staff.manage'))
with check (public.has_permission('staff.manage'));

create policy audit_permission_read
on public.audit_events for select to authenticated
using (public.has_permission('audit.view'));

create policy approvals_permission_read
on public.approval_requests for select to authenticated
using (
  public.has_permission('approvals.view')
  or requested_by = auth.uid()
);

create policy approvals_submit
on public.approval_requests for insert to authenticated
with check (requested_by = auth.uid());

create policy approvals_decide
on public.approval_requests for update to authenticated
using (public.has_permission('approvals.decide'))
with check (public.has_permission('approvals.decide'));

create policy business_rules_read
on public.business_rule_versions for select to authenticated
using (public.has_permission('system.rules.view') or status='ACTIVE');

create policy business_rules_insert
on public.business_rule_versions for insert to authenticated
with check (public.has_permission('system.rules.manage'));

create policy business_rules_update
on public.business_rule_versions for update to authenticated
using (public.has_permission('system.rules.manage'))
with check (public.has_permission('system.rules.manage'));

create policy academic_years_read
on public.academic_years for select to authenticated
using (true);

create policy classes_public_read
on public.classes for select to anon,authenticated
using (is_active);

create policy programs_public_read
on public.programs for select to anon,authenticated
using (is_active);

create policy subjects_public_read
on public.subjects for select to anon,authenticated
using (is_active);

create policy schools_public_read
on public.schools for select to anon,authenticated
using (is_active);

create policy lead_sources_public_read
on public.lead_sources for select to anon,authenticated
using (is_active);

create policy areas_authenticated_read
on public.areas for select to authenticated
using (is_active);

create policy guardian_relationships_authenticated_read
on public.guardian_relationships for select to authenticated
using (is_active);

create policy payment_methods_authenticated_read
on public.payment_methods for select to authenticated
using (is_active);

create policy master_data_manage_academic_years
on public.academic_years for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_classes
on public.classes for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_programs
on public.programs for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_subjects
on public.subjects for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_areas
on public.areas for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_schools
on public.schools for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_lead_sources
on public.lead_sources for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_guardian_relationships
on public.guardian_relationships for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create policy master_data_manage_payment_methods
on public.payment_methods for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

-- No destructive operational deletion through API roles.
revoke delete on all tables in schema public from anon, authenticated;



-- ============================================================
-- SOURCE: 0002_v2_crm_student_core.sql
-- ============================================================

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
  capacity integer not null,
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
  select (payload->>'max_students')::integer
    into v_max
  from public.business_rule_versions
  where domain='academics'
    and rule_key='batch_capacity_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if v_max is null or v_max < 1 then
    raise exception 'Active batch capacity policy is missing or invalid.';
  end if;

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
    raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
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
      and (
        upper(code)=upper(replace(v_relationship_text,' ','_'))
        or lower(name)=lower(v_relationship_text)
      )
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



-- ============================================================
-- SOURCE: 0003_v2_staff_workflow.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Staff creation workflow and teaching qualification assignments.

create table public.staff_subject_assignments (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  subject_id uuid not null references public.subjects(id),
  effective_from date not null default current_date,
  effective_to date,
  is_primary boolean not null default false,
  assigned_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index staff_subject_open_assignment_uniq
on public.staff_subject_assignments(staff_id,subject_id)
where effective_to is null;

create or replace function public.enforce_staff_subject_teaching_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.staff_role_assignments sra
    join public.staff_roles sr on sr.id=sra.staff_role_id
    where sra.staff_id=new.staff_id
      and sr.is_teaching_role
      and sra.effective_from<=current_date
      and (sra.effective_to is null or sra.effective_to>=current_date)
  ) then
    raise exception 'Teaching subjects can only be assigned to staff with an active teaching role.';
  end if;

  return new;
end;
$$;

create trigger staff_subject_requires_teaching_role
before insert or update of staff_id,subject_id,effective_to
on public.staff_subject_assignments
for each row execute function public.enforce_staff_subject_teaching_role();

create or replace function public.create_staff_member(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_staff public.staff;
  v_role public.staff_roles;
  v_branch public.branches;
  v_subject_id uuid;
  v_subjects jsonb;
  v_mobile text;
  v_joined_on date;
  v_correlation_id uuid := gen_random_uuid();
  v_actor_role text;
begin
  if v_actor is null or not public.has_permission('staff.manage') then
    raise exception 'You are not authorized to create Staff identities.';
  end if;

  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Staff request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_input->>'full_name','')), '') is null then
    raise exception 'Full name is required.';
  end if;

  select * into v_role
  from public.staff_roles
  where code=upper(btrim(coalesce(p_input->>'staff_role_code','')))
    and is_active;

  if v_role.id is null then
    raise exception 'Select a valid Staff role.';
  end if;

  if nullif(p_input->>'branch_id','') is not null then
    begin
      select * into v_branch
      from public.branches
      where id=(p_input->>'branch_id')::uuid
        and is_active;
    exception when others then
      raise exception 'Selected branch is invalid.';
    end;
  else
    select * into v_branch
    from public.branches
    where code='MAIN' and is_active
    order by created_at asc
    limit 1;
  end if;

  if v_branch.id is null then
    raise exception 'An active branch is required.';
  end if;

  begin
    v_joined_on := coalesce(
      nullif(p_input->>'joined_on','')::date,
      current_date
    );
  exception when others then
    raise exception 'Joining date is invalid.';
  end;

  v_mobile := nullif(btrim(coalesce(p_input->>'mobile','')), '');

  if v_mobile is not null and exists (
    select 1
    from public.staff s
    where regexp_replace(coalesce(s.mobile,''), '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and s.status in ('ACTIVE','ON_LEAVE')
  ) then
    raise exception 'Another active Staff identity already uses this mobile number.';
  end if;

  insert into public.staff(
    branch_id,
    full_name,
    mobile,
    alternate_mobile,
    email,
    address,
    emergency_contact_name,
    emergency_contact_mobile,
    joined_on,
    status,
    notes,
    created_by
  )
  values(
    v_branch.id,
    btrim(p_input->>'full_name'),
    v_mobile,
    nullif(btrim(coalesce(p_input->>'alternate_mobile','')), ''),
    nullif(lower(btrim(coalesce(p_input->>'email',''))), ''),
    nullif(btrim(coalesce(p_input->>'address','')), ''),
    nullif(btrim(coalesce(p_input->>'emergency_contact_name','')), ''),
    nullif(btrim(coalesce(p_input->>'emergency_contact_mobile','')), ''),
    v_joined_on,
    'ACTIVE',
    nullif(btrim(coalesce(p_input->>'notes','')), ''),
    v_actor
  )
  returning * into v_staff;

  insert into public.staff_role_assignments(
    staff_id,
    staff_role_id,
    branch_id,
    effective_from,
    is_primary,
    assigned_by
  )
  values(
    v_staff.id,
    v_role.id,
    v_branch.id,
    v_joined_on,
    true,
    v_actor
  );

  v_subjects := coalesce(p_input->'subject_ids','[]'::jsonb);

  if jsonb_typeof(v_subjects) <> 'array' then
    raise exception 'Teaching subject selection must be an array.';
  end if;

  if not v_role.is_teaching_role
     and jsonb_array_length(v_subjects) > 0 then
    raise exception 'Teaching subjects can only be selected for a teaching Staff role.';
  end if;

  for v_subject_id in
    select value::text::uuid
    from jsonb_array_elements_text(v_subjects)
  loop
    if not exists (
      select 1 from public.subjects
      where id=v_subject_id and is_active
    ) then
      raise exception 'One selected subject is not available.';
    end if;

    insert into public.staff_subject_assignments(
      staff_id,
      subject_id,
      effective_from,
      assigned_by
    )
    values(
      v_staff.id,
      v_subject_id,
      v_joined_on,
      v_actor
    );
  end loop;

  select sr.code into v_actor_role
  from public.user_role_assignments ura
  join public.system_roles sr on sr.id=ura.role_id
  where ura.profile_id=v_actor
    and ura.is_active
    and ura.effective_from<=current_date
    and (ura.effective_to is null or ura.effective_to>=current_date)
  order by case when sr.code='ADMIN' then 0 else 1 end, sr.code
  limit 1;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    actor_role_code,
    branch_id,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    v_actor_role,
    v_branch.id,
    'STAFF',
    v_staff.id::text,
    'CREATE',
    jsonb_build_object(
      'staff_no',v_staff.staff_no,
      'full_name',v_staff.full_name,
      'staff_role_code',v_role.code,
      'joined_on',v_staff.joined_on,
      'status',v_staff.status
    ),
    jsonb_build_object(
      'workflow','CREATE_STAFF_MEMBER',
      'subject_count',jsonb_array_length(v_subjects)
    )
  );

  return jsonb_build_object(
    'staff_id',v_staff.id,
    'staff_no',v_staff.staff_no,
    'correlation_id',v_correlation_id
  );
end;
$$;

alter table public.staff_subject_assignments enable row level security;

grant select,insert,update on public.staff_subject_assignments to authenticated;
grant execute on function public.create_staff_member(jsonb) to authenticated;

create policy staff_subjects_read
on public.staff_subject_assignments for select to authenticated
using (public.has_permission('staff.view'));

create policy staff_subjects_manage_insert
on public.staff_subject_assignments for insert to authenticated
with check (public.has_permission('staff.manage'));

create policy staff_subjects_manage_update
on public.staff_subject_assignments for update to authenticated
using (public.has_permission('staff.manage'))
with check (public.has_permission('staff.manage'));

revoke delete on public.staff_subject_assignments from authenticated;



-- ============================================================
-- SOURCE: 0004_v2_crm_followup.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Prospect follow-up workflow and controlled CRM status transitions.

alter table public.prospect_followups
  add constraint prospect_followup_type_check
  check (
    followup_type in (
      'CALL',
      'WHATSAPP',
      'IN_PERSON',
      'COUNSELLING',
      'TRIAL',
      'OTHER'
    )
  ) not valid;

alter table public.prospect_followups
  validate constraint prospect_followup_type_check;

create or replace function public.is_valid_prospect_transition(
  p_from public.prospect_status,
  p_to public.prospect_status
)
returns boolean
language sql
immutable
as $$
  select
    p_from = p_to
    or (p_from='NEW' and p_to in ('CONTACTED','COUNSELLING','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='CONTACTED' and p_to in ('COUNSELLING','TRIAL_SCHEDULED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='COUNSELLING' and p_to in ('TRIAL_SCHEDULED','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_SCHEDULED' and p_to in ('TRIAL_ATTENDED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_ATTENDED' and p_to in ('COUNSELLING','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='REGISTERED' and p_to='LOST')
    or (p_from='FUTURE_FOLLOW_UP' and p_to in ('CONTACTED','COUNSELLING','TRIAL_SCHEDULED','LOST'))
    or (p_from='LOST' and p_to='FUTURE_FOLLOW_UP');
$$;

create or replace function public.record_prospect_followup(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_prospect public.prospects;
  v_followup public.prospect_followups;
  v_followup_type text;
  v_new_status public.prospect_status;
  v_next_follow_up_at timestamptz;
  v_notes text;
  v_outcome text;
  v_lost_reason text;
  v_correlation_id uuid := gen_random_uuid();
  v_actor_role text;
  v_before jsonb;
begin
  if v_actor is null or not public.has_permission('crm.followups.manage') then
    raise exception 'You are not authorized to record CRM follow-ups.';
  end if;

  begin
    select * into v_prospect
    from public.prospects
    where id=(p_input->>'prospect_id')::uuid
    for update;
  exception when others then
    raise exception 'Prospect identity is invalid.';
  end;

  if v_prospect.id is null then
    raise exception 'Prospect was not found.';
  end if;

  if v_prospect.status='CONVERTED' then
    raise exception 'Converted prospects are read-only in CRM. Continue from the Student record.';
  end if;

  v_followup_type := upper(btrim(coalesce(p_input->>'followup_type','')));
  if v_followup_type not in ('CALL','WHATSAPP','IN_PERSON','COUNSELLING','TRIAL','OTHER') then
    raise exception 'Select a valid follow-up type.';
  end if;

  v_notes := nullif(btrim(coalesce(p_input->>'notes','')), '');
  if v_notes is null then
    raise exception 'Follow-up notes are required.';
  end if;

  v_outcome := nullif(btrim(coalesce(p_input->>'outcome','')), '');
  v_lost_reason := nullif(btrim(coalesce(p_input->>'lost_reason','')), '');

  begin
    v_new_status := coalesce(
      nullif(p_input->>'new_status','')::public.prospect_status,
      v_prospect.status
    );
    v_next_follow_up_at := nullif(p_input->>'next_follow_up_at','')::timestamptz;
  exception when others then
    raise exception 'Follow-up status or next follow-up date is invalid.';
  end;

  if not public.is_valid_prospect_transition(v_prospect.status,v_new_status) then
    raise exception 'Prospect status cannot move from % to % through a follow-up.', v_prospect.status, v_new_status;
  end if;

  if v_new_status='LOST' and v_lost_reason is null then
    raise exception 'Lost reason is required when a prospect is marked LOST.';
  end if;

  if v_new_status='FUTURE_FOLLOW_UP' and v_next_follow_up_at is null then
    raise exception 'Next follow-up date is required for FUTURE FOLLOW UP.';
  end if;

  v_before := to_jsonb(v_prospect);

  insert into public.prospect_followups(
    prospect_id,
    followup_type,
    occurred_at,
    outcome,
    notes,
    next_follow_up_at,
    recorded_by
  )
  values(
    v_prospect.id,
    v_followup_type,
    now(),
    v_outcome,
    v_notes,
    v_next_follow_up_at,
    v_actor
  )
  returning * into v_followup;

  update public.prospects
  set
    status=v_new_status,
    next_follow_up_at=v_next_follow_up_at,
    lost_reason=case
      when v_new_status='LOST' then v_lost_reason
      when v_prospect.status='LOST' and v_new_status<>'LOST' then null
      else lost_reason
    end,
    updated_at=now()
  where id=v_prospect.id
  returning * into v_prospect;

  select sr.code into v_actor_role
  from public.user_role_assignments ura
  join public.system_roles sr on sr.id=ura.role_id
  where ura.profile_id=v_actor
    and ura.is_active
    and ura.effective_from<=current_date
    and (ura.effective_to is null or ura.effective_to>=current_date)
  order by case when sr.code='ADMIN' then 0 else 1 end, sr.code
  limit 1;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    actor_role_code,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    v_actor_role,
    v_prospect.branch_id,
    'PROSPECT',
    v_prospect.id::text,
    'RECORD_FOLLOW_UP',
    v_notes,
    v_before,
    to_jsonb(v_prospect),
    jsonb_build_object(
      'workflow','PROSPECT_FOLLOW_UP',
      'followup_id',v_followup.id,
      'followup_type',v_followup.followup_type,
      'outcome',v_followup.outcome
    )
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no,
    'followup_id',v_followup.id,
    'status',v_prospect.status,
    'correlation_id',v_correlation_id
  );
end;
$$;

revoke all on function public.record_prospect_followup(jsonb) from public;
grant execute on function public.record_prospect_followup(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0005_v2_configuration.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Configuration control center, editable role permissions and versioned policy publishing.

create table public.setting_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  group_code text not null,
  name text not null,
  description text,
  value_type text not null check (value_type in ('BOOLEAN','INTEGER','NUMERIC','TEXT','JSON')),
  default_value jsonb,
  validation_contract jsonb not null default '{}'::jsonb,
  is_sensitive boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.setting_versions (
  id uuid primary key default gen_random_uuid(),
  setting_definition_id uuid not null references public.setting_definitions(id),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid references public.branches(id),
  version integer not null,
  status public.rule_status not null default 'ACTIVE',
  effective_from date not null default current_date,
  effective_to date,
  value jsonb not null,
  change_reason text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  unique (setting_definition_id, organization_id, branch_id, version)
);

create unique index one_active_setting_per_scope
on public.setting_versions(
  setting_definition_id,
  organization_id,
  coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid)
)
where status='ACTIVE';

insert into public.permissions(code,name,description)
values
  ('system.settings.view','View settings','View configuration and active policy values.'),
  ('system.settings.manage','Manage settings','Publish versioned configuration changes.'),
  ('system.roles.manage','Manage roles and permissions','Create/maintain role permission bundles.')
on conflict (code) do nothing;

-- Bootstrap ADMIN remains the protected recovery authority and automatically
-- receives permissions introduced by later migrations.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
cross join public.permissions p
where r.code='ADMIN'
on conflict do nothing;

-- Initial admission policy. This is a default version, not hard-coded behavior.
insert into public.business_rule_versions(
  domain,
  rule_key,
  version,
  status,
  effective_from,
  payload,
  change_reason
)
select
  'admissions',
  'activation_policy',
  1,
  'ACTIVE',
  current_date,
  '{
    "requires_admission_acceptance": true,
    "requires_initial_billing_posted": true,
    "payment_requirement": "NONE",
    "minimum_payment_percent": 0,
    "allow_credit_enrollment": true,
    "count_student_active_only_when_enrollment_active": true
  }'::jsonb,
  'Initial configurable admission activation policy.'
where not exists (
  select 1
  from public.business_rule_versions
  where domain='admissions'
    and rule_key='activation_policy'
);

create or replace function public.validate_setting_value(
  p_value_type text,
  p_value jsonb
)
returns boolean
language plpgsql
immutable
as $$
begin
  return case p_value_type
    when 'BOOLEAN' then jsonb_typeof(p_value)='boolean'
    when 'INTEGER' then jsonb_typeof(p_value)='number'
      and (p_value::text)::numeric = trunc((p_value::text)::numeric)
    when 'NUMERIC' then jsonb_typeof(p_value)='number'
    when 'TEXT' then jsonb_typeof(p_value)='string'
    when 'JSON' then p_value is not null
    else false
  end;
exception when others then
  return false;
end;
$$;

create or replace function public.publish_setting_value(
  p_setting_code text,
  p_value jsonb,
  p_reason text,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_org public.organizations;
  v_definition public.setting_definitions;
  v_previous public.setting_versions;
  v_new public.setting_versions;
  v_version integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.settings.manage') then
    raise exception 'You are not authorized to manage settings.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  select * into v_definition
  from public.setting_definitions
  where code=p_setting_code and is_active;

  if v_definition.id is null then
    raise exception 'Setting definition % was not found.', p_setting_code;
  end if;

  if not public.validate_setting_value(v_definition.value_type,p_value) then
    raise exception 'Setting value does not match the required type %.', v_definition.value_type;
  end if;

  if p_branch_id is not null and not exists (
    select 1
    from public.branches b
    where b.id=p_branch_id
      and b.organization_id=v_org.id
      and b.is_active
  ) then
    raise exception 'Selected branch is not available.';
  end if;

  select * into v_previous
  from public.setting_versions
  where setting_definition_id=v_definition.id
    and organization_id=v_org.id
    and branch_id is not distinct from p_branch_id
    and status='ACTIVE'
  for update;

  select coalesce(max(version),0)+1 into v_version
  from public.setting_versions
  where setting_definition_id=v_definition.id
    and organization_id=v_org.id
    and branch_id is not distinct from p_branch_id;

  if v_previous.id is not null then
    update public.setting_versions
    set
      status='RETIRED',
      effective_to=current_date
    where id=v_previous.id;
  end if;

  insert into public.setting_versions(
    setting_definition_id,
    organization_id,
    branch_id,
    version,
    status,
    effective_from,
    value,
    change_reason,
    created_by
  )
  values(
    v_definition.id,
    v_org.id,
    p_branch_id,
    v_version,
    'ACTIVE',
    current_date,
    p_value,
    btrim(p_reason),
    v_actor
  )
  returning * into v_new;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'SETTING',
    v_definition.code,
    'PUBLISH_VERSION',
    btrim(p_reason),
    case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_new),
    jsonb_build_object(
      'setting_code',v_definition.code,
      'branch_id',p_branch_id,
      'version',v_new.version
    )
  );

  return jsonb_build_object(
    'setting_code',v_definition.code,
    'version',v_new.version,
    'value',v_new.value,
    'correlation_id',v_correlation_id
  );
end;
$$;

create or replace function public.publish_business_rule_version(
  p_domain text,
  p_rule_key text,
  p_payload jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_previous public.business_rule_versions;
  v_new public.business_rule_versions;
  v_version integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.settings.manage') then
    raise exception 'You are not authorized to manage business policies.';
  end if;

  if nullif(btrim(coalesce(p_domain,'')), '') is null
     or nullif(btrim(coalesce(p_rule_key,'')), '') is null then
    raise exception 'Policy domain and rule key are required.';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Policy payload must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_previous
  from public.business_rule_versions
  where domain=p_domain
    and rule_key=p_rule_key
    and status='ACTIVE'
  for update;

  select coalesce(max(version),0)+1 into v_version
  from public.business_rule_versions
  where domain=p_domain and rule_key=p_rule_key;

  if v_previous.id is not null then
    update public.business_rule_versions
    set
      status='RETIRED',
      effective_to=current_date
    where id=v_previous.id;
  end if;

  insert into public.business_rule_versions(
    domain,
    rule_key,
    version,
    status,
    effective_from,
    payload,
    change_reason,
    created_by
  )
  values(
    p_domain,
    p_rule_key,
    v_version,
    'ACTIVE',
    current_date,
    p_payload,
    btrim(p_reason),
    v_actor
  )
  returning * into v_new;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'BUSINESS_RULE',
    p_domain || '.' || p_rule_key,
    'PUBLISH_VERSION',
    btrim(p_reason),
    case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_new),
    jsonb_build_object('version',v_new.version)
  );

  return jsonb_build_object(
    'domain',v_new.domain,
    'rule_key',v_new.rule_key,
    'version',v_new.version,
    'payload',v_new.payload,
    'correlation_id',v_correlation_id
  );
end;
$$;

create or replace function public.set_role_permissions(
  p_role_code text,
  p_permission_codes text[],
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.system_roles;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.roles.manage') then
    raise exception 'You are not authorized to manage role permissions.';
  end if;

  select * into v_role
  from public.system_roles
  where code=upper(btrim(p_role_code))
    and is_active
  for update;

  if v_role.id is null then
    raise exception 'Role was not found.';
  end if;

  if v_role.code='ADMIN' then
    raise exception 'The bootstrap ADMIN role is protected. Create or edit operational roles instead.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  if exists (
    select unnest(coalesce(p_permission_codes,'{}'::text[]))
    except
    select code from public.permissions
  ) then
    raise exception 'One or more permission codes are invalid.';
  end if;

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_before
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  delete from public.role_permissions where role_id=v_role.id;

  insert into public.role_permissions(role_id,permission_id)
  select v_role.id,p.id
  from public.permissions p
  where p.code=any(coalesce(p_permission_codes,'{}'::text[]));

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_after
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'SYSTEM_ROLE',
    v_role.id::text,
    'SET_PERMISSIONS',
    btrim(p_reason),
    jsonb_build_object('permissions',v_before),
    jsonb_build_object('permissions',v_after)
  );

  return jsonb_build_object(
    'role_code',v_role.code,
    'permissions',v_after,
    'correlation_id',v_correlation_id
  );
end;
$$;

alter table public.setting_definitions enable row level security;
alter table public.setting_versions enable row level security;

grant select on public.system_roles,public.permissions,public.role_permissions,
  public.setting_definitions,public.setting_versions to authenticated;

grant execute on function public.publish_setting_value(text,jsonb,text,uuid) to authenticated;
grant execute on function public.publish_business_rule_version(text,text,jsonb,text) to authenticated;
grant execute on function public.set_role_permissions(text,text[],text) to authenticated;

revoke insert,update,delete on public.role_permissions from authenticated;
revoke insert,update,delete on public.business_rule_versions from authenticated;
revoke insert,update,delete on public.setting_versions from authenticated;

create policy system_roles_read
on public.system_roles for select to authenticated
using (true);

create policy permissions_read
on public.permissions for select to authenticated
using (true);

create policy role_permissions_read
on public.role_permissions for select to authenticated
using (
  public.has_permission('system.roles.manage')
  or public.has_permission('system.users.manage')
);

create policy setting_definitions_read
on public.setting_definitions for select to authenticated
using (
  public.has_permission('system.settings.view')
  or public.has_permission('system.settings.manage')
);

create policy setting_versions_read
on public.setting_versions for select to authenticated
using (
  public.has_permission('system.settings.view')
  or public.has_permission('system.settings.manage')
);

-- Business rules are published only through the audited RPC from this point on.
drop policy if exists business_rules_insert on public.business_rule_versions;
drop policy if exists business_rules_update on public.business_rule_versions;



-- ============================================================
-- SOURCE: 0006_v2_control_center_editing.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Harden editable Control Center policies with database payload validation.

create or replace function public.validate_business_rule_payload(
  p_domain text,
  p_rule_key text,
  p_payload jsonb
)
returns boolean
language plpgsql
immutable
as $$
declare
  v_pool numeric;
  v_pool_max numeric;
  v_acquisition numeric;
  v_retention_3 numeric;
  v_retention_6 numeric;
  v_capacity numeric;
  v_payment_requirement text;
  v_minimum_payment numeric;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return false;
  end if;

  if p_domain='academics' and p_rule_key='batch_capacity_policy' then
    if jsonb_typeof(p_payload->'max_students') <> 'number' then
      return false;
    end if;

    v_capacity := (p_payload->>'max_students')::numeric;

    return v_capacity = trunc(v_capacity)
      and v_capacity between 1 and 500;
  end if;

  if p_domain='teacher_compensation' and p_rule_key='default_policy' then
    if jsonb_typeof(p_payload->'teaching_pool_percent') <> 'number'
       or jsonb_typeof(p_payload->'teaching_pool_review_max_percent') <> 'number'
       or jsonb_typeof(p_payload->'acquisition_bonus_percent') <> 'number'
       or jsonb_typeof(p_payload->'retention_3_month_percent') <> 'number'
       or jsonb_typeof(p_payload->'retention_6_month_percent') <> 'number' then
      return false;
    end if;

    v_pool := (p_payload->>'teaching_pool_percent')::numeric;
    v_pool_max := (p_payload->>'teaching_pool_review_max_percent')::numeric;
    v_acquisition := (p_payload->>'acquisition_bonus_percent')::numeric;
    v_retention_3 := (p_payload->>'retention_3_month_percent')::numeric;
    v_retention_6 := (p_payload->>'retention_6_month_percent')::numeric;

    return v_pool between 0 and 100
      and v_pool_max between 0 and 100
      and v_pool <= v_pool_max
      and v_acquisition between 0 and 100
      and v_retention_3 between 0 and 100
      and v_retention_6 between 0 and 100;
  end if;

  if p_domain='admissions' and p_rule_key='activation_policy' then
    if jsonb_typeof(p_payload->'requires_admission_acceptance') <> 'boolean'
       or jsonb_typeof(p_payload->'requires_initial_billing_posted') <> 'boolean'
       or jsonb_typeof(p_payload->'allow_credit_enrollment') <> 'boolean'
       or jsonb_typeof(p_payload->'count_student_active_only_when_enrollment_active') <> 'boolean'
       or jsonb_typeof(p_payload->'minimum_payment_percent') <> 'number'
       or jsonb_typeof(p_payload->'payment_requirement') <> 'string' then
      return false;
    end if;

    v_payment_requirement := p_payload->>'payment_requirement';
    v_minimum_payment := (p_payload->>'minimum_payment_percent')::numeric;

    if v_payment_requirement not in ('NONE','MINIMUM_PERCENT','FULL') then
      return false;
    end if;

    if v_minimum_payment < 0 or v_minimum_payment > 100 then
      return false;
    end if;

    if v_payment_requirement='NONE' and v_minimum_payment <> 0 then
      return false;
    end if;

    if v_payment_requirement='MINIMUM_PERCENT'
       and (v_minimum_payment <= 0 or v_minimum_payment >= 100) then
      return false;
    end if;

    if v_payment_requirement='FULL' and v_minimum_payment <> 100 then
      return false;
    end if;

    return true;
  end if;

  -- Unknown rules are intentionally not editable through the generic
  -- Control Center publisher until a database validation contract is added.
  return false;
exception when others then
  return false;
end;
$$;

create or replace function public.publish_business_rule_version(
  p_domain text,
  p_rule_key text,
  p_payload jsonb,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_previous public.business_rule_versions;
  v_new public.business_rule_versions;
  v_version integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.settings.manage') then
    raise exception 'You are not authorized to manage business policies.';
  end if;

  if nullif(btrim(coalesce(p_domain,'')), '') is null
     or nullif(btrim(coalesce(p_rule_key,'')), '') is null then
    raise exception 'Policy domain and rule key are required.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  if not public.validate_business_rule_payload(p_domain,p_rule_key,p_payload) then
    raise exception 'Policy payload failed the database validation contract.';
  end if;

  select * into v_previous
  from public.business_rule_versions
  where domain=p_domain
    and rule_key=p_rule_key
    and status='ACTIVE'
  for update;

  if v_previous.id is null then
    raise exception 'Active policy %.% was not found.', p_domain, p_rule_key;
  end if;

  if v_previous.payload = p_payload then
    raise exception 'The proposed policy is identical to the active version.';
  end if;

  select coalesce(max(version),0)+1 into v_version
  from public.business_rule_versions
  where domain=p_domain and rule_key=p_rule_key;

  update public.business_rule_versions
  set
    status='RETIRED',
    effective_to=current_date
  where id=v_previous.id;

  insert into public.business_rule_versions(
    domain,
    rule_key,
    version,
    status,
    effective_from,
    payload,
    change_reason,
    created_by
  )
  values(
    p_domain,
    p_rule_key,
    v_version,
    'ACTIVE',
    current_date,
    p_payload,
    btrim(p_reason),
    v_actor
  )
  returning * into v_new;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'BUSINESS_RULE',
    p_domain || '.' || p_rule_key,
    'PUBLISH_VERSION',
    btrim(p_reason),
    to_jsonb(v_previous),
    to_jsonb(v_new),
    jsonb_build_object(
      'previous_version',v_previous.version,
      'new_version',v_new.version
    )
  );

  return jsonb_build_object(
    'domain',v_new.domain,
    'rule_key',v_new.rule_key,
    'version',v_new.version,
    'payload',v_new.payload,
    'correlation_id',v_correlation_id
  );
end;
$$;

grant execute on function public.validate_business_rule_payload(text,text,jsonb) to authenticated;
grant execute on function public.publish_business_rule_version(text,text,jsonb,text) to authenticated;



-- ============================================================
-- SOURCE: 0007_v2_user_access_control.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Controlled user-to-operational-role assignment workflow.

create or replace function public.set_user_operational_roles(
  p_profile_id uuid,
  p_role_codes text[],
  p_reason text,
  p_branch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.profiles;
  v_branch public.branches;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.users.manage') then
    raise exception 'You are not authorized to manage user access.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_profile
  from public.profiles
  where id=p_profile_id
    and status='ACTIVE'
  for update;

  if v_profile.id is null then
    raise exception 'Active user profile was not found.';
  end if;

  if p_branch_id is not null then
    select * into v_branch
    from public.branches
    where id=p_branch_id and is_active;

    if v_branch.id is null then
      raise exception 'Selected branch is not available.';
    end if;
  end if;

  if 'ADMIN'=any(coalesce(p_role_codes,'{}'::text[])) then
    raise exception 'ADMIN assignment is protected and cannot be changed through the operational access editor.';
  end if;

  if exists (
    select unnest(coalesce(p_role_codes,'{}'::text[]))
    except
    select code
    from public.system_roles
    where code<>'ADMIN' and is_active
  ) then
    raise exception 'One or more operational role codes are invalid.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_before
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  update public.user_role_assignments ura
  set
    is_active=false,
    effective_to=current_date
  from public.system_roles r
  where ura.role_id=r.id
    and ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id
    and not (r.code=any(coalesce(p_role_codes,'{}'::text[])));

  insert into public.user_role_assignments(
    profile_id,
    role_id,
    branch_id,
    effective_from,
    is_active,
    assigned_by
  )
  select
    p_profile_id,
    r.id,
    p_branch_id,
    current_date,
    true,
    v_actor
  from public.system_roles r
  where r.code=any(coalesce(p_role_codes,'{}'::text[]))
    and r.code<>'ADMIN'
    and r.is_active
    and not exists (
      select 1
      from public.user_role_assignments existing
      where existing.profile_id=p_profile_id
        and existing.role_id=r.id
        and existing.branch_id is not distinct from p_branch_id
        and existing.is_active
        and existing.effective_to is null
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_after
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  if v_before=v_after then
    raise exception 'The proposed access assignment is identical to the current assignment.';
  end if;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    p_branch_id,
    'USER_ACCESS',
    p_profile_id::text,
    'SET_OPERATIONAL_ROLES',
    btrim(p_reason),
    jsonb_build_object('roles',v_before),
    jsonb_build_object('roles',v_after),
    jsonb_build_object('scope_branch_id',p_branch_id)
  );

  return jsonb_build_object(
    'profile_id',p_profile_id,
    'branch_id',p_branch_id,
    'roles',v_after,
    'correlation_id',v_correlation_id
  );
end;
$$;

grant execute on function public.set_user_operational_roles(uuid,text[],text,uuid) to authenticated;

-- Access assignments are mutated only through controlled workflows.
revoke insert,update,delete on public.user_role_assignments from authenticated;



-- ============================================================
-- SOURCE: 0008_v2_programme_offerings_fee_plans.sql
-- ============================================================

-- Programme Offering and versioned standard Fee Plan foundation.
-- Admission will reference a published fee_plan_version_id, never copy mutable defaults.

create type public.offering_status as enum ('DRAFT','ACTIVE','RETIRED');

create table public.academic_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  unique (organization_id, code)
);

insert into public.academic_groups(organization_id,code,name)
select id,'SCIENCE','Science' from public.organizations where code='SOHOJ';

create table public.programme_offerings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  branch_id uuid not null references public.branches(id),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  program_id uuid not null references public.programs(id),
  group_id uuid references public.academic_groups(id),
  code text not null,
  name text not null,
  status public.offering_status not null default 'DRAFT',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, academic_year_id, code),
  check (length(btrim(code)) between 2 and 40),
  check (length(btrim(name)) between 2 and 160)
);

create unique index programme_offering_context_uniq
on public.programme_offerings(academic_year_id, branch_id, class_id, program_id,
  coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid));

create trigger programme_offerings_set_updated_at
before update on public.programme_offerings
for each row execute function public.set_updated_at();

create table public.fee_plan_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.programme_offerings(id),
  version integer not null check (version > 0),
  status public.rule_status not null default 'DRAFT',
  billing_cycle text not null check (billing_cycle in ('ONE_TIME','MONTHLY','TERM')),
  due_day integer check (due_day between 1 and 28),
  currency_code text not null default 'BDT' check (currency_code ~ '^[A-Z]{3}$'),
  effective_from date not null,
  effective_to date,
  change_reason text not null check (length(btrim(change_reason)) >= 5),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (offering_id, version),
  check (effective_to is null or effective_to >= effective_from),
  check ((billing_cycle = 'MONTHLY' and due_day is not null)
    or (billing_cycle <> 'MONTHLY' and due_day is null))
);

create unique index fee_plan_one_active_per_offering
on public.fee_plan_versions(offering_id) where status='ACTIVE';

create table public.fee_plan_components (
  id uuid primary key default gen_random_uuid(),
  fee_plan_version_id uuid not null references public.fee_plan_versions(id),
  code text not null check (code ~ '^[A-Z][A-Z0-9_]{1,39}$'),
  name text not null check (length(btrim(name)) between 2 and 100),
  amount numeric(12,2) not null check (amount >= 0),
  charge_type text not null check (charge_type in ('TUITION','ADMISSION','EXAM','MATERIAL','OTHER')),
  recurrence text not null check (recurrence in ('PER_CYCLE','ONE_TIME')),
  sort_order integer not null default 0,
  unique (fee_plan_version_id, code)
);

create or replace function public.guard_fee_plan_history()
returns trigger language plpgsql set search_path=public as $
begin
  if tg_table_name='fee_plan_components' then
    if tg_op='DELETE' then return old; end if;
    return new;
  end if;
  if tg_op='DELETE' then raise exception 'Fee Plans cannot be deleted.'; end if;
  if old.id is distinct from new.id or old.offering_id is distinct from new.offering_id
     or old.version is distinct from new.version or old.created_by is distinct from new.created_by then
    raise exception 'Fee Plan identity fields cannot be changed.';
  end if;
  return new;
end;
$;

create trigger fee_plan_version_history_guard
before update or delete on public.fee_plan_versions
for each row execute function public.guard_fee_plan_history();
create trigger fee_plan_component_history_guard
before insert or update or delete on public.fee_plan_components
for each row execute function public.guard_fee_plan_history();

create or replace function public.create_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_row public.programme_offerings;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to manage Programme Offerings.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active;
  if v_org is null or not exists (
    select 1 from public.branches b
    join public.academic_years y on y.id=(p_input->>'academic_year_id')::uuid
    join public.classes c on c.id=(p_input->>'class_id')::uuid
    join public.programs p on p.id=(p_input->>'program_id')::uuid
    where b.id=(p_input->>'branch_id')::uuid and b.is_active
      and b.organization_id=v_org and y.organization_id=v_org
      and c.organization_id=v_org and c.is_active
      and p.organization_id=v_org and p.is_active
      and (nullif(p_input->>'group_id','') is null or exists (
        select 1 from public.academic_groups g
        where g.id=(p_input->>'group_id')::uuid
          and g.organization_id=v_org and g.is_active))
  ) then
    raise exception 'Offering context must use active master data from the same organization.';
  end if;
  insert into public.programme_offerings(
    organization_id,branch_id,academic_year_id,class_id,program_id,
    group_id,code,name,created_by
  ) values (
    v_org,(p_input->>'branch_id')::uuid,(p_input->>'academic_year_id')::uuid,
    (p_input->>'class_id')::uuid,(p_input->>'program_id')::uuid,
    nullif(p_input->>'group_id','')::uuid,
    upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_actor
  ) returning * into v_row;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    branch_id,entity_type,entity_id,action,reason,after_data)
  values (v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
    v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'CREATE',v_reason,to_jsonb(v_row));
  return jsonb_build_object('offering_id',v_row.id,'correlation_id',v_correlation);
end;
$$;

create or replace function public.publish_fee_plan(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_plan public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_effective date := (p_input->>'effective_from')::date;
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then raise exception 'You are not authorized to manage Fee Plans.'; end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  if jsonb_typeof(v_components) is distinct from 'array' then raise exception 'Fee Components must be an array.'; end if;
  if jsonb_array_length(v_components)=0 or not exists (select 1 from jsonb_array_elements(v_components) c where c->>'charge_type'='TUITION' and c->>'recurrence'='PER_CYCLE') then raise exception 'A recurring Tuition component is required.'; end if;
  select * into v_offering from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status<>'RETIRED' for update;
  if v_offering.id is null then raise exception 'Offering is not available.'; end if;
  select (now() at time zone timezone)::date into v_today from public.organizations where id=v_offering.organization_id;
  if v_effective is distinct from v_today then raise exception 'Fee Plan effective date must be today.'; end if;
  select * into v_plan from public.fee_plan_versions where offering_id=v_offering.id order by case when status='ACTIVE' then 0 else 1 end, created_at desc limit 1 for update;
  if v_plan.id is null then
    insert into public.fee_plan_versions(offering_id,version,status,billing_cycle,due_day,currency_code,effective_from,effective_to,change_reason,created_by)
    values(v_offering.id,1,'ACTIVE',p_input->>'billing_cycle',(p_input->>'due_day')::integer,(select currency_code from public.organizations where id=v_offering.organization_id),v_effective,null,v_reason,v_actor)
    returning * into v_plan;
  else
    update public.fee_plan_versions set status='ACTIVE',billing_cycle=p_input->>'billing_cycle',due_day=(p_input->>'due_day')::integer,currency_code=(select currency_code from public.organizations where id=v_offering.organization_id),effective_from=v_effective,effective_to=null,change_reason=v_reason
    where id=v_plan.id returning * into v_plan;
    delete from public.fee_plan_components where fee_plan_version_id=v_plan.id;
  end if;
  for v_component in select value from jsonb_array_elements(v_components) loop
    insert into public.fee_plan_components(fee_plan_version_id,code,name,amount,charge_type,recurrence,sort_order)
    values(v_plan.id,upper(btrim(v_component->>'code')),btrim(v_component->>'name'),(v_component->>'amount')::numeric,v_component->>'charge_type',v_component->>'recurrence',coalesce((v_component->>'sort_order')::integer,0));
  end loop;
  update public.programme_offerings set status='ACTIVE' where id=v_offering.id;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,branch_id,entity_type,entity_id,action,reason,after_data,metadata)
  values(v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),v_offering.branch_id,'FEE_PLAN',v_plan.id::text,'SAVE',v_reason,to_jsonb(v_plan),jsonb_build_object('offering_id',v_offering.id,'component_count',jsonb_array_length(v_components)));
  return jsonb_build_object('fee_plan_version_id',v_plan.id,'version',1,'correlation_id',v_correlation);
end;
$;

alter table public.academic_groups enable row level security;
alter table public.programme_offerings enable row level security;
alter table public.fee_plan_versions enable row level security;
alter table public.fee_plan_components enable row level security;

grant select on public.academic_groups,public.programme_offerings,public.fee_plan_versions,
  public.fee_plan_components to authenticated;
revoke insert,update,delete on public.programme_offerings,public.fee_plan_versions,
  public.fee_plan_components from authenticated,anon;
revoke all on function public.create_programme_offering(jsonb),
  public.publish_fee_plan(jsonb) from public,anon;
grant execute on function public.create_programme_offering(jsonb),
  public.publish_fee_plan(jsonb) to authenticated;

create policy programme_offerings_read on public.programme_offerings
for select to authenticated using (public.has_permission('academics.view')
  or public.has_permission('admissions.view') or public.has_permission('finance.view'));
create policy academic_groups_read on public.academic_groups
for select to authenticated using (public.has_permission('academics.view')
  or public.has_permission('admissions.view'));
create policy fee_plan_versions_read on public.fee_plan_versions
for select to authenticated using (public.has_permission('finance.view')
  or public.has_permission('finance.billing.manage') or public.has_permission('admissions.view'));
create policy fee_plan_components_read on public.fee_plan_components
for select to authenticated using (public.has_permission('finance.view')
  or public.has_permission('finance.billing.manage') or public.has_permission('admissions.view'));



-- ============================================================
-- SOURCE: 0009_v2_fee_plan_local_date.sql
-- ============================================================

-- Fee Plan publication uses the organization local calendar date.
create or replace function public.publish_fee_plan(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_plan public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_effective date := (p_input->>'effective_from')::date;
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then raise exception 'You are not authorized to manage Fee Plans.'; end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  if jsonb_typeof(v_components) is distinct from 'array' then raise exception 'Fee Components must be an array.'; end if;
  if jsonb_array_length(v_components)=0 or not exists (select 1 from jsonb_array_elements(v_components) c where c->>'charge_type'='TUITION' and c->>'recurrence'='PER_CYCLE') then raise exception 'A recurring Tuition component is required.'; end if;
  select * into v_offering from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status<>'RETIRED' for update;
  if v_offering.id is null then raise exception 'Offering is not available.'; end if;
  select (now() at time zone timezone)::date into v_today from public.organizations where id=v_offering.organization_id;
  if v_effective is distinct from v_today then raise exception 'Fee Plan effective date must be today.'; end if;
  select * into v_plan from public.fee_plan_versions where offering_id=v_offering.id order by case when status='ACTIVE' then 0 else 1 end, created_at desc limit 1 for update;
  if v_plan.id is null then
    insert into public.fee_plan_versions(offering_id,version,status,billing_cycle,due_day,currency_code,effective_from,effective_to,change_reason,created_by)
    values(v_offering.id,1,'ACTIVE',p_input->>'billing_cycle',(p_input->>'due_day')::integer,(select currency_code from public.organizations where id=v_offering.organization_id),v_effective,null,v_reason,v_actor)
    returning * into v_plan;
  else
    update public.fee_plan_versions set status='ACTIVE',billing_cycle=p_input->>'billing_cycle',due_day=(p_input->>'due_day')::integer,currency_code=(select currency_code from public.organizations where id=v_offering.organization_id),effective_from=v_effective,effective_to=null,change_reason=v_reason
    where id=v_plan.id returning * into v_plan;
    delete from public.fee_plan_components where fee_plan_version_id=v_plan.id;
  end if;
  for v_component in select value from jsonb_array_elements(v_components) loop
    insert into public.fee_plan_components(fee_plan_version_id,code,name,amount,charge_type,recurrence,sort_order)
    values(v_plan.id,upper(btrim(v_component->>'code')),btrim(v_component->>'name'),(v_component->>'amount')::numeric,v_component->>'charge_type',v_component->>'recurrence',coalesce((v_component->>'sort_order')::integer,0));
  end loop;
  update public.programme_offerings set status='ACTIVE' where id=v_offering.id;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,branch_id,entity_type,entity_id,action,reason,after_data,metadata)
  values(v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),v_offering.branch_id,'FEE_PLAN',v_plan.id::text,'SAVE',v_reason,to_jsonb(v_plan),jsonb_build_object('offering_id',v_offering.id,'component_count',jsonb_array_length(v_components)));
  return jsonb_build_object('fee_plan_version_id',v_plan.id,'version',1,'correlation_id',v_correlation);
end;
$;



-- ============================================================
-- SOURCE: 0010_v2_admission_workflow.sql
-- ============================================================

-- Transactional Admission -> initial Billing -> policy-based Enrollment.
-- Fee versions and identity snapshots are pinned before acceptance.
alter table public.batches add column offering_id uuid references public.programme_offerings(id);
alter table public.batches add column capacity_policy_version_id uuid references public.business_rule_versions(id);
create sequence public.admission_no_seq;
create sequence public.invoice_no_seq;
create table public.admission_cases (
 id uuid primary key default gen_random_uuid(),
 admission_no text not null unique default ('ADM-'||lpad(nextval('public.admission_no_seq')::text,6,'0')),
 prospect_id uuid not null unique references public.prospects(id),
 batch_id uuid not null references public.batches(id),
 fee_plan_version_id uuid not null references public.fee_plan_versions(id),
 activation_policy_version_id uuid references public.business_rule_versions(id),
 capacity_policy_version_id uuid references public.business_rule_versions(id),
 student_id uuid unique references public.students(id),
 enrollment_id uuid unique references public.enrollments(id),
 status text not null default 'DRAFT' check(status in ('DRAFT','READY','ACCEPTED','BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT')),
 identity_snapshot jsonb not null,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create trigger admission_updated before update on public.admission_cases for each row execute function public.set_updated_at();
create table public.admission_invoices (
 id uuid primary key default gen_random_uuid(),
 invoice_no text not null unique default ('INV-'||lpad(nextval('public.invoice_no_seq')::text,6,'0')),
 admission_id uuid not null unique references public.admission_cases(id),
 student_id uuid not null references public.students(id),
 fee_plan_version_id uuid not null references public.fee_plan_versions(id),
 currency_code text not null,
 total numeric(12,2) not null check(total>=0),
 due_on date not null,
 issued_on date not null,
 posted_by uuid not null references public.profiles(id),
 posted_at timestamptz not null default now()
);
create table public.admission_invoice_lines (
 id uuid primary key default gen_random_uuid(),
 invoice_id uuid not null references public.admission_invoices(id),
 fee_component_id uuid not null references public.fee_plan_components(id),
 name text not null,
 charge_type text not null,
 amount numeric(12,2) not null check(amount>=0),
 unique(invoice_id,fee_component_id)
);
create table public.admission_command_keys (
 request_id uuid primary key,
 actor_id uuid not null references public.profiles(id),
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now()
);
create or replace function public.protect_admission_invoice()
returns trigger language plpgsql as $$ begin raise exception 'Posted billing history is immutable; use a compensating adjustment workflow.'; end; $$;
create trigger admission_invoice_immutable before update or delete on public.admission_invoices for each row execute function public.protect_admission_invoice();
create trigger admission_lines_immutable before update or delete on public.admission_invoice_lines for each row execute function public.protect_admission_invoice();

create or replace function public.admission_payment_satisfied(p_admission_id uuid)
returns boolean language sql security definer set search_path=public as $$
 select i.total=0 or (r.payload->>'payment_requirement'='NONE' and (r.payload->>'allow_credit_enrollment')::boolean)
 from public.admission_cases a join public.admission_invoices i on i.admission_id=a.id
 join public.business_rule_versions r on r.id=a.activation_policy_version_id where a.id=p_admission_id;
$$;
revoke all on function public.admission_payment_satisfied(uuid) from public,anon,authenticated;

create or replace function public.admission_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_actor uuid:=auth.uid(); v_action text:=p_input->>'action';
 v_request uuid:=(p_input->>'request_id')::uuid; v_key public.admission_command_keys;
 v_reason text:=btrim(coalesce(p_input->>'reason','')); v_case public.admission_cases;
 v_before jsonb; v_result jsonb; v_batch public.batches; v_offering public.programme_offerings;
 v_prospect public.prospects; v_fee public.fee_plan_versions;
 v_policy public.business_rule_versions; v_capacity public.business_rule_versions;
 v_guardian uuid; v_student uuid; v_enrollment uuid; v_invoice uuid;
 v_today date; v_total numeric; v_occupied integer;
begin
 if v_actor is null then raise exception 'Sign in to continue.'; end if;
 if v_action='CREATE_BATCH' then
   if not public.has_permission('academics.manage') then raise exception 'Batch management permission required.'; end if;
 elsif not public.has_permission('admissions.create') then raise exception 'Admission permission required.';
 end if;
 if v_request is null or length(v_reason)<5 then raise exception 'Request identity and a reason of at least five characters are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 select * into v_key from public.admission_command_keys where request_id=v_request;
 if found then
   if v_key.actor_id<>v_actor or v_key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
   return v_key.result;
 end if;
 if v_action='CREATE_BATCH' then
   select * into v_offering from public.programme_offerings where id=(p_input->>'offering_id')::uuid and status='ACTIVE' for update;
   if not found then raise exception 'Choose an active offering with a published Fee Plan.'; end if;
   select * into v_capacity from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
   if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;
   if length(btrim(coalesce(p_input->>'name','')))<2 or length(btrim(coalesce(p_input->>'code','')))<2 then raise exception 'Batch name and code are required.'; end if;
   insert into public.batches(organization_id,branch_id,academic_year_id,class_id,program_id,code,name,capacity,created_by,offering_id,capacity_policy_version_id)
   values(v_offering.organization_id,v_offering.branch_id,v_offering.academic_year_id,v_offering.class_id,v_offering.program_id,
     upper(btrim(p_input->>'code')),btrim(p_input->>'name'),(p_input->>'capacity')::integer,v_actor,v_offering.id,v_capacity.id) returning * into v_batch;
   v_result:=jsonb_build_object('id',v_batch.id,'status','CREATED');
 elsif v_action='CREATE' then
   select * into v_prospect from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
   if v_prospect.id is null or v_prospect.status in ('CONVERTED','LOST') then raise exception 'Choose an unconverted, open Prospect.'; end if;
   if exists(select 1 from public.admission_cases where prospect_id=v_prospect.id) then raise exception 'This Prospect already has an Admission Case. Open the existing case.'; end if;
   select * into v_batch from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
   select * into v_offering from public.programme_offerings where id=v_batch.offering_id and status='ACTIVE';
   if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id or v_prospect.current_class_id is distinct from v_offering.class_id then
     raise exception 'Batch must match the Prospect class and an active offering.';
   end if;
   if (select count(*) from public.enrollments where batch_id=v_batch.id and status='ACTIVE')>=v_batch.capacity then raise exception 'Selected batch is full.'; end if;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_offering.organization_id;
   select * into v_fee from public.fee_plan_versions where offering_id=v_offering.id and status='ACTIVE' and effective_from<=v_today;
   if v_fee.id is null then raise exception 'No effective published Fee Plan is available.'; end if;
   insert into public.admission_cases(prospect_id,batch_id,fee_plan_version_id,identity_snapshot,created_by)
   values(v_prospect.id,v_batch.id,v_fee.id,jsonb_build_object('student_name',v_prospect.student_name,'guardian_name',v_prospect.guardian_name,
     'mobile',v_prospect.mobile,'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian'),
     'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot),v_actor) returning * into v_case;
   v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status);
 else
   select * into v_case from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
   if not found then raise exception 'Admission Case not found.'; end if;
   v_before:=to_jsonb(v_case);
   select * into v_batch from public.batches where id=v_case.batch_id and is_active for update;
   if v_batch.id is null then raise exception 'Batch is no longer active.'; end if;
   select * into v_fee from public.fee_plan_versions where id=v_case.fee_plan_version_id for share;
   select (now() at time zone timezone)::date into v_today from public.organizations where id=v_batch.organization_id;
   if v_action='EDIT_DRAFT' and v_case.status in ('DRAFT','READY') then
     if length(btrim(coalesce(p_input->>'student_name','')))<2 or length(btrim(coalesce(p_input->>'guardian_name','')))<2
       or coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$' then raise exception 'Valid student, guardian and Bangladesh mobile details are required.'; end if;
     update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_build_object('student_name',btrim(p_input->>'student_name'),'guardian_name',btrim(p_input->>'guardian_name'),'mobile',p_input->>'mobile'),status='DRAFT' where id=v_case.id;
   elsif v_action='READY' and v_case.status='DRAFT' then
     if length(btrim(coalesce(v_case.identity_snapshot->>'student_name','')))<2 or length(btrim(coalesce(v_case.identity_snapshot->>'guardian_name','')))<2
       or coalesce(v_case.identity_snapshot->>'mobile','') !~ '^01[3-9][0-9]{8}$' then raise exception 'Valid student, guardian and Bangladesh mobile details are required. Correct the Prospect before starting admission.'; end if;
     if v_fee.status<>'ACTIVE' then raise exception 'The selected Fee Plan has changed. Refresh fees before review.'; end if;
     update public.admission_cases set status='READY' where id=v_case.id;
   elsif v_action='REFRESH_FEES' and v_case.status in ('DRAFT','READY') then
     select * into v_fee from public.fee_plan_versions where offering_id=v_batch.offering_id and status='ACTIVE' and effective_from<=v_today;
     if v_fee.id is null then raise exception 'No active Fee Plan.'; end if;
     update public.admission_cases set fee_plan_version_id=v_fee.id,status='DRAFT' where id=v_case.id;
   elsif v_action='ACCEPT' and v_case.status='READY' then
     select * into v_prospect from public.prospects where id=v_case.prospect_id for update;
     if v_prospect.status in ('CONVERTED','LOST') then raise exception 'Prospect is no longer eligible for admission.'; end if;
     if v_fee.status<>'ACTIVE' then raise exception 'Fee Plan changed. Refresh and review before acceptance.'; end if;
     select * into v_policy from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE';
     if v_policy.id is null or not public.validate_business_rule_payload('admissions','activation_policy',v_policy.payload) then raise exception 'A valid activation policy is required.'; end if;
     perform pg_advisory_xact_lock(hashtextextended(v_case.identity_snapshot->>'mobile',1));
     if exists(select 1 from public.students s join public.student_guardians sg on sg.student_id=s.id join public.guardians g on g.id=sg.guardian_id
       where s.organization_id=v_batch.organization_id and lower(s.full_name)=lower(v_case.identity_snapshot->>'student_name') and g.mobile=v_case.identity_snapshot->>'mobile') then
       raise exception 'Possible existing student with this name and guardian mobile. Review the existing identity before continuing.';
     end if;
     select id into v_guardian from public.guardians where organization_id=v_batch.organization_id and mobile=v_case.identity_snapshot->>'mobile'
       and lower(full_name)=lower(v_case.identity_snapshot->>'guardian_name') order by created_at limit 1;
     if v_guardian is null then
       insert into public.guardians(organization_id,full_name,mobile,created_by) values(v_batch.organization_id,v_case.identity_snapshot->>'guardian_name',v_case.identity_snapshot->>'mobile',v_actor) returning id into v_guardian;
     end if;
     insert into public.students(organization_id,branch_id,full_name,school_id,school_name_snapshot,status,created_from_prospect_id,created_by)
     values(v_batch.organization_id,v_batch.branch_id,v_case.identity_snapshot->>'student_name',(v_case.identity_snapshot->>'school_id')::uuid,
       v_case.identity_snapshot->>'school_name','INACTIVE',v_case.prospect_id,v_actor) returning id into v_student;
     insert into public.student_guardians(student_id,guardian_id,relationship_snapshot,is_primary) values(v_student,v_guardian,v_case.identity_snapshot->>'guardian_relationship',true);
     update public.admission_cases set student_id=v_student,activation_policy_version_id=v_policy.id,status='ACCEPTED' where id=v_case.id;
     update public.prospects set status='CONVERTED',converted_student_id=v_student,converted_at=now() where id=v_case.prospect_id;
   elsif v_action='BILL' and v_case.status='ACCEPTED' then
     select coalesce(sum(amount),0) into v_total from public.fee_plan_components where fee_plan_version_id=v_fee.id;
     if not exists(select 1 from public.fee_plan_components where fee_plan_version_id=v_fee.id) then raise exception 'Fee Plan has no charge components.'; end if;
     insert into public.admission_invoices(admission_id,student_id,fee_plan_version_id,currency_code,total,issued_on,due_on,posted_by)
     values(v_case.id,v_case.student_id,v_fee.id,v_fee.currency_code,v_total,v_today,
       case when v_fee.due_day is not null then greatest(v_today,date_trunc('month',v_today)::date+v_fee.due_day-1) else v_today end,v_actor) returning id into v_invoice;
     insert into public.admission_invoice_lines(invoice_id,fee_component_id,name,charge_type,amount)
     select v_invoice,id,name,charge_type,amount from public.fee_plan_components where fee_plan_version_id=v_fee.id;
     update public.admission_cases set status='BILLING_POSTED' where id=v_case.id;
   elsif v_action='ACTIVATE' and v_case.status in ('BILLING_POSTED','PENDING_PAYMENT') then
     select * into v_policy from public.business_rule_versions where id=v_case.activation_policy_version_id;
     select total into v_total from public.admission_invoices where admission_id=v_case.id;
     if v_total is null or v_case.student_id is null or v_policy.id is null then raise exception 'Accepted identity, initial billing and pinned activation policy are required.'; end if;
     -- Payment-backed activation is added by the following payment migration.
     if not coalesce(public.admission_payment_satisfied(v_case.id),false) then
       update public.admission_cases set status='PENDING_PAYMENT' where id=v_case.id;
     else
       select * into v_capacity from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
       if v_capacity.id is null then raise exception 'Capacity policy missing.'; end if;
       select count(*) into v_occupied from public.enrollments where batch_id=v_batch.id and status='ACTIVE';
       if v_occupied>=least(v_batch.capacity,(v_capacity.payload->>'max_students')::integer) then raise exception 'Selected batch is full under the current capacity policy.'; end if;
       insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,status,created_by)
       values(v_case.student_id,v_batch.organization_id,v_batch.branch_id,v_batch.academic_year_id,v_batch.class_id,v_batch.program_id,v_batch.id,'ACTIVE',v_actor) returning id into v_enrollment;
       update public.admission_cases set status='ACTIVE_ENROLLMENT',enrollment_id=v_enrollment,capacity_policy_version_id=v_capacity.id where id=v_case.id;
       update public.students set status='ACTIVE' where id=v_case.student_id;
     end if;
   else raise exception 'This action is not allowed from the current admission state.';
   end if;
   select * into v_case from public.admission_cases where id=v_case.id;
   v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status);
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
   case when v_action='CREATE_BATCH' then 'BATCH' else 'ADMISSION' end,v_result->>'id',v_action,v_reason,v_before,
   case when v_action='CREATE_BATCH' then to_jsonb(v_batch) else to_jsonb(v_case) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
 return v_result;
end; $$;

alter table public.admission_cases enable row level security;
alter table public.admission_invoices enable row level security;
alter table public.admission_invoice_lines enable row level security;
alter table public.admission_command_keys enable row level security;
grant select on public.admission_cases,public.admission_invoices,public.admission_invoice_lines to authenticated;
revoke insert,update,delete on public.enrollments,public.batches from authenticated;
revoke insert,update,delete on public.admission_cases,public.admission_invoices,public.admission_invoice_lines,public.admission_command_keys from authenticated,anon;
create policy admission_cases_read on public.admission_cases for select to authenticated using(public.has_permission('admissions.view'));
create policy admission_invoices_read on public.admission_invoices for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
create policy admission_lines_read on public.admission_invoice_lines for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
revoke all on function public.admission_command(jsonb) from public,anon;
grant execute on function public.admission_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0011_v2_admission_payments.sql
-- ============================================================

-- First-payment workflow: posted money, explicit allocation, immutable receipt.
create sequence public.admission_receipt_no_seq;
create table public.admission_payments (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id),
 payment_method_id uuid not null references public.payment_methods(id),
 amount numeric(12,2) not null check(amount>0),
 currency_code text not null,
 external_reference text,
 receipt_no text not null unique default ('RCT-'||lpad(nextval('public.admission_receipt_no_seq')::text,6,'0')),
 posted_by uuid not null references public.profiles(id),
 posted_at timestamptz not null default now(),
 reason text not null
);
create unique index admission_payment_external_reference on public.admission_payments(payment_method_id,external_reference) where external_reference is not null;
create table public.admission_payment_allocations (
 payment_id uuid primary key references public.admission_payments(id),
 invoice_id uuid not null references public.admission_invoices(id),
 amount numeric(12,2) not null check(amount>0)
);
create trigger admission_payment_immutable before update or delete on public.admission_payments for each row execute function public.protect_admission_invoice();
create trigger admission_allocation_immutable before update or delete on public.admission_payment_allocations for each row execute function public.protect_admission_invoice();

create or replace function public.admission_payment_satisfied(p_admission_id uuid)
returns boolean language sql security definer set search_path=public as $$
 select coalesce(sum(pa.amount),0)>=case
 when not (r.payload->>'allow_credit_enrollment')::boolean or r.payload->>'payment_requirement'='FULL' then i.total
 when r.payload->>'payment_requirement'='MINIMUM_PERCENT' then round(i.total*(r.payload->>'minimum_payment_percent')::numeric/100,2)
 else 0 end
 from public.admission_cases a join public.admission_invoices i on i.admission_id=a.id
 join public.business_rule_versions r on r.id=a.activation_policy_version_id
 left join public.admission_payment_allocations pa on pa.invoice_id=i.id
 where a.id=p_admission_id group by i.total,r.payload;
$$;

create or replace function public.post_admission_payment(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_actor uuid:=auth.uid(); v_request uuid:=(p_input->>'request_id')::uuid;
 v_key public.admission_command_keys; v_case public.admission_cases; v_invoice public.admission_invoices;
 v_payment public.admission_payments; v_amount numeric:=(p_input->>'amount')::numeric;
 v_paid numeric; v_result jsonb; v_reason text:=btrim(coalesce(p_input->>'reason',''));
begin
 if v_actor is null or not public.has_permission('finance.payments.post') then raise exception 'Payment posting permission required.'; end if;
 if v_request is null or v_amount is null or v_amount<=0 or v_amount<>round(v_amount,2) or length(v_reason)<5 then raise exception 'Valid amount, request identity and reason are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 select * into v_key from public.admission_command_keys where request_id=v_request;
 if found then
   if v_key.actor_id<>v_actor or v_key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
   return v_key.result;
 end if;
 select * into v_case from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if not found or v_case.status not in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT') then raise exception 'Post initial billing before collecting payment.'; end if;
 select * into v_invoice from public.admission_invoices where admission_id=v_case.id for update;
 select coalesce(sum(amount),0) into v_paid from public.admission_payment_allocations where invoice_id=v_invoice.id;
 if v_invoice.id is null or v_amount>v_invoice.total-v_paid then raise exception 'Payment exceeds the outstanding invoice balance.'; end if;
 if not exists(select 1 from public.payment_methods where id=(p_input->>'payment_method_id')::uuid and is_active) then raise exception 'Choose an active payment method.'; end if;
 insert into public.admission_payments(student_id,payment_method_id,amount,currency_code,external_reference,posted_by,reason)
 values(v_case.student_id,(p_input->>'payment_method_id')::uuid,v_amount,v_invoice.currency_code,nullif(btrim(p_input->>'external_reference'),''),v_actor,v_reason) returning * into v_payment;
 insert into public.admission_payment_allocations(payment_id,invoice_id,amount) values(v_payment.id,v_invoice.id,v_amount);
 v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status,'receipt_no',v_payment.receipt_no);
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(v_request,v_actor,'PAYMENT',v_payment.id::text,'POST',v_reason,to_jsonb(v_payment),jsonb_build_object('invoice_id',v_invoice.id,'admission_id',v_case.id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
 return v_result;
end; $$;
alter table public.admission_payments enable row level security;
alter table public.admission_payment_allocations enable row level security;
grant select on public.admission_payments,public.admission_payment_allocations to authenticated;
revoke insert,update,delete on public.admission_payments,public.admission_payment_allocations from authenticated,anon;
create policy admission_payment_read on public.admission_payments for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
create policy admission_allocation_read on public.admission_payment_allocations for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
revoke all on function public.post_admission_payment(jsonb) from public,anon;
grant execute on function public.post_admission_payment(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0012_v2_admission_workspace.sql
-- ============================================================

-- Permission-scoped read model; sensitive case/prospect data needs admissions.view.
create or replace function public.admission_workspace()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_view boolean:=public.has_permission('admissions.view'); v_result jsonb;
begin
 if auth.uid() is null or not (v_view or public.has_permission('academics.view')) then raise exception 'Workspace access denied.'; end if;
 select jsonb_build_object(
  'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'classId',o.class_id,'className',c.name)) from public.programme_offerings o join public.classes c on c.id=o.class_id where o.status='ACTIVE'),'[]'::jsonb),
  'capacityLimit',(select (payload->>'max_students')::integer from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'),
  'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,'classId',b.class_id,'capacity',b.capacity,'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE'))) from public.batches b where b.is_active and b.offering_id is not null),'[]'::jsonb),
  'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id)),'[]'::jsonb) else '[]'::jsonb end,
  'cases',case when v_view then coalesce((select jsonb_agg(x order by x->>'createdAt' desc) from (
    select jsonb_build_object('id',a.id,'number',a.admission_no,'status',a.status,'createdAt',a.created_at,
      'batchId',a.batch_id,'studentNo',s.student_no,'studentId',s.id,'name',a.identity_snapshot->>'student_name','guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',
      'feeVersion',f.version,'feePlanId',f.id,'policyVersion',r.version,'paymentRequirement',r.payload->>'payment_requirement',
      'components',coalesce((select jsonb_agg(jsonb_build_object('name',fc.name,'amount',fc.amount,'recurrence',fc.recurrence)) from public.fee_plan_components fc where fc.fee_plan_version_id=f.id),'[]'::jsonb),
      'invoice',case when i.id is null then null else jsonb_build_object('number',i.invoice_no,'total',i.total,'dueOn',i.due_on,'paid',coalesce((select sum(amount) from public.admission_payment_allocations where invoice_id=i.id),0)) end,
      'receipts',coalesce((select jsonb_agg(jsonb_build_object('number',p.receipt_no,'amount',pa.amount,'postedAt',p.posted_at,'method',pm.name)) from public.admission_payment_allocations pa join public.admission_payments p on p.id=pa.payment_id join public.payment_methods pm on pm.id=p.payment_method_id where pa.invoice_id=i.id),'[]'::jsonb)
    ) as x
    from public.admission_cases a join public.fee_plan_versions f on f.id=a.fee_plan_version_id
    left join public.students s on s.id=a.student_id left join public.business_rule_versions r on r.id=a.activation_policy_version_id
    left join public.admission_invoices i on i.admission_id=a.id
  ) rows),'[]'::jsonb) else '[]'::jsonb end,
  'paymentMethods',case when public.has_permission('finance.payments.post') then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb) else '[]'::jsonb end
 ) into v_result;
 return v_result;
end; $$;
revoke all on function public.admission_workspace() from public,anon;
grant execute on function public.admission_workspace() to authenticated;



-- ============================================================
-- SOURCE: 0013_v2_finance_adjustment_foundation.sql
-- ============================================================

-- Preserve gross invoices/payments; adjustments are immutable compensating facts.
alter table public.admission_cases drop constraint admission_cases_status_check;
alter table public.admission_cases add constraint admission_cases_status_check check(status in ('DRAFT','READY','ACCEPTED','BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT','CANCELLED'));
alter table public.admission_cases drop constraint admission_cases_prospect_id_key;
create unique index admission_open_prospect on public.admission_cases(prospect_id) where status<>'CANCELLED';
alter table public.admission_invoices drop constraint admission_invoices_admission_id_key;
alter table public.admission_invoices add column invoice_kind text not null default 'INITIAL' check(invoice_kind in ('INITIAL','RECURRING'));
alter table public.admission_invoices add column billing_period date;
-- Controlled one-time backfill; restore the history trigger immediately.
alter table public.admission_invoices disable trigger admission_invoice_immutable;
update public.admission_invoices set billing_period=date_trunc('month',issued_on)::date;
alter table public.admission_invoices enable trigger admission_invoice_immutable;
alter table public.admission_invoices alter column billing_period set not null;
create unique index admission_one_initial_invoice on public.admission_invoices(admission_id) where invoice_kind='INITIAL';
create unique index admission_invoice_period on public.admission_invoices(admission_id,billing_period);
create table public.billing_terms (
 id uuid primary key default gen_random_uuid(), academic_year_id uuid not null references public.academic_years(id),
 name text not null check(length(btrim(name))>=2), starts_on date not null, ends_on date not null, due_on date not null,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
 check(ends_on>=starts_on), check(due_on>=starts_on), unique(academic_year_id,starts_on)
);
create table public.admission_discounts (
 id uuid primary key default gen_random_uuid(), admission_id uuid not null references public.admission_cases(id),
 approval_id uuid not null unique references public.approval_requests(id),
 kind text not null check(kind in ('PERCENT','FIXED')), value numeric(12,2) not null check(value>0),
 starts_on date not null, ends_on date not null, check(ends_on>=starts_on),
 check(kind<>'PERCENT' or value<=100), created_at timestamptz not null default now()
);
create table public.invoice_credits (
 id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.admission_invoices(id),
 approval_id uuid not null references public.approval_requests(id),
 discount_id uuid references public.admission_discounts(id), kind text not null check(kind in ('DISCOUNT','CANCELLATION')),
 amount numeric(12,2) not null check(amount>0), created_at timestamptz not null default now(),
 unique(invoice_id,approval_id)
);
create table public.refund_authorizations (
 id uuid primary key default gen_random_uuid(), approval_id uuid not null unique references public.approval_requests(id),
 payment_id uuid not null references public.admission_payments(id), invoice_id uuid not null references public.admission_invoices(id),
 amount numeric(12,2) not null check(amount>0), created_at timestamptz not null default now()
);
create sequence public.refund_no_seq;
create table public.refund_payouts (
 id uuid primary key default gen_random_uuid(), authorization_id uuid not null unique references public.refund_authorizations(id),
 refund_no text not null unique default ('RFN-'||lpad(nextval('public.refund_no_seq')::text,6,'0')),
 payment_method_id uuid not null references public.payment_methods(id), external_reference text,
 posted_by uuid not null references public.profiles(id), posted_at timestamptz not null default now(), reason text not null
);
create unique index refund_external_reference on public.refund_payouts(payment_method_id,external_reference) where external_reference is not null;
create table public.admission_cancellations (
 admission_id uuid primary key references public.admission_cases(id), approval_id uuid not null unique references public.approval_requests(id),
 settlement text not null check(settlement in ('KEEP_CHARGES','CREDIT_ALL')), cancelled_at timestamptz not null default now()
);
create table public.billing_runs (
 id uuid primary key, period date not null, term_id uuid references public.billing_terms(id),
 posted_by uuid not null references public.profiles(id), posted_at timestamptz not null default now(),
 invoice_count integer not null, gross_total numeric(14,2) not null, reason text not null
);

create or replace function public.invoice_balance(p_invoice_id uuid)
returns table(gross numeric,credits numeric,paid numeric,refunded numeric,net numeric,due numeric,credit_balance numeric,reserved_refunds numeric)
language sql stable security definer set search_path=public as $$
 with x as (
 select i.total as g,
 coalesce((select sum(amount) from public.invoice_credits where invoice_id=i.id),0) c,
 coalesce((select sum(amount) from public.admission_payment_allocations where invoice_id=i.id),0) p,
 coalesce((select sum(r.amount) from public.refund_authorizations r join public.refund_payouts rp on rp.authorization_id=r.id where r.invoice_id=i.id),0) f,
 coalesce((select sum(r.amount) from public.refund_authorizations r where r.invoice_id=i.id and not exists(select 1 from public.refund_payouts rp where rp.authorization_id=r.id)),0) reserved
 from public.admission_invoices i where i.id=p_invoice_id)
 select g,c,p,f,g-c,greatest(g-c-p+f,0),greatest(p-f-(g-c),0),reserved from x;
$$;
revoke all on function public.invoice_balance(uuid) from public,anon,authenticated;

create or replace function public.apply_invoice_discounts(p_invoice_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare i public.admission_invoices; d public.admission_discounts; tuition numeric; credit numeric;
begin
 select * into i from public.admission_invoices where id=p_invoice_id;
 select coalesce(sum(amount),0) into tuition from public.admission_invoice_lines where invoice_id=i.id and charge_type='TUITION';
 for d in select * from public.admission_discounts where admission_id=i.admission_id and i.billing_period between starts_on and ends_on loop
  credit:=least(tuition,case when d.kind='PERCENT' then round(tuition*d.value/100,2) else d.value end);
  if credit>0 then insert into public.invoice_credits(invoice_id,approval_id,discount_id,kind,amount)
   values(i.id,d.approval_id,d.id,'DISCOUNT',credit) on conflict(invoice_id,approval_id) do nothing; end if;
 end loop;
end; $$;
revoke all on function public.apply_invoice_discounts(uuid) from public,anon,authenticated;

-- Protect all finalized adjustment records, including term definitions used by billing.
do $$ declare t text; begin
 foreach t in array array['billing_terms','admission_discounts','invoice_credits','refund_authorizations','refund_payouts','admission_cancellations','billing_runs'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
  execute format('create policy finance_read on public.%I for select to authenticated using (public.has_permission(''finance.view''))',t);
  execute format('create trigger immutable_finance_history before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 end loop;
end; $$;
-- Decisions must go through the atomic workflow, not direct API updates.
revoke insert,update,delete on public.approval_requests from authenticated;

