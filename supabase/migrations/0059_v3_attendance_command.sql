-- SOHOJ ACADEMY V3
-- Focused teacher attendance command boundary.
-- Teacher submissions remain reviewable by admin; each correction is a new revision.

alter table public.attendance_submissions
  add column if not exists reviewer_id uuid references public.profiles(id),
  add column if not exists review_note text,
  add column if not exists reviewed_at timestamptz;

create index if not exists attendance_reviewed_idx
  on public.attendance_submissions(session_id, status, revision desc);

create or replace function public.attendance_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  session_row public.class_sessions;
  latest public.attendance_submissions;
  attendance public.attendance_submissions;
  approval public.approval_requests;
  roster jsonb;
  rows jsonb;
  entry jsonb;
  result jsonb;
  id_out uuid;
  session_id uuid:=nullif(p_input->>'session_id','')::uuid;
  attendance_id uuid:=nullif(p_input->>'attendance_id','')::uuid;
  approval_id uuid:=nullif(p_input->>'approval_id','')::uuid;
begin
  if actor is null or not public.has_permission('academics.view') then
    raise exception 'Academic access required.';
  end if;

  if req is null or length(reason)<5 or length(reason)>500 then
    raise exception 'A request identity and reason of 5–500 characters are required.';
  end if;

  if action not in ('SAVE_ATTENDANCE','SUBMIT_ATTENDANCE','DECIDE_ATTENDANCE') then
    raise exception 'Unsupported V3 attendance action.';
  end if;

  if action in ('SAVE_ATTENDANCE','SUBMIT_ATTENDANCE')
    and not public.has_permission('academics.attendance.record') then
    raise exception 'Attendance recording permission required.';
  end if;

  if action='DECIDE_ATTENDANCE'
    and not public.has_permission('academics.attendance.approve') then
    raise exception 'Attendance review permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,11));

  select * into key
  from public.admission_command_keys
  where request_id=req;

  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  if action='DECIDE_ATTENDANCE' then
    select * into approval
    from public.approval_requests
    where id=approval_id
      and workflow_type='ATTENDANCE'
    for update;

    if approval.id is null or approval.status<>'PENDING' then
      raise exception 'Pending attendance review was not found.';
    end if;

    attendance_id:=nullif(approval.payload_snapshot->>'attendance_id','')::uuid;
    select * into attendance
    from public.attendance_submissions
    where id=attendance_id
      and status='SUBMITTED'
    for update;

    if attendance.id is null then
      raise exception 'Submitted attendance was not found.';
    end if;

    if attendance.recorded_by=actor then
      raise exception 'The submitting teacher cannot review their own attendance.';
    end if;

    if length(reason)<5 then
      raise exception 'A review note is required.';
    end if;

    if p_input->>'decision' not in ('APPROVED','REJECTED') then
      raise exception 'Choose Approve or Reject.';
    end if;

    update public.attendance_submissions
    set status=p_input->>'decision',
        reviewer_id=actor,
        review_note=reason,
        reviewed_at=now()
    where id=attendance.id;

    update public.approval_requests
    set status=(p_input->>'decision')::public.approval_status,
        decided_by=actor,
        decided_at=now(),
        decision_note=reason
    where id=approval.id;

    result:=jsonb_build_object(
      'id',attendance.id,
      'message','Attendance '||lower(p_input->>'decision')||'. The reviewed revision is preserved in history.'
    );

  else
    select * into session_row
    from public.class_sessions
    where id=session_id
      and public.can_access_class_session(id)
    for update;

    if session_row.id is null then
      raise exception 'Class session was not found or is not accessible.';
    end if;

    if session_row.status<>'SCHEDULED' or session_row.starts_at>now() then
      raise exception 'Attendance can be recorded only after a scheduled class has started.';
    end if;

    select * into latest
    from public.attendance_submissions
    where id in (
      select id
      from public.attendance_submissions
      where session_id=session_row.id
      order by revision desc
      limit 1
    )
    for update;

    if action='SUBMIT_ATTENDANCE' then
      if attendance_id is null
        or latest.id is distinct from attendance_id
        or latest.status<>'DRAFT' then
        raise exception 'Only the latest saved attendance draft can be submitted.';
      end if;

      if latest.recorded_by<>actor then
        raise exception 'Only the draft author may submit the attendance.';
      end if;

      if exists(
        select 1
        from public.attendance_submissions
        where session_id=session_row.id
          and status='SUBMITTED'
      ) then
        raise exception 'Attendance is already awaiting admin review.';
      end if;

      insert into public.approval_requests(
        workflow_type,
        entity_type,
        entity_id,
        requested_action,
        payload_snapshot,
        request_note,
        requested_by,
        correlation_id
      )
      values(
        'ATTENDANCE',
        'CLASS_SESSION',
        session_row.id::text,
        'SUBMIT_ATTENDANCE',
        jsonb_build_object(
          'attendance_id',latest.id,
          'revision',latest.revision,
          'entries',latest.entries
        ),
        reason,
        actor,
        req
      )
      returning id into id_out;

      update public.attendance_submissions
      set status='SUBMITTED'
      where id=latest.id;

      result:=jsonb_build_object(
        'id',latest.id,
        'message','Attendance submitted for admin review.'
      );

    else
      if latest.status='SUBMITTED' then
        raise exception 'Attendance is awaiting admin review.';
      end if;

      if latest.id is not null
        and latest.id is distinct from nullif(p_input->>'base_id','')::uuid then
        raise exception 'Attendance changed. Refresh before saving a new revision.';
      end if;

      perform pg_advisory_xact_lock(hashtextextended('attendance:'||session_row.id::text,31));

      if latest.id is null then
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'student_id',s.id,
              'enrollment_id',e.id,
              'number',s.student_no,
              'name',s.full_name,
              'status',null,
              'note',''
            )
            order by s.student_no
          ),
          '[]'::jsonb
        )
        into roster
        from public.enrollments e
        join public.students s on s.id=e.student_id
        where e.batch_id=session_row.batch_id
          and e.admission_date<=session_row.session_date
          and (e.ended_on is null or e.ended_on>session_row.session_date)
          and e.status in ('ACTIVE','WITHDRAWN','COMPLETED');
      else
        roster:=latest.entries;
      end if;

      rows:=p_input->'entries';

      if rows is null or jsonb_typeof(rows)<>'array' then
        raise exception 'Attendance entries are required.';
      end if;

      if jsonb_array_length(roster)=0
        or jsonb_array_length(rows)<>jsonb_array_length(roster)
        or (
          select count(distinct x->>'enrollment_id')
          from jsonb_array_elements(rows) x
        )<>jsonb_array_length(rows) then
        raise exception 'Record exactly one attendance status for every roster member.';
      end if;

      for entry in
        select x from jsonb_array_elements(rows) x
      loop
        if coalesce(entry->>'status','') not in ('PRESENT','ABSENT','LATE','EXCUSED')
          or length(coalesce(entry->>'note',''))>500
          or not exists(
            select 1
            from jsonb_array_elements(roster) r
            where r->>'enrollment_id'=entry->>'enrollment_id'
          ) then
          raise exception 'Invalid attendance status, note or roster member.';
        end if;
      end loop;

      select jsonb_agg(
        r||jsonb_build_object(
          'status',e->>'status',
          'note',coalesce(e->>'note','')
        )
        order by r->>'number'
      )
      into rows
      from jsonb_array_elements(roster) r
      join jsonb_array_elements(rows) e
        on r->>'enrollment_id'=e->>'enrollment_id';

      insert into public.attendance_submissions(
        session_id,
        revision,
        entries,
        reason,
        recorded_by
      )
      values(
        session_row.id,
        coalesce(latest.revision,0)+1,
        rows,
        reason,
        actor
      )
      returning id into id_out;

      result:=jsonb_build_object(
        'id',id_out,
        'message','Attendance draft saved. Submit it for admin review.'
      );
    end if;
  end if;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    after_data,
    metadata
  )
  values(
    req,
    actor,
    (select id from public.staff where profile_id=actor limit 1),
    'ATTENDANCE_SUBMISSION',
    result->>'id',
    action,
    reason,
    result,
    jsonb_build_object('academic_flow','V3_ATTENDANCE_REVIEW')
  );

  insert into public.admission_command_keys(
    request_id,
    actor_id,
    payload,
    result
  )
  values(
    req,
    actor,
    p_input,
    result
  );

  return result;
end;
$$;

revoke all on function public.attendance_command(jsonb) from public,anon;
grant execute on function public.attendance_command(jsonb) to authenticated;
