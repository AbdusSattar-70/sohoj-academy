-- ERP v2 CRM / Student Core verification. Safe to run after a clean reset.

do $$
begin
  if to_regclass('public.prospects') is null
     or to_regclass('public.prospect_followups') is null
     or to_regclass('public.students') is null
     or to_regclass('public.guardians') is null
     or to_regclass('public.batches') is null
     or to_regclass('public.enrollments') is null then
    raise exception 'CRM / Student Core tables are incomplete.';
  end if;

  if to_regprocedure('public.submit_public_interest(jsonb)') is null
     or to_regprocedure('public.generate_prospect_no()') is null
     or to_regprocedure('public.generate_student_no()') is null then
    raise exception 'CRM / Student Core functions are incomplete.';
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('anon','public.prospects','SELECT')
     or has_table_privilege('anon','public.prospects','INSERT')
     or has_table_privilege('anon','public.students','SELECT') then
    raise exception 'Anonymous API can access private CRM/student tables directly.';
  end if;

  if not has_function_privilege(
    'anon',
    'public.submit_public_interest(jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Public Interest RPC is not available to anonymous users.';
  end if;
end;
$$;

do $$
begin
  if exists (
    select student_no
    from public.students
    group by student_no
    having count(*) > 1
  ) then
    raise exception 'Duplicate permanent Student ID detected.';
  end if;

  if exists (
    select prospect_no
    from public.prospects
    group by prospect_no
    having count(*) > 1
  ) then
    raise exception 'Duplicate permanent Prospect ID detected.';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from public.batches b
    join lateral (
      select count(*)::integer as occupied
      from public.enrollments e
      where e.batch_id=b.id and e.status='ACTIVE'
    ) x on true
    where x.occupied>b.capacity
  ) then
    raise exception 'A batch exceeds its configured capacity.';
  end if;

  if exists (
    select 1 from public.batches where capacity>12
  ) then
    raise exception 'A batch exceeds the active academy policy maximum.';
  end if;
end;
$$;

select
  'PASS' as v2_crm_student_status,
  (select count(*) from public.prospects) as prospects,
  (select count(*) from public.students) as students,
  (select count(*) from public.batches) as batches,
  (select count(*) from public.enrollments where status='ACTIVE') as active_enrollments;
