create type public.payment_status as enum ('POSTED','VOID');
create type public.attendance_status as enum ('PRESENT','ABSENT','LATE','EXCUSED');

create table public.classrooms (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  capacity integer check (capacity > 0),
  is_active boolean not null default true
);

create table public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.batches(id),
  subject_id uuid references public.subjects(id),
  teacher_id uuid references public.teachers(id),
  classroom_id uuid references public.classrooms(id),
  session_date date not null,
  starts_at time not null,
  ends_at time not null,
  session_type text not null default 'CLASS',
  notes text,
  check (ends_at > starts_at)
);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.class_sessions(id),
  student_id uuid not null references public.students(id),
  status public.attendance_status not null,
  remarks text,
  marked_by uuid references public.profiles(id),
  marked_at timestamptz not null default now(),
  unique (session_id, student_id)
);

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id),
  batch_id uuid not null references public.batches(id),
  subject_id uuid references public.subjects(id),
  title text not null,
  assessment_type text not null,
  held_on date not null,
  total_marks numeric(8,2) not null check (total_marks > 0),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.assessment_results (
  assessment_id uuid not null references public.assessments(id),
  student_id uuid not null references public.students(id),
  marks numeric(8,2) not null check (marks >= 0),
  remarks text,
  primary key (assessment_id, student_id)
);

create table public.fee_structures (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id),
  program_id uuid references public.programs(id),
  class_id uuid references public.classes(id),
  title text not null,
  amount numeric(12,2) not null check (amount >= 0),
  frequency text not null default 'MONTHLY',
  effective_from date not null,
  effective_to date
);

create table public.student_fee_assignments (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id),
  fee_structure_id uuid references public.fee_structures(id),
  amount numeric(12,2) not null check (amount >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  effective_from date not null,
  effective_to date
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  receipt_no text not null unique,
  student_id uuid not null references public.students(id),
  enrollment_id uuid references public.enrollments(id),
  amount numeric(12,2) not null check (amount > 0),
  payment_date date not null default current_date,
  method text not null default 'CASH',
  status public.payment_status not null default 'POSTED',
  notes text,
  collected_by uuid references public.profiles(id),
  voided_at timestamptz,
  voided_by uuid references public.profiles(id),
  void_reason text,
  created_at timestamptz not null default now()
);

create table public.weekly_monitoring (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  week_start date not null,
  homework_score numeric(5,2),
  participation_score numeric(5,2),
  test_score numeric(5,2),
  remarks text,
  recorded_by uuid references public.profiles(id),
  unique (student_id, week_start)
);

create table public.parent_communications (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  guardian_id uuid references public.guardians(id),
  communication_type text not null,
  occurred_at timestamptz not null default now(),
  notes text not null,
  next_follow_up date,
  recorded_by uuid references public.profiles(id)
);

create table public.notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null default 'ALL',
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  actor_id uuid,
  created_at timestamptz not null default now()
);

create table public.recovery_logs (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id text not null,
  reason text not null,
  snapshot jsonb,
  recovered_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(table_name, record_id, action, old_data, new_data, actor_id)
  values (tg_table_name, coalesce(new.id::text, old.id::text), tg_op,
    case when tg_op <> 'INSERT' then to_jsonb(old) end,
    case when tg_op <> 'DELETE' then to_jsonb(new) end,
    auth.uid());
  return coalesce(new, old);
end; $$;

create trigger audit_students after insert or update or delete on public.students for each row execute function public.audit_row_change();
create trigger audit_enrollments after insert or update or delete on public.enrollments for each row execute function public.audit_row_change();
create trigger audit_payments after insert or update on public.payments for each row execute function public.audit_row_change();

alter table public.attendance enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_results enable row level security;
alter table public.payments enable row level security;
alter table public.weekly_monitoring enable row level security;
alter table public.parent_communications enable row level security;
alter table public.notices enable row level security;
alter table public.audit_logs enable row level security;

create policy "staff attendance" on public.attendance for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER')) with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff assessments" on public.assessments for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER')) with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff results" on public.assessment_results for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER')) with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "finance staff payments" on public.payments for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR')) with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "staff monitoring" on public.weekly_monitoring for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER')) with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff communications" on public.parent_communications for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR','TEACHER')) with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "authenticated notices" on public.notices for select to authenticated using (published_at is not null);
create policy "staff notices" on public.notices for all to authenticated using (public.current_role() in ('ADMIN','OPERATOR')) with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "admin audit" on public.audit_logs for select to authenticated using (public.current_role() = 'ADMIN');

revoke delete on public.payments from authenticated;
revoke delete on public.audit_logs from authenticated;
