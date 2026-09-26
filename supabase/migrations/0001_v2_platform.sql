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
  ('UNCLE','Uncle'),
  ('AUNT','Aunt'),
  ('OTHER','Other')
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
