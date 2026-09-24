-- Complete the staff-side operational security model and core business helpers.

create sequence if not exists public.receipt_number_seq start 1;

create or replace function public.generate_receipt_no()
returns text
language sql
as $$
  select 'SA-R-' || to_char(current_date, 'YYYY') || '-' ||
         lpad(nextval('public.receipt_number_seq')::text, 6, '0');
$$;

-- Master/operational tables were created before the full privilege matrix.
grant select, insert, update on public.academic_years, public.programs, public.classes,
  public.subjects, public.batches, public.classrooms, public.class_sessions,
  public.attendance, public.assessments, public.assessment_results,
  public.fee_structures, public.student_fee_assignments, public.payments,
  public.weekly_monitoring, public.parent_communications, public.notices,
  public.teachers, public.teacher_subjects, public.recovery_logs to authenticated;

grant select on public.audit_logs to authenticated;
grant usage, select on sequence public.receipt_number_seq to authenticated;

alter table public.academic_years enable row level security;
alter table public.programs enable row level security;
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.batches enable row level security;
alter table public.classrooms enable row level security;
alter table public.class_sessions enable row level security;
alter table public.fee_structures enable row level security;
alter table public.student_fee_assignments enable row level security;
alter table public.teachers enable row level security;
alter table public.teacher_subjects enable row level security;
alter table public.student_guardians enable row level security;
alter table public.recovery_logs enable row level security;

create policy "authenticated read academic years" on public.academic_years for select to authenticated using (true);
create policy "admin manage academic years" on public.academic_years for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "authenticated read programs" on public.programs for select to authenticated using (true);
create policy "admin manage programs" on public.programs for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "authenticated read classes" on public.classes for select to authenticated using (true);
create policy "admin manage classes" on public.classes for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "authenticated read subjects" on public.subjects for select to authenticated using (true);
create policy "admin manage subjects" on public.subjects for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "staff read batches" on public.batches for select to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "admin manage batches" on public.batches for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "staff classrooms" on public.classrooms for all to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
  with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "staff sessions" on public.class_sessions for all to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
  with check (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "staff read fee structures" on public.fee_structures for select to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "finance manage fee structures" on public.fee_structures for all to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR'))
  with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "staff read fee assignments" on public.student_fee_assignments for select to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "finance manage fee assignments" on public.student_fee_assignments for all to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR'))
  with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "staff read teachers" on public.teachers for select to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "admin manage teachers" on public.teachers for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "staff read teacher subjects" on public.teacher_subjects for select to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'));
create policy "admin manage teacher subjects" on public.teacher_subjects for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');
create policy "staff student guardian links" on public.student_guardians for all to authenticated
  using (public.current_role() in ('ADMIN','OPERATOR','TEACHER'))
  with check (public.current_role() in ('ADMIN','OPERATOR'));
create policy "admin recovery logs" on public.recovery_logs for all to authenticated
  using (public.current_role() = 'ADMIN') with check (public.current_role() = 'ADMIN');

-- Make admission truly complete: student + guardian + enrollment + fee assignment.
create or replace function public.create_admission(
  p_student jsonb,
  p_guardian jsonb,
  p_enrollment jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_student public.students;
  v_guardian public.guardians;
  v_enrollment public.enrollments;
  v_fee_assignment public.student_fee_assignments;
begin
  if public.current_role() not in ('ADMIN','OPERATOR') then
    raise exception 'Not authorized';
  end if;

  insert into public.students (name, name_bn, gender, date_of_birth, school_name, school_roll)
  values (
    p_student->>'name', nullif(p_student->>'name_bn',''), nullif(p_student->>'gender',''),
    nullif(p_student->>'date_of_birth','')::date, nullif(p_student->>'school_name',''),
    nullif(p_student->>'school_roll','')
  ) returning * into v_student;

  select * into v_guardian from public.guardians
  where mobile = p_guardian->>'mobile' order by created_at asc limit 1;

  if v_guardian.id is null then
    insert into public.guardians (name, mobile, alternate_mobile, address)
    values (p_guardian->>'name', p_guardian->>'mobile',
      nullif(p_guardian->>'alternate_mobile',''), nullif(p_guardian->>'address',''))
    returning * into v_guardian;
  end if;

  insert into public.student_guardians(student_id, guardian_id, relationship, is_primary)
  values (v_student.id, v_guardian.id, p_guardian->>'relationship', true);

  insert into public.enrollments (
    student_id, academic_year_id, class_id, batch_id, program_id,
    admission_date, monthly_fee, discount
  ) values (
    v_student.id, (p_enrollment->>'academic_year_id')::uuid,
    (p_enrollment->>'class_id')::uuid, nullif(p_enrollment->>'batch_id','')::uuid,
    nullif(p_enrollment->>'program_id','')::uuid,
    (p_enrollment->>'admission_date')::date,
    coalesce((p_enrollment->>'monthly_fee')::numeric,0),
    coalesce((p_enrollment->>'discount')::numeric,0)
  ) returning * into v_enrollment;

  insert into public.student_fee_assignments (
    enrollment_id, amount, discount, effective_from
  ) values (
    v_enrollment.id, v_enrollment.monthly_fee, v_enrollment.discount,
    v_enrollment.admission_date
  ) returning * into v_fee_assignment;

  return jsonb_build_object(
    'student_id', v_student.id, 'student_no', v_student.student_no,
    'guardian_id', v_guardian.id, 'enrollment_id', v_enrollment.id,
    'fee_assignment_id', v_fee_assignment.id
  );
end;
$$;
