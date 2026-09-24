create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1), 'User'),
    case
      when lower(new.email) = lower(current_setting('app.bootstrap_admin_email', true)) then 'ADMIN'::public.app_role
      else 'STUDENT'::public.app_role
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

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
begin
  if public.current_role() not in ('ADMIN','OPERATOR') then
    raise exception 'Not authorized';
  end if;

  insert into public.students (
    name, name_bn, gender, date_of_birth, school_name, school_roll
  ) values (
    p_student->>'name',
    nullif(p_student->>'name_bn',''),
    nullif(p_student->>'gender',''),
    nullif(p_student->>'date_of_birth','')::date,
    nullif(p_student->>'school_name',''),
    nullif(p_student->>'school_roll','')
  )
  returning * into v_student;

  select * into v_guardian
  from public.guardians
  where mobile = p_guardian->>'mobile'
  order by created_at asc
  limit 1;

  if v_guardian.id is null then
    insert into public.guardians (name, mobile, alternate_mobile, address)
    values (
      p_guardian->>'name',
      p_guardian->>'mobile',
      nullif(p_guardian->>'alternate_mobile',''),
      nullif(p_guardian->>'address','')
    )
    returning * into v_guardian;
  end if;

  insert into public.student_guardians (student_id, guardian_id, relationship, is_primary)
  values (
    v_student.id,
    v_guardian.id,
    p_guardian->>'relationship',
    true
  );

  insert into public.enrollments (
    student_id, academic_year_id, class_id, batch_id, program_id,
    admission_date, monthly_fee, discount
  ) values (
    v_student.id,
    (p_enrollment->>'academic_year_id')::uuid,
    (p_enrollment->>'class_id')::uuid,
    nullif(p_enrollment->>'batch_id','')::uuid,
    nullif(p_enrollment->>'program_id','')::uuid,
    coalesce(nullif(p_enrollment->>'admission_date','')::date, current_date),
    coalesce((p_enrollment->>'monthly_fee')::numeric, 0),
    coalesce((p_enrollment->>'discount')::numeric, 0)
  )
  returning * into v_enrollment;

  return jsonb_build_object(
    'student_id', v_student.id,
    'student_no', v_student.student_no,
    'guardian_id', v_guardian.id,
    'enrollment_id', v_enrollment.id
  );
end;
$$;

grant execute on function public.create_admission(jsonb,jsonb,jsonb) to authenticated;

create policy "student reads self" on public.students
for select to authenticated
using (
  id = (select student_id from public.profiles where id = auth.uid())
);

create policy "guardian reads linked students" on public.students
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    join public.student_guardians sg on sg.guardian_id = p.guardian_id
    where p.id = auth.uid() and sg.student_id = students.id
  )
);

create policy "student reads own enrollment" on public.enrollments
for select to authenticated
using (
  student_id = (select student_id from public.profiles where id = auth.uid())
);

create policy "guardian reads linked enrollments" on public.enrollments
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    join public.student_guardians sg on sg.guardian_id = p.guardian_id
    where p.id = auth.uid() and sg.student_id = enrollments.student_id
  )
);

create policy "guardian reads own guardian record" on public.guardians
for select to authenticated
using (
  id = (select guardian_id from public.profiles where id = auth.uid())
);
