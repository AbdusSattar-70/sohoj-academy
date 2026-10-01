-- Sohoj Academy fresh database baseline: crm admissions student lifecycle.
-- Install on an empty application schema. Each object is defined once.

create table public.prospects (
  id uuid default gen_random_uuid() not null,
  prospect_no text default generate_prospect_no() not null,
  organization_id uuid not null,
  branch_id uuid,
  student_name text not null,
  student_name_bn text,
  guardian_name text not null,
  guardian_relationship_id uuid,
  guardian_relationship_snapshot text,
  mobile text not null,
  alternate_mobile text,
  current_class_id uuid,
  school_id uuid,
  school_name_snapshot text,
  area_id uuid,
  area_snapshot text,
  preferred_schedule text,
  preferred_days text[] default '{}'::text[] not null,
  trial_interest boolean default false not null,
  source_id uuid,
  referral_note text,
  notes text,
  consent_to_contact boolean default false not null,
  status prospect_status default 'NEW'::prospect_status not null,
  assigned_to_staff_id uuid,
  next_follow_up_at timestamp with time zone,
  lost_reason text,
  converted_student_id uuid,
  converted_at timestamp with time zone,
  submitted_via text default 'PUBLIC_WEB'::text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  interested_offering_id uuid,
  submission_intent text default 'interest'::text not null,
  date_of_birth date,
  gender text,
  school_roll text,
  guardian_address text,
  application_snapshot jsonb,
  application_verified_at timestamp with time zone,
  application_verified_by uuid
);

create table public.prospect_program_interests (
  prospect_id uuid not null,
  program_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.prospect_subject_interests (
  prospect_id uuid not null,
  subject_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.prospect_followups (
  id uuid default gen_random_uuid() not null,
  prospect_id uuid not null,
  followup_type text not null,
  occurred_at timestamp with time zone default now() not null,
  outcome text,
  notes text not null,
  next_follow_up_at timestamp with time zone,
  recorded_by uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.students (
  id uuid default gen_random_uuid() not null,
  student_no text default generate_student_no() not null,
  organization_id uuid not null,
  branch_id uuid,
  full_name text not null,
  name_bn text,
  gender text,
  date_of_birth date,
  school_id uuid,
  school_name_snapshot text,
  school_roll text,
  status student_status default 'ACTIVE'::student_status not null,
  created_from_prospect_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  merged_into_id uuid,
  academy_roll bigint generated always as identity not null
);

create table public.guardians (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  full_name text not null,
  mobile text not null,
  alternate_mobile text,
  email text,
  address text,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.student_guardians (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  guardian_id uuid not null,
  relationship_id uuid,
  relationship_snapshot text,
  is_primary boolean default false not null,
  created_at timestamp with time zone default now() not null
);

create table public.batches (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  branch_id uuid,
  academic_year_id uuid not null,
  class_id uuid not null,
  program_id uuid,
  code text not null,
  name text not null,
  capacity integer not null,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  offering_id uuid,
  capacity_policy_version_id uuid
);

create table public.enrollments (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  organization_id uuid not null,
  branch_id uuid,
  academic_year_id uuid not null,
  class_id uuid not null,
  program_id uuid,
  batch_id uuid,
  admission_date date default CURRENT_DATE not null,
  status enrollment_status default 'ACTIVE'::enrollment_status not null,
  ended_on date,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.admission_cases (
  id uuid default gen_random_uuid() not null,
  admission_no text default ('ADM-'::text || lpad((nextval('admission_no_seq'::regclass))::text, 6, '0'::text)) not null,
  prospect_id uuid,
  batch_id uuid not null,
  fee_plan_version_id uuid not null,
  activation_policy_version_id uuid,
  capacity_policy_version_id uuid,
  student_id uuid,
  enrollment_id uuid,
  status text default 'DRAFT'::text not null,
  identity_snapshot jsonb not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  existing_student boolean default false not null,
  consent_required boolean default true not null,
  origin text default 'PROSPECT_CONVERSION'::text not null,
  origin_prospect_id uuid,
  selected_discount_percent integer default 0 not null,
  discount_reason text,
  identity_revision integer default 1 not null,
  additional_charges jsonb default '[]'::jsonb not null
);

create table public.admission_command_keys (
  request_id uuid not null,
  actor_id uuid not null,
  payload jsonb not null,
  result jsonb not null,
  created_at timestamp with time zone default now() not null
);

create table public.student_merges (
  id uuid default gen_random_uuid() not null,
  source_id uuid not null,
  target_id uuid not null,
  source_snapshot jsonb not null,
  target_snapshot jsonb not null,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid not null,
  authorization_reason text not null
);

create table public.enrollment_transfers (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  admission_id uuid not null,
  from_enrollment_id uuid not null,
  to_enrollment_id uuid not null,
  from_batch_id uuid not null,
  to_batch_id uuid not null,
  capacity_policy_version_id uuid not null,
  transferred_on date not null,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid not null,
  authorization_reason text not null
);

create table public.staff_admission_intake_requests (
  request_id uuid not null,
  actor_id uuid not null,
  payload jsonb not null,
  prospect_id uuid,
  admission_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.admission_physical_consent_receipts (
  id uuid default gen_random_uuid() not null,
  request_id uuid not null,
  request_payload jsonb not null,
  admission_id uuid not null,
  version integer not null,
  guardian_signed_on date not null,
  student_signed boolean default false not null,
  physical_copy_reference text,
  received_by uuid not null,
  received_at timestamp with time zone default now() not null,
  reason text not null,
  identity_revision integer default 1 not null
);
