-- Sohoj Academy Staff foundation verification.
-- Run after 0015_staff_identity.sql is applied.

do $$
begin
  if to_regclass('public.staff') is null then
    raise exception 'Missing canonical staff table.';
  end if;

  if to_regclass('public.staff_employments') is null then
    raise exception 'Missing staff_employments table.';
  end if;

  if to_regclass('public.staff_role_assignments') is null then
    raise exception 'Missing staff_role_assignments table.';
  end if;

  if to_regclass('public.staff_subject_assignments') is null then
    raise exception 'Missing staff_subject_assignments table.';
  end if;

  if to_regprocedure('public.create_staff_member(jsonb)') is null then
    raise exception 'Missing create_staff_member(jsonb) RPC.';
  end if;
end;
$$;

-- Every legacy Teacher must have exactly one canonical Staff identity using the
-- same UUID so historical class_session teacher references remain stable.
do $$
begin
  if exists (
    select 1
    from public.teachers t
    left join public.staff s on s.id = t.staff_id
    where t.staff_id is null
       or s.id is null
       or t.id <> t.staff_id
  ) then
    raise exception 'Legacy Teacher is missing a matching Staff identity.';
  end if;
end;
$$;

-- Existing Teachers must have an open Teacher role assignment.
do $$
begin
  if exists (
    select 1
    from public.teachers t
    where not exists (
      select 1
      from public.staff_role_assignments ra
      join public.staff_role_catalog rc on rc.id = ra.role_id
      where ra.staff_id = t.staff_id
        and rc.code = 'TEACHER'
        and ra.effective_to is null
    )
  ) then
    raise exception 'A legacy Teacher is missing an active Teacher role assignment.';
  end if;
end;
$$;

-- Legacy teacher_subjects must be represented in canonical staff assignments.
do $$
begin
  if exists (
    select 1
    from public.teacher_subjects ts
    join public.teachers t on t.id = ts.teacher_id
    where not exists (
      select 1
      from public.staff_subject_assignments sa
      where sa.staff_id = t.staff_id
        and sa.subject_id = ts.subject_id
        and sa.effective_to is null
    )
  ) then
    raise exception 'A legacy Teacher subject is missing from canonical Staff subjects.';
  end if;
end;
$$;

-- Canonical Staff subject assignments must only belong to an active Teacher role.
do $$
begin
  if exists (
    select 1
    from public.staff_subject_assignments sa
    where sa.effective_to is null
      and not exists (
        select 1
        from public.staff_role_assignments ra
        join public.staff_role_catalog rc on rc.id = ra.role_id
        where ra.staff_id = sa.staff_id
          and rc.code = 'TEACHER'
          and ra.effective_to is null
      )
  ) then
    raise exception 'A Staff subject assignment exists without an active Teacher role.';
  end if;
end;
$$;

-- Session compatibility must remain consistent during the gradual migration.
do $$
begin
  if exists (
    select 1
    from public.class_sessions
    where teacher_id is distinct from staff_id
      and (teacher_id is not null or staff_id is not null)
  ) then
    raise exception 'Class session teacher/staff identities are inconsistent.';
  end if;
end;
$$;

-- Permanent Staff IDs and current employment/primary-role rules must be unique.
do $$
begin
  if exists (
    select staff_no
    from public.staff
    group by staff_no
    having count(*) > 1
  ) then
    raise exception 'Duplicate permanent Staff ID detected.';
  end if;

  if exists (
    select staff_id
    from public.staff_employments
    where status in ('ACTIVE','ON_LEAVE')
      and ends_on is null
    group by staff_id
    having count(*) > 1
  ) then
    raise exception 'A staff member has multiple open employments.';
  end if;

  if exists (
    select staff_id
    from public.staff_role_assignments
    where is_primary
      and effective_to is null
    group by staff_id
    having count(*) > 1
  ) then
    raise exception 'A staff member has multiple open primary roles.';
  end if;
end;
$$;

-- Legacy Teacher tables are compatibility bridges, not normal write APIs.
do $$
begin
  if has_table_privilege('authenticated','public.teachers','INSERT')
     or has_table_privilege('authenticated','public.teachers','UPDATE')
     or has_table_privilege('authenticated','public.teachers','DELETE') then
    raise exception 'authenticated can still directly mutate legacy teachers.';
  end if;

  if has_table_privilege('authenticated','public.teacher_subjects','INSERT')
     or has_table_privilege('authenticated','public.teacher_subjects','UPDATE')
     or has_table_privilege('authenticated','public.teacher_subjects','DELETE') then
    raise exception 'authenticated can still directly mutate legacy teacher_subjects.';
  end if;
end;
$$;

select
  'PASS' as staff_foundation_status,
  (select count(*) from public.staff) as staff_identities,
  (select count(*) from public.teachers) as legacy_teacher_bridges,
  (select count(*) from public.staff_role_assignments where effective_to is null) as active_role_assignments,
  (select count(*) from public.staff_subject_assignments where effective_to is null) as active_subject_assignments;
