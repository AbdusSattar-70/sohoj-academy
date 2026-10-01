-- Sohoj Academy fresh database baseline: platform identity access.
-- Install on an empty application schema. Each object is defined once.

create extension if not exists pgcrypto;

create type public.approval_status as enum ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

create type public.enrollment_status as enum ('ACTIVE', 'COMPLETED', 'WITHDRAWN', 'CANCELLED');

create type public.offering_status as enum ('DRAFT', 'ACTIVE', 'RETIRED');

create type public.profile_status as enum ('ACTIVE', 'SUSPENDED', 'ARCHIVED');

create type public.prospect_status as enum ('NEW', 'CONTACTED', 'COUNSELLING', 'TRIAL_SCHEDULED', 'TRIAL_ATTENDED', 'REGISTERED', 'CONVERTED', 'FUTURE_FOLLOW_UP', 'LOST');

create type public.rule_status as enum ('DRAFT', 'ACTIVE', 'RETIRED');

create type public.staff_status as enum ('ACTIVE', 'ON_LEAVE', 'RESIGNED', 'TERMINATED', 'ARCHIVED');

create type public.student_status as enum ('ACTIVE', 'INACTIVE', 'WITHDRAWN', 'GRADUATED', 'ARCHIVED');

create sequence public.staff_no_seq start with 1;

create sequence public.prospect_no_seq start with 1;

create sequence public.student_no_seq start with 1;

create sequence public.admission_no_seq start with 1;

create sequence public.invoice_no_seq start with 1;

create sequence public.admission_receipt_no_seq start with 1;

create sequence public.refund_no_seq start with 1;

create sequence public.general_ledger_journal_no_seq start with 1;

create sequence public.vendor_no_seq start with 1;

create sequence public.finance_payable_no_seq start with 1;

create sequence public.finance_advance_no_seq start with 1;

create sequence public.finance_expense_no_seq start with 1;

create sequence public.teacher_compensation_run_no_seq start with 1;

CREATE OR REPLACE FUNCTION public.generate_staff_no()
 RETURNS text
 LANGUAGE sql
AS $function$
  select 'SA-STF-' || lpad(nextval('public.staff_no_seq')::text, 6, '0');
$function$
;

CREATE OR REPLACE FUNCTION public.generate_prospect_no()
 RETURNS text
 LANGUAGE sql
AS $function$
  select 'PR-' || lpad(nextval('public.prospect_no_seq')::text, 6, '0');
$function$
;

CREATE OR REPLACE FUNCTION public.generate_student_no()
 RETURNS text
 LANGUAGE sql
AS $function$
  select 'SA-' || lpad(nextval('public.student_no_seq')::text, 6, '0');
$function$
;

create table public.organizations (
  id uuid default gen_random_uuid() not null,
  code text not null,
  name text not null,
  timezone text default 'Asia/Dhaka'::text not null,
  currency_code text default 'BDT'::text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  setup_completed_at timestamp with time zone,
  setup_completed_by uuid,
  setup_identity_confirmed_at timestamp with time zone
);

create table public.branches (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  address text,
  timezone text default 'Asia/Dhaka'::text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.profiles (
  id uuid not null,
  display_name text not null,
  status profile_status default 'ACTIVE'::profile_status not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.system_roles (
  id uuid default gen_random_uuid() not null,
  code text not null,
  name text not null,
  description text,
  is_system boolean default true not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.permissions (
  id uuid default gen_random_uuid() not null,
  code text not null,
  name text not null,
  description text,
  created_at timestamp with time zone default now() not null
);

create table public.role_permissions (
  role_id uuid not null,
  permission_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.user_role_assignments (
  id uuid default gen_random_uuid() not null,
  profile_id uuid not null,
  role_id uuid not null,
  branch_id uuid,
  effective_from date default CURRENT_DATE not null,
  effective_to date,
  is_active boolean default true not null,
  assigned_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.staff (
  id uuid default gen_random_uuid() not null,
  staff_no text default generate_staff_no() not null,
  profile_id uuid,
  branch_id uuid,
  full_name text not null,
  mobile text,
  alternate_mobile text,
  email text,
  address text,
  emergency_contact_name text,
  emergency_contact_mobile text,
  joined_on date,
  left_on date,
  status staff_status default 'ACTIVE'::staff_status not null,
  notes text,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.staff_roles (
  id uuid default gen_random_uuid() not null,
  code text not null,
  name text not null,
  is_teaching_role boolean default false not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.staff_role_assignments (
  id uuid default gen_random_uuid() not null,
  staff_id uuid not null,
  staff_role_id uuid not null,
  branch_id uuid,
  effective_from date default CURRENT_DATE not null,
  effective_to date,
  is_primary boolean default false not null,
  assigned_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.audit_events (
  id uuid default gen_random_uuid() not null,
  correlation_id uuid default gen_random_uuid() not null,
  occurred_at timestamp with time zone default now() not null,
  actor_profile_id uuid,
  actor_staff_id uuid,
  actor_role_code text,
  branch_id uuid,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  reason text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb default '{}'::jsonb not null
);

create table public.approval_requests (
  id uuid default gen_random_uuid() not null,
  correlation_id uuid default gen_random_uuid() not null,
  workflow_type text not null,
  entity_type text not null,
  entity_id text not null,
  requested_action text not null,
  payload_snapshot jsonb default '{}'::jsonb not null,
  request_note text,
  status approval_status default 'PENDING'::approval_status not null,
  requested_by uuid not null,
  requested_at timestamp with time zone default now() not null,
  decided_by uuid,
  decided_at timestamp with time zone,
  decision_note text,
  created_at timestamp with time zone default now() not null
);

create table public.business_rule_versions (
  id uuid default gen_random_uuid() not null,
  domain text not null,
  rule_key text not null,
  version integer not null,
  status rule_status default 'DRAFT'::rule_status not null,
  effective_from date default CURRENT_DATE not null,
  effective_to date,
  payload jsonb not null,
  change_reason text not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.staff_access_requests (
  id uuid default gen_random_uuid() not null,
  full_name text not null,
  email text not null,
  mobile text not null,
  requested_role text not null,
  purpose text not null,
  status text default 'PENDING'::text not null,
  assigned_role text,
  profile_id uuid,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  invitation_sent_at timestamp with time zone,
  review_note text,
  created_at timestamp with time zone default now() not null
);
