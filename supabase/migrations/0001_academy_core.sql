create extension if not exists pgcrypto;

create type public.app_role as enum ('ADMIN','OPERATOR','TEACHER','GUARDIAN','STUDENT');
create type public.student_status as enum ('ACTIVE','INACTIVE','GRADUATED','WITHDRAWN');

create sequence if not exists public.student_number_seq start 1;

create or replace function public.generate_student_no()
returns text language sql as $$
  select 'SA-' || lpad(nextval('public.student_number_seq')::text, 6, '0');
$$;

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null default 0
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  is_active boolean not null default true
);

create table public.batches (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  program_id uuid references public.programs(id),
  name text not null,
  capacity integer not null default 12 check (capacity > 0),
  is_active boolean not null default true,
  unique (academic_year_id, class_id, name)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  student_no text not null unique default public.generate_student_no(),
  name text not null,
  name_bn text,
  gender text,
  date_of_birth date,
  school_name text,
  school_roll text,
  status public.student_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mobile text not null,
  alternate_mobile text,
  address text,
  created_at timestamptz not null default now()
);

create table public.student_guardians (
  student_id uuid not null references public.students(id),
  guardian_id uuid not null references public.guardians(id),
  relationship text not null,
  is_primary boolean not null default false,
  primary key (student_id, guardian_id)
);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  academic_year_id uuid not null references public.academic_years(id),
  class_id uuid not null references public.classes(id),
  batch_id uuid references public.batches(id),
  program_id uuid references public.programs(id),
  admission_date date not null default current_date,
  monthly_fee numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  effective_fee numeric(12,2) generated always as (greatest(monthly_fee - discount, 0)) stored,
  is_active boolean not null default true,
  unique (student_id, academic_year_id)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.app_role not null,
  student_id uuid references public.students(id),
  guardian_id uuid references public.guardians(id),
  created_at timestamptz not null default now()
);

create table public.teachers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id),
  name text not null,
  mobile text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.teacher_subjects (
  teacher_id uuid not null references public.teachers(id),
  subject_id uuid not null references public.subjects(id),
  primary key (teacher_id, subject_id)
);

create index students_student_no_idx on public.students(student_no);
create index enrollments_batch_idx on public.enrollments(batch_id);
create index guardians_mobile_idx on public.guardians(mobile);

alter table public.students enable row level security;
alter table public.guardians enable row level security;
alter table public.enrollments enable row level security;
alter table public.profiles enable row level security;

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid(); $$;

create policy "staff read students" on public.students for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff manage students" on public.students for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "users read own profile" on public.profiles for select to authenticated
using (id = auth.uid() or public.current_role() = 'ADMIN');

create policy "staff read enrollments" on public.enrollments for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff manage enrollments" on public.enrollments for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));

create policy "staff read guardians" on public.guardians for select to authenticated
using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));

create policy "staff manage guardians" on public.guardians for all to authenticated
using (public.current_role() in ('ADMIN','OPERATOR'))
with check (public.current_role() in ('ADMIN','OPERATOR'));
