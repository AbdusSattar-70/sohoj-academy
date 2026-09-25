-- Admission hardening: canonical School master data and workflow correlation.

-- Make database-trigger audit events join a workflow correlation when the
-- caller sets app.correlation_id for the current transaction.
create or replace function public.audit_critical_business_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_old jsonb;
  v_new jsonb;
  v_entity_id text;
  v_role public.app_role;
  v_correlation_id uuid;
  v_correlation_setting text;
begin
  v_old := case when tg_op <> 'INSERT' then to_jsonb(old) else null end;
  v_new := case when tg_op <> 'DELETE' then to_jsonb(new) else null end;
  v_row := coalesce(v_new, v_old, '{}'::jsonb);

  v_entity_id := coalesce(
    v_row->>'id',
    case
      when v_row ? 'assessment_id' and v_row ? 'student_id'
        then (v_row->>'assessment_id') || ':' || (v_row->>'student_id')
      else null
    end,
    'unknown'
  );

  select role into v_role
  from public.profiles
  where id = auth.uid();

  v_correlation_setting := nullif(current_setting('app.correlation_id', true), '');
  if v_correlation_setting is not null then
    begin
      v_correlation_id := v_correlation_setting::uuid;
    exception when others then
      v_correlation_id := gen_random_uuid();
    end;
  else
    v_correlation_id := gen_random_uuid();
  end if;

  insert into public.audit_events (
    correlation_id,
    actor_id,
    actor_role,
    entity_type,
    entity_id,
    action,
    before_data,
    after_data,
    metadata
  )
  values (
    v_correlation_id,
    auth.uid(),
    v_role,
    upper(tg_table_name),
    v_entity_id,
    tg_op,
    v_old,
    v_new,
    jsonb_build_object('source', 'DATABASE_TRIGGER')
  );

  return coalesce(new, old);
end;
$$;

create or replace function public.create_admission(
  p_student jsonb,
  p_guardian jsonb,
  p_enrollment jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role public.app_role;
  v_student public.students;
  v_guardian public.guardians;
  v_enrollment public.enrollments;
  v_fee_assignment public.student_fee_assignments;
  v_school public.schools;
  v_school_id uuid;
  v_school_snapshot text;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user;

  if v_role not in ('ADMIN','OPERATOR') then
    raise exception 'Not authorized';
  end if;

  perform set_config('app.correlation_id', v_correlation_id::text, true);

  v_school_snapshot := nullif(
    btrim(coalesce(
      p_student->>'school_name_snapshot',
      p_student->>'school_name',
      ''
    )),
    ''
  );

  if nullif(p_student->>'school_id','') is not null then
    begin
      v_school_id := (p_student->>'school_id')::uuid;
    exception when others then
      raise exception 'Invalid School selection.';
    end;

    select *
      into v_school
    from public.schools
    where id = v_school_id
      and is_active;

    if v_school.id is null then
      raise exception 'Selected School is not available.';
    end if;

    v_school_snapshot := coalesce(v_school_snapshot, v_school.name);
  elsif v_school_snapshot is not null then
    select *
      into v_school
    from public.schools
    where lower(btrim(name)) = lower(v_school_snapshot)
    order by created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools (
        name,
        is_active,
        created_by
      )
      values (
        v_school_snapshot,
        true,
        v_user
      )
      on conflict do nothing;

      select *
        into v_school
      from public.schools
      where lower(btrim(name)) = lower(v_school_snapshot)
      order by created_at asc
      limit 1;
    end if;

    v_school_id := v_school.id;
    v_school_snapshot := v_school.name;
  end if;

  insert into public.students (
    name,
    name_bn,
    gender,
    date_of_birth,
    school_id,
    school_name,
    school_roll
  )
  values (
    btrim(p_student->>'name'),
    nullif(btrim(coalesce(p_student->>'name_bn','')), ''),
    nullif(btrim(coalesce(p_student->>'gender','')), ''),
    nullif(p_student->>'date_of_birth','')::date,
    v_school_id,
    v_school_snapshot,
    nullif(btrim(coalesce(p_student->>'school_roll','')), '')
  )
  returning * into v_student;

  select *
    into v_guardian
  from public.guardians
  where regexp_replace(mobile, '\D', '', 'g')
      = regexp_replace(p_guardian->>'mobile', '\D', '', 'g')
  order by created_at asc
  limit 1;

  if v_guardian.id is null then
    insert into public.guardians (
      name,
      mobile,
      alternate_mobile,
      address
    )
    values (
      btrim(p_guardian->>'name'),
      btrim(p_guardian->>'mobile'),
      nullif(btrim(coalesce(p_guardian->>'alternate_mobile','')), ''),
      nullif(btrim(coalesce(p_guardian->>'address','')), '')
    )
    returning * into v_guardian;
  end if;

  insert into public.student_guardians (
    student_id,
    guardian_id,
    relationship,
    is_primary
  )
  values (
    v_student.id,
    v_guardian.id,
    btrim(p_guardian->>'relationship'),
    true
  );

  insert into public.enrollments (
    student_id,
    academic_year_id,
    class_id,
    batch_id,
    program_id,
    admission_date,
    monthly_fee,
    discount
  )
  values (
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

  insert into public.student_fee_assignments (
    enrollment_id,
    amount,
    discount,
    effective_from
  )
  values (
    v_enrollment.id,
    v_enrollment.monthly_fee,
    v_enrollment.discount,
    v_enrollment.admission_date
  )
  returning * into v_fee_assignment;

  insert into public.audit_events (
    correlation_id,
    actor_id,
    actor_role,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values (
    v_correlation_id,
    v_user,
    v_role,
    'ADMISSION',
    v_enrollment.id::text,
    'CREATE',
    jsonb_build_object(
      'student_id', v_student.id,
      'student_no', v_student.student_no,
      'guardian_id', v_guardian.id,
      'enrollment_id', v_enrollment.id,
      'fee_assignment_id', v_fee_assignment.id,
      'school_id', v_school_id
    ),
    jsonb_build_object('workflow', 'CREATE_ADMISSION')
  );

  return jsonb_build_object(
    'student_id', v_student.id,
    'student_no', v_student.student_no,
    'guardian_id', v_guardian.id,
    'enrollment_id', v_enrollment.id,
    'fee_assignment_id', v_fee_assignment.id,
    'school_id', v_school_id,
    'correlation_id', v_correlation_id
  );
end;
$$;

revoke all on function public.create_admission(jsonb,jsonb,jsonb) from public;
grant execute on function public.create_admission(jsonb,jsonb,jsonb) to authenticated;
