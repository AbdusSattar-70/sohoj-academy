-- ERP v2 Staff workflow verification.

do $$
begin
  if to_regclass('public.staff_subject_assignments') is null then
    raise exception 'Staff subject assignment table is missing.';
  end if;

  if to_regprocedure('public.create_staff_member(jsonb)') is null then
    raise exception 'Create Staff workflow RPC is missing.';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from public.staff_roles
    where code='TEACHER'
      and is_teaching_role
      and is_active
  ) then
    raise exception 'Teaching Staff role is not configured correctly.';
  end if;

  if exists (
    select 1
    from public.staff_subject_assignments ssa
    where ssa.effective_to is null
      and not exists (
        select 1
        from public.staff_role_assignments sra
        join public.staff_roles sr on sr.id=sra.staff_role_id
        where sra.staff_id=ssa.staff_id
          and sr.is_teaching_role
          and sra.effective_from<=current_date
          and (sra.effective_to is null or sra.effective_to>=current_date)
      )
  ) then
    raise exception 'A teaching-subject assignment exists without an active teaching role.';
  end if;
end;
$$;

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
    from public.staff_role_assignments
    where is_primary and effective_to is null
    group by staff_id
    having count(*) > 1
  ) then
    raise exception 'A Staff identity has multiple open primary roles.';
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('authenticated','public.staff','DELETE')
     or has_table_privilege('authenticated','public.staff_role_assignments','DELETE')
     or has_table_privilege('authenticated','public.staff_subject_assignments','DELETE') then
    raise exception 'Authenticated API still has destructive Staff delete privileges.';
  end if;
end;
$$;

select
  'PASS' as v2_staff_status,
  (select count(*) from public.staff) as staff_identities,
  (select count(*) from public.staff_role_assignments where effective_to is null) as active_role_assignments,
  (select count(*) from public.staff_subject_assignments where effective_to is null) as active_subject_assignments;
