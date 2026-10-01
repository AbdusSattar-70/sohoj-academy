-- Sohoj Academy fresh database baseline: teacher academic records.
-- Install on an empty application schema. Each object is defined once.

create table public.staff_subject_assignments (
  id uuid default gen_random_uuid() not null,
  staff_id uuid not null,
  subject_id uuid not null,
  effective_from date default CURRENT_DATE not null,
  effective_to date,
  is_primary boolean default false not null,
  assigned_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.academic_rooms (
  id uuid default gen_random_uuid() not null,
  branch_id uuid not null,
  name text not null,
  capacity integer not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.curriculum_versions (
  id uuid default gen_random_uuid() not null,
  batch_id uuid not null,
  subject_id uuid not null,
  version integer not null,
  title text not null,
  units jsonb not null,
  reason text not null,
  published_by uuid not null,
  published_at timestamp with time zone default now() not null
);

create table public.academic_routines (
  id uuid default gen_random_uuid() not null,
  batch_id uuid not null,
  subject_id uuid not null,
  teacher_id uuid not null,
  room_id uuid not null,
  weekday integer not null,
  start_time time without time zone not null,
  end_time time without time zone not null,
  starts_on date not null,
  ends_on date not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null,
  retired_at timestamp with time zone
);

create table public.class_sessions (
  id uuid default gen_random_uuid() not null,
  routine_id uuid,
  batch_id uuid not null,
  subject_id uuid not null,
  teacher_id uuid not null,
  room_id uuid not null,
  curriculum_version_id uuid,
  planned_scope text not null,
  session_date date not null,
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone not null,
  status text default 'SCHEDULED'::text not null,
  cancellation_reason text,
  cancelled_by uuid,
  cancelled_at timestamp with time zone,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.attendance_submissions (
  id uuid default gen_random_uuid() not null,
  session_id uuid not null,
  revision integer not null,
  entries jsonb not null,
  reason text not null,
  status text default 'DRAFT'::text not null,
  recorded_by uuid not null,
  created_at timestamp with time zone default now() not null,
  approval_id uuid,
  reviewer_id uuid,
  review_note text,
  reviewed_at timestamp with time zone
);

create table public.class_logs (
  id uuid default gen_random_uuid() not null,
  session_id uuid not null,
  revision integer not null,
  previous_log_id uuid,
  status text not null,
  unit_progress jsonb default '[]'::jsonb not null,
  class_summary text not null,
  unfinished_reason text default ''::text not null,
  homework text default ''::text not null,
  next_session_plan text default ''::text not null,
  reason text not null,
  authored_by uuid not null,
  created_at timestamp with time zone default now() not null,
  submitted_at timestamp with time zone,
  reviewer_id uuid,
  review_note text,
  reviewed_at timestamp with time zone
);

create table public.question_bank_items (
  id uuid default gen_random_uuid() not null,
  root_id uuid,
  revision integer default 1 not null,
  batch_id uuid not null,
  subject_id uuid not null,
  curriculum_version_id uuid,
  topic text not null,
  difficulty text not null,
  question_type text not null,
  prompt text not null,
  choices jsonb default '[]'::jsonb not null,
  answer_key text not null,
  explanation text,
  status text default 'DRAFT'::text not null,
  author_id uuid not null,
  reviewer_id uuid,
  review_note text,
  created_at timestamp with time zone default now() not null,
  submitted_at timestamp with time zone,
  reviewed_at timestamp with time zone
);

create table public.homework_checks (
  id uuid default gen_random_uuid() not null,
  class_log_id uuid not null,
  enrollment_id uuid not null,
  revision integer not null,
  status text not null,
  submitted_on date,
  feedback text default ''::text not null,
  recorded_by uuid not null,
  recorded_at timestamp with time zone default now() not null
);

create table public.academic_assessments (
  id uuid default gen_random_uuid() not null,
  batch_id uuid not null,
  subject_id uuid not null,
  title text not null,
  assessment_date date not null,
  max_marks numeric(8,2) not null,
  status text default 'DRAFT'::text not null,
  author_id uuid not null,
  created_at timestamp with time zone default now() not null,
  published_at timestamp with time zone
);

create table public.assessment_result_submissions (
  id uuid default gen_random_uuid() not null,
  assessment_id uuid not null,
  revision integer not null,
  entries jsonb not null,
  status text default 'DRAFT'::text not null,
  author_id uuid not null,
  reviewer_id uuid,
  review_note text,
  created_at timestamp with time zone default now() not null,
  submitted_at timestamp with time zone,
  reviewed_at timestamp with time zone
);
