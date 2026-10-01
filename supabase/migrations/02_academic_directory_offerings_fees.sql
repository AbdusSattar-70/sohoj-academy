-- Sohoj Academy fresh database baseline: academic directory offerings fees.
-- Install on an empty application schema. Each object is defined once.

create table public.academic_years (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_active boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table public.classes (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  sort_order integer default 0 not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.programs (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  description text,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.subjects (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.areas (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  name text not null,
  parent_id uuid,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.schools (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  area_id uuid,
  name text not null,
  is_verified boolean default false not null,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.lead_sources (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.guardian_relationships (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.academic_groups (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  is_active boolean default true not null
);

create table public.programme_offerings (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  branch_id uuid not null,
  academic_year_id uuid not null,
  class_id uuid not null,
  program_id uuid not null,
  group_id uuid,
  code text not null,
  name text not null,
  status offering_status default 'DRAFT'::offering_status not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  showcase_title text,
  showcase_title_bn text,
  showcase_description text,
  showcase_description_bn text,
  showcase_eyebrow text,
  showcase_eyebrow_bn text,
  showcase_icon text,
  showcase_sort_order integer default 100 not null,
  is_website_visible boolean default false not null,
  is_accepting_applications boolean default false not null,
  applications_open_on date,
  applications_close_on date,
  public_schedule text,
  public_requirements text,
  admission_policy text,
  public_schedule_bn text,
  public_requirements_bn text,
  admission_policy_bn text,
  allowed_discount_percentages integer[] default '{}'::integer[] not null
);

create table public.fee_plan_versions (
  id uuid default gen_random_uuid() not null,
  offering_id uuid not null,
  version integer not null,
  status rule_status default 'DRAFT'::rule_status not null,
  billing_cycle text not null,
  due_day integer,
  currency_code text default 'BDT'::text not null,
  effective_from date not null,
  effective_to date,
  change_reason text not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.fee_plan_components (
  id uuid default gen_random_uuid() not null,
  fee_plan_version_id uuid not null,
  code text not null,
  name text not null,
  amount numeric(12,2) not null,
  charge_type text not null,
  recurrence text not null,
  sort_order integer default 0 not null
);

create table public.programme_offering_subjects (
  offering_id uuid not null,
  subject_id uuid not null,
  sort_order integer default 0 not null
);
