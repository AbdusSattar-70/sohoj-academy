-- Sohoj Academy ERP production-hardening verification.
-- Safe to run in Supabase SQL Editor after migrations are applied.
-- This script is read-only except for temporary procedural assertions.

do $$
begin
  if to_regprocedure('public.save_attendance(uuid,jsonb)') is null then
    raise exception 'Missing hardened save_attendance(uuid,jsonb).';
  end if;

  if to_regprocedure('public.save_assessment_results(uuid,jsonb)') is null then
    raise exception 'Missing hardened save_assessment_results(uuid,jsonb).';
  end if;

  if to_regprocedure('public.post_payment(uuid,uuid,numeric,date,text,text,uuid)') is null then
    raise exception 'Missing post_payment idempotent financial RPC.';
  end if;

  if to_regclass('public.payment_posting_keys') is null then
    raise exception 'Missing payment_posting_keys table.';
  end if;
end;
$$;

-- Official attendance/results/payments must not be directly writable by the
-- authenticated API role. Controlled security-definer workflows own writes.
do $$
begin
  if has_table_privilege('authenticated', 'public.attendance', 'INSERT')
     or has_table_privilege('authenticated', 'public.attendance', 'UPDATE')
     or has_table_privilege('authenticated', 'public.attendance', 'DELETE') then
    raise exception 'authenticated still has direct attendance write privilege.';
  end if;

  if has_table_privilege('authenticated', 'public.assessment_results', 'INSERT')
     or has_table_privilege('authenticated', 'public.assessment_results', 'UPDATE')
     or has_table_privilege('authenticated', 'public.assessment_results', 'DELETE') then
    raise exception 'authenticated still has direct assessment-result write privilege.';
  end if;

  if has_table_privilege('authenticated', 'public.payments', 'INSERT')
     or has_table_privilege('authenticated', 'public.payments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.payments', 'DELETE') then
    raise exception 'authenticated still has direct payment write privilege.';
  end if;
end;
$$;

-- No active batch may exceed its configured capacity.
do $$
begin
  if exists (
    select 1
    from public.batches b
    join lateral (
      select count(*)::integer as occupied
      from public.enrollments e
      where e.batch_id = b.id
        and e.is_active
    ) x on true
    where x.occupied > b.capacity
  ) then
    raise exception 'At least one batch is currently over capacity.';
  end if;
end;
$$;

-- Attendance must only exist for students actively enrolled in the session batch.
do $$
begin
  if exists (
    select 1
    from public.attendance a
    join public.class_sessions s on s.id = a.session_id
    where not exists (
      select 1
      from public.enrollments e
      where e.student_id = a.student_id
        and e.batch_id = s.batch_id
        and e.is_active
    )
  ) then
    raise exception 'Attendance contains a student outside the active session roster.';
  end if;
end;
$$;

-- Assessment results must only exist for active students in the assessment batch.
do $$
begin
  if exists (
    select 1
    from public.assessment_results r
    join public.assessments a on a.id = r.assessment_id
    where not exists (
      select 1
      from public.enrollments e
      where e.student_id = r.student_id
        and e.batch_id = a.batch_id
        and e.is_active
    )
  ) then
    raise exception 'Assessment results contain a student outside the active assessment roster.';
  end if;
end;
$$;

-- Maker-checker: an approved request cannot be approved by its submitter.
do $$
begin
  if exists (
    select 1
    from public.approval_requests
    where status = 'APPROVED'
      and decided_by = requested_by
  ) then
    raise exception 'Maker-checker violation: submitter also approved a request.';
  end if;
end;
$$;

-- Pending academic finalisation requests must snapshot a complete roster.
do $$
begin
  if exists (
    select 1
    from public.approval_requests
    where workflow_type in (
      'ATTENDANCE_FINALIZATION',
      'ASSESSMENT_RESULTS_FINALIZATION'
    )
      and status = 'PENDING'
      and payload_snapshot is null
  ) then
    raise exception 'A pending academic approval is missing its immutable submission snapshot.';
  end if;
end;
$$;

-- Human-friendly identities must remain unique.
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
    raise exception 'Duplicate Prospect ID detected.';
  end if;

  if exists (
    select receipt_no
    from public.payments
    group by receipt_no
    having count(*) > 1
  ) then
    raise exception 'Duplicate payment receipt detected.';
  end if;
end;
$$;

select
  'PASS' as production_hardening_status,
  (select count(*) from public.students) as students,
  (select count(*) from public.prospects) as prospects,
  (select count(*) from public.payments) as payments,
  (select count(*) from public.audit_events) as audit_events,
  (select count(*) from public.approval_requests) as approval_requests;
