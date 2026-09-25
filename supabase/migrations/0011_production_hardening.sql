-- Production hardening: approval-gated academic finalisation, roster integrity,
-- immutable audit events, and removal of direct final-record writes.
--
-- This migration intentionally reuses the generic approval_requests/audit_events
-- foundation introduced in 0009_erp_foundation.sql so future workflows can share
-- the same approval and traceability model.

-- ---------------------------------------------------------------------------
-- 1. Harden attendance writes.
-- ---------------------------------------------------------------------------

create or replace function public.save_attendance(
  p_session_id uuid,
  p_entries jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role public.app_role;
  v_session public.class_sessions;
  v_latest_status public.approval_status;
  v_entry jsonb;
  v_student_id uuid;
  v_count integer := 0;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user;

  if v_role not in ('ADMIN','OPERATOR','TEACHER') then
    raise exception 'Not authorized';
  end if;

  select * into v_session
  from public.class_sessions
  where id = p_session_id;

  if v_session.id is null then
    raise exception 'Class session not found';
  end if;

  select ar.status
    into v_latest_status
  from public.approval_requests ar
  where ar.workflow_type = 'ATTENDANCE_FINALIZATION'
    and ar.entity_type = 'CLASS_SESSION'
    and ar.entity_id = p_session_id::text
  order by ar.requested_at desc
  limit 1;

  if v_latest_status = 'PENDING' then
    raise exception 'Attendance is awaiting approval and cannot be changed.';
  elsif v_latest_status = 'APPROVED' then
    raise exception 'Approved attendance is final. Use a controlled correction workflow.';
  end if;

  if jsonb_typeof(coalesce(p_entries, '[]'::jsonb)) <> 'array' then
    raise exception 'Attendance entries must be an array.';
  end if;

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    begin
      v_student_id := (v_entry->>'student_id')::uuid;
    exception when others then
      raise exception 'Invalid student identity in attendance payload.';
    end;

    if not exists (
      select 1
      from public.enrollments e
      where e.student_id = v_student_id
        and e.batch_id = v_session.batch_id
        and e.is_active
    ) then
      raise exception 'Student % is not actively enrolled in this session batch.', v_student_id;
    end if;

    select to_jsonb(a)
      into v_before
    from public.attendance a
    where a.session_id = p_session_id
      and a.student_id = v_student_id;

    insert into public.attendance (
      session_id,
      student_id,
      status,
      remarks,
      marked_by,
      marked_at
    )
    values (
      p_session_id,
      v_student_id,
      (v_entry->>'status')::public.attendance_status,
      nullif(btrim(coalesce(v_entry->>'remarks','')), ''),
      v_user,
      now()
    )
    on conflict (session_id, student_id)
    do update set
      status = excluded.status,
      remarks = excluded.remarks,
      marked_by = excluded.marked_by,
      marked_at = now();

    select to_jsonb(a)
      into v_after
    from public.attendance a
    where a.session_id = p_session_id
      and a.student_id = v_student_id;

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
      v_user,
      v_role,
      'ATTENDANCE',
      p_session_id::text || ':' || v_student_id::text,
      case when v_before is null then 'DRAFT_CREATE' else 'DRAFT_UPDATE' end,
      v_before,
      v_after,
      jsonb_build_object('session_id', p_session_id, 'student_id', v_student_id)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke insert, update, delete on public.attendance from authenticated;
grant execute on function public.save_attendance(uuid,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Harden assessment-result writes.
-- ---------------------------------------------------------------------------

create or replace function public.save_assessment_results(
  p_assessment_id uuid,
  p_entries jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role public.app_role;
  v_assessment public.assessments;
  v_latest_status public.approval_status;
  v_entry jsonb;
  v_student_id uuid;
  v_marks numeric;
  v_count integer := 0;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user;

  if v_role not in ('ADMIN','OPERATOR','TEACHER') then
    raise exception 'Not authorized';
  end if;

  select * into v_assessment
  from public.assessments
  where id = p_assessment_id;

  if v_assessment.id is null then
    raise exception 'Assessment not found';
  end if;

  select ar.status
    into v_latest_status
  from public.approval_requests ar
  where ar.workflow_type = 'ASSESSMENT_RESULTS_FINALIZATION'
    and ar.entity_type = 'ASSESSMENT'
    and ar.entity_id = p_assessment_id::text
  order by ar.requested_at desc
  limit 1;

  if v_latest_status = 'PENDING' then
    raise exception 'Results are awaiting approval and cannot be changed.';
  elsif v_latest_status = 'APPROVED' then
    raise exception 'Approved results are final. Use a controlled correction workflow.';
  end if;

  if jsonb_typeof(coalesce(p_entries, '[]'::jsonb)) <> 'array' then
    raise exception 'Result entries must be an array.';
  end if;

  for v_entry in
    select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    begin
      v_student_id := (v_entry->>'student_id')::uuid;
      v_marks := (v_entry->>'marks')::numeric;
    exception when others then
      raise exception 'Invalid student or marks value in result payload.';
    end;

    if v_marks < 0 or v_marks > v_assessment.total_marks then
      raise exception 'Marks must be between 0 and %', v_assessment.total_marks;
    end if;

    if not exists (
      select 1
      from public.enrollments e
      where e.student_id = v_student_id
        and e.batch_id = v_assessment.batch_id
        and e.is_active
    ) then
      raise exception 'Student % is not actively enrolled in this assessment batch.', v_student_id;
    end if;

    select to_jsonb(r)
      into v_before
    from public.assessment_results r
    where r.assessment_id = p_assessment_id
      and r.student_id = v_student_id;

    insert into public.assessment_results (
      assessment_id,
      student_id,
      marks,
      remarks
    )
    values (
      p_assessment_id,
      v_student_id,
      v_marks,
      nullif(btrim(coalesce(v_entry->>'remarks','')), '')
    )
    on conflict (assessment_id, student_id)
    do update set
      marks = excluded.marks,
      remarks = excluded.remarks;

    select to_jsonb(r)
      into v_after
    from public.assessment_results r
    where r.assessment_id = p_assessment_id
      and r.student_id = v_student_id;

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
      v_user,
      v_role,
      'ASSESSMENT_RESULT',
      p_assessment_id::text || ':' || v_student_id::text,
      case when v_before is null then 'DRAFT_CREATE' else 'DRAFT_UPDATE' end,
      v_before,
      v_after,
      jsonb_build_object('assessment_id', p_assessment_id, 'student_id', v_student_id)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke insert, update, delete on public.assessment_results from authenticated;
grant execute on function public.save_assessment_results(uuid,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Validate approval submissions and freeze exact snapshots.
-- ---------------------------------------------------------------------------

create or replace function public.validate_academic_finalization_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.app_role;
  v_entity_uuid uuid;
  v_batch_id uuid;
  v_expected integer;
  v_actual integer;
begin
  if new.workflow_type not in (
    'ATTENDANCE_FINALIZATION',
    'ASSESSMENT_RESULTS_FINALIZATION'
  ) then
    return new;
  end if;

  if auth.uid() is null or new.requested_by <> auth.uid() then
    raise exception 'Approval request actor mismatch.';
  end if;

  select role into v_role
  from public.profiles
  where id = auth.uid();

  if v_role not in ('ADMIN','OPERATOR','TEACHER') then
    raise exception 'Not authorized to submit this workflow.';
  end if;

  begin
    v_entity_uuid := new.entity_id::uuid;
  exception when others then
    raise exception 'Invalid workflow entity identity.';
  end;

  if new.workflow_type = 'ATTENDANCE_FINALIZATION' then
    if new.entity_type <> 'CLASS_SESSION' then
      raise exception 'Attendance approval must target a class session.';
    end if;

    select batch_id into v_batch_id
    from public.class_sessions
    where id = v_entity_uuid;

    if v_batch_id is null then
      raise exception 'Class session not found.';
    end if;

    select count(*) into v_expected
    from public.enrollments
    where batch_id = v_batch_id
      and is_active;

    select count(*) into v_actual
    from public.attendance
    where session_id = v_entity_uuid;

    if v_expected = 0 then
      raise exception 'The selected session batch has no active students.';
    end if;

    if v_actual <> v_expected then
      raise exception 'Attendance is incomplete: % of % students are marked.', v_actual, v_expected;
    end if;

    new.payload_snapshot := jsonb_build_object(
      'session_id', v_entity_uuid,
      'student_count', v_expected,
      'attendance',
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'student_id', a.student_id,
              'status', a.status,
              'remarks', a.remarks,
              'marked_by', a.marked_by,
              'marked_at', a.marked_at
            )
            order by a.student_id
          ),
          '[]'::jsonb
        )
        from public.attendance a
        where a.session_id = v_entity_uuid
      )
    );
  else
    if new.entity_type <> 'ASSESSMENT' then
      raise exception 'Result approval must target an assessment.';
    end if;

    select batch_id into v_batch_id
    from public.assessments
    where id = v_entity_uuid;

    if v_batch_id is null then
      raise exception 'Assessment not found.';
    end if;

    select count(*) into v_expected
    from public.enrollments
    where batch_id = v_batch_id
      and is_active;

    select count(*) into v_actual
    from public.assessment_results
    where assessment_id = v_entity_uuid;

    if v_expected = 0 then
      raise exception 'The assessment batch has no active students.';
    end if;

    if v_actual <> v_expected then
      raise exception 'Results are incomplete: % of % students have marks.', v_actual, v_expected;
    end if;

    new.payload_snapshot := jsonb_build_object(
      'assessment_id', v_entity_uuid,
      'student_count', v_expected,
      'results',
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'student_id', r.student_id,
              'marks', r.marks,
              'remarks', r.remarks
            )
            order by r.student_id
          ),
          '[]'::jsonb
        )
        from public.assessment_results r
        where r.assessment_id = v_entity_uuid
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists validate_academic_finalization_request_trigger
on public.approval_requests;

create trigger validate_academic_finalization_request_trigger
before insert on public.approval_requests
for each row
execute function public.validate_academic_finalization_request();

-- ---------------------------------------------------------------------------
-- 4. Audit approval lifecycle changes.
-- ---------------------------------------------------------------------------

create or replace function public.audit_approval_request_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.app_role;
begin
  select role into v_role
  from public.profiles
  where id = auth.uid();

  if tg_op = 'INSERT' then
    insert into public.audit_events (
      correlation_id,
      actor_id,
      actor_role,
      entity_type,
      entity_id,
      action,
      after_data,
      reason,
      metadata
    )
    values (
      new.correlation_id,
      auth.uid(),
      v_role,
      new.entity_type,
      new.entity_id,
      'SUBMIT_FOR_APPROVAL',
      to_jsonb(new),
      new.request_note,
      jsonb_build_object(
        'workflow_type', new.workflow_type,
        'approval_request_id', new.id
      )
    );
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.audit_events (
      correlation_id,
      actor_id,
      actor_role,
      entity_type,
      entity_id,
      action,
      before_data,
      after_data,
      reason,
      metadata
    )
    values (
      new.correlation_id,
      auth.uid(),
      v_role,
      new.entity_type,
      new.entity_id,
      case new.status
        when 'APPROVED' then 'APPROVE'
        when 'REJECTED' then 'REJECT'
        when 'CANCELLED' then 'CANCEL_APPROVAL'
        else 'APPROVAL_STATUS_CHANGE'
      end,
      to_jsonb(old),
      to_jsonb(new),
      new.decision_note,
      jsonb_build_object(
        'workflow_type', new.workflow_type,
        'approval_request_id', new.id
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists audit_approval_request_insert_trigger
on public.approval_requests;
drop trigger if exists audit_approval_request_update_trigger
on public.approval_requests;

create trigger audit_approval_request_insert_trigger
after insert on public.approval_requests
for each row
execute function public.audit_approval_request_change();

create trigger audit_approval_request_update_trigger
after update on public.approval_requests
for each row
execute function public.audit_approval_request_change();

-- ---------------------------------------------------------------------------
-- 5. Add audit_events coverage for critical money/admission records.
--    audit_logs remains legacy-compatible for now; audit_events is the canonical
--    business audit stream going forward.
-- ---------------------------------------------------------------------------

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

  insert into public.audit_events (
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

drop trigger if exists audit_event_students on public.students;
drop trigger if exists audit_event_enrollments on public.enrollments;
drop trigger if exists audit_event_payments on public.payments;
drop trigger if exists audit_event_weekly_monitoring on public.weekly_monitoring;
drop trigger if exists audit_event_parent_communications on public.parent_communications;

create trigger audit_event_students
after insert or update on public.students
for each row execute function public.audit_critical_business_row();

create trigger audit_event_enrollments
after insert or update on public.enrollments
for each row execute function public.audit_critical_business_row();

create trigger audit_event_payments
after insert or update on public.payments
for each row execute function public.audit_critical_business_row();

create trigger audit_event_weekly_monitoring
after insert or update on public.weekly_monitoring
for each row execute function public.audit_critical_business_row();

create trigger audit_event_parent_communications
after insert or update on public.parent_communications
for each row execute function public.audit_critical_business_row();

comment on table public.audit_logs is
  'Legacy row-audit stream retained for compatibility. New business audit/reporting should use public.audit_events.';
