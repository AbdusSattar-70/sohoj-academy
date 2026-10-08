-- Actual duration extends existing immutable teaching evidence and review.
alter table public.class_logs add column actual_starts_at timestamptz,add column actual_ends_at timestamptz;
alter table public.class_logs add constraint class_log_actual_time check((actual_starts_at is null and actual_ends_at is null) or(actual_starts_at is not null and actual_ends_at>actual_starts_at));
alter table public.class_logs drop constraint class_logs_check;
alter table public.class_logs add constraint class_logs_submission_time check((status='DRAFT' and submitted_at is null)or(status in('SUBMITTED','APPROVED','REJECTED')and submitted_at is not null));
CREATE OR REPLACE FUNCTION public.class_log_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid := auth.uid();
  rid uuid := nullif(p_input->>'request_id','')::uuid;
  sid uuid := nullif(p_input->>'session_id','')::uuid;
  act text := p_input->>'action';
  why text := trim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  cs public.class_sessions;
  latest public.class_logs;
  draft public.class_logs;
  review public.class_logs;
  progress jsonb := coalesce(p_input->'unit_progress','[]'::jsonb);
  unit_count integer;
  summary text := trim(coalesce(p_input->>'class_summary',''));
  unfinished text := trim(coalesce(p_input->>'unfinished_reason',''));
  homework_value text := trim(coalesce(p_input->>'homework',''));
  next_value text := trim(coalesce(p_input->>'next_session_plan',''));
  result jsonb;
  new_revision integer;
  branch uuid;
  actual_start timestamptz:=nullif(p_input->>'actual_starts_at','')::timestamptz;
  actual_end timestamptz:=nullif(p_input->>'actual_ends_at','')::timestamptz;
begin
  if actor is null or not public.has_permission('academics.view') then
    raise exception 'Academic access required.';
  end if;

  if rid is null or sid is null or length(why) < 5 or length(why) > 500 then
    raise exception 'Session, request identity and reason (5–500 characters) are required.';
  end if;

  if act = 'DECIDE' then
    if not public.has_permission('academics.attendance.approve') then
      raise exception 'Academic review permission required.';
    end if;
  elsif not (
    public.has_permission('academics.attendance.record')
    or public.has_permission('academics.sessions.manage')
  ) then
    raise exception 'Attendance recording permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into key from public.admission_command_keys where request_id=rid;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
  perform pg_advisory_xact_lock(hashtextextended(sid::text,21));

  select * into cs
  from public.class_sessions
  where id=sid
  for update;

  if cs.id is null then
    raise exception 'Class session not found.';
  end if;

  select branch_id
  into branch
  from public.batches
  where id=cs.batch_id;

  if act='DECIDE' then
    select *
    into review
    from public.class_logs
    where id=nullif(p_input->>'class_log_id','')::uuid
      and session_id=sid
      and status='SUBMITTED'
    for update;

    if review.id is null then
      raise exception 'No submitted class log is awaiting review.';
    end if;

    if review.authored_by=actor then
      raise exception 'The class-log author cannot approve or reject their own submission.';
    end if;

    if review.revision<>(select max(revision) from public.class_logs where session_id=sid) then raise exception 'Review the latest submitted teaching revision.';end if;
    if p_input->>'decision'='APPROVED' and(review.actual_starts_at is null or review.actual_ends_at is null) then raise exception 'Teacher must record actual teaching times before approval.';end if;
    if p_input->>'decision' not in ('APPROVED','REJECTED') then
      raise exception 'Choose Approve or Reject.';
    end if;

    if length(trim(coalesce(p_input->>'review_note',''))) < 5
      or length(trim(coalesce(p_input->>'review_note',''))) > 1000 then
      raise exception 'Enter a review note of 5–1000 characters.';
    end if;

    if p_input->>'decision'='APPROVED' and exists(select 1 from public.class_logs l join public.class_sessions x on x.id=l.session_id where x.teacher_id=cs.teacher_id and l.session_id<>sid and x.status='SCHEDULED' and l.status='APPROVED' and l.actual_starts_at<review.actual_ends_at and l.actual_ends_at>review.actual_starts_at) then raise exception 'Actual teaching time overlaps another approved class.';end if;
    update public.class_logs
    set status=p_input->>'decision',
        reviewer_id=actor,
        review_note=trim(p_input->>'review_note'),
        reviewed_at=now()
    where id=review.id
    returning * into review;

    result:=jsonb_build_object(
      'id',review.id,
      'revision',review.revision,
      'status',review.status,
      'message',case when review.status='APPROVED'
        then 'Class log approved.'
        else 'Class log rejected. The teacher can prepare a corrected revision.'
      end
    );

  else
    if not public.can_access_class_session(sid) then
      raise exception 'This class is outside your assigned scope.';
    end if;

    if cs.status<>'SCHEDULED' then
      raise exception 'A cancelled class cannot receive a class log.';
    end if;

    if cs.starts_at>now() then
      raise exception 'Class log opens after the scheduled class starts.';
    end if;

    if not public.has_permission('academics.sessions.manage')
      and not exists(
        select 1
        from public.staff st
        where st.profile_id=actor and st.id=cs.teacher_id
      ) then
      raise exception 'Only the assigned teacher may record this class.';
    end if;

    select * into latest
    from public.class_logs
    where session_id=sid
    order by revision desc
    limit 1;

    select * into draft
    from public.class_logs
    where session_id=sid
      and status='DRAFT'
    for update;

    if act='SAVE_DRAFT' then
      if actual_start is null or actual_end is null or actual_end<=actual_start or actual_end>now() or(actual_start at time zone 'Asia/Dhaka')::date<>cs.session_date or(actual_end at time zone 'Asia/Dhaka')::date<>cs.session_date then raise exception 'Record actual same-day start/end times; the end cannot be in the future.';end if;
      if exists(select 1 from public.class_logs l join public.class_sessions x on x.id=l.session_id where x.teacher_id=cs.teacher_id and l.session_id<>sid and x.status='SCHEDULED' and l.status='APPROVED' and l.actual_starts_at<actual_end and l.actual_ends_at>actual_start) then raise exception 'Actual teaching time overlaps another verified class.';end if;
      if latest.status='SUBMITTED' then
        raise exception 'This class log is awaiting admin review. Correct it only after a review decision.';
      end if;

      if jsonb_typeof(progress)<>'array' or jsonb_array_length(progress)>200 then
        raise exception 'Check curriculum progress entries.';
      end if;

      select coalesce(jsonb_array_length(cv.units),0)
      into unit_count
      from public.class_sessions x
      left join public.curriculum_versions cv on cv.id=x.curriculum_version_id
      where x.id=sid;

      if jsonb_array_length(progress)>unit_count then
        raise exception 'Progress must refer only to the curriculum pinned to this class.';
      end if;

      if exists(
        select 1
        from jsonb_array_elements(progress) e
        where (e->>'unit_index')::integer<0
          or (e->>'unit_index')::integer>=unit_count
          or e->>'status' not in ('COVERED','PARTIAL','NOT_COVERED')
          or length(coalesce(e->>'note',''))>500
      ) then
        raise exception 'Invalid curriculum progress entry.';
      end if;

      if summary='' or length(summary)>4000
        or length(unfinished)>2000
        or length(homework_value)>2000
        or length(next_value)>2000 then
        raise exception 'Class summary is required; keep each field within its limit.';
      end if;

      if exists(
        select 1 from jsonb_array_elements(progress) e
        where e->>'status' in ('PARTIAL','NOT_COVERED')
      ) and unfinished='' then
        raise exception 'Explain any planned curriculum left incomplete.';
      end if;

      if draft.id is not null and draft.authored_by<>actor then
        raise exception 'Another staff member owns the current draft.';
      end if;

      if draft.id is null then
        select coalesce(max(revision),0)+1
        into new_revision
        from public.class_logs
        where session_id=sid;

        insert into public.class_logs(
          session_id,revision,previous_log_id,status,unit_progress,
          class_summary,unfinished_reason,homework,next_session_plan,
          reason,authored_by,actual_starts_at,actual_ends_at
        )
        values(
          sid,new_revision,latest.id,'DRAFT',progress,summary,
          unfinished,homework_value,next_value,why,actor,actual_start,actual_end
        )
        returning * into draft;
      else
        update public.class_logs
        set actual_starts_at=actual_start,actual_ends_at=actual_end,unit_progress=progress,
            class_summary=summary,
            unfinished_reason=unfinished,
            homework=homework_value,
            next_session_plan=next_value,
            reason=why
        where id=draft.id
        returning * into draft;
      end if;

      result:=jsonb_build_object(
        'id',draft.id,
        'revision',draft.revision,
        'status',draft.status,
        'message','Class-log draft saved.'
      );

    elsif act='SUBMIT' then
      if draft.id is null or draft.authored_by<>actor then
        raise exception 'Save your class-log draft before submitting it.';
      end if;

      update public.class_logs
      set status='SUBMITTED',
          submitted_at=now()
      where id=draft.id
      returning * into draft;

      result:=jsonb_build_object(
        'id',draft.id,
        'revision',draft.revision,
        'status',draft.status,
        'message','Class log submitted for admin review.'
      );

    else
      raise exception 'Unsupported class-log action.';
    end if;
  end if;

  insert into public.audit_events(
    actor_profile_id,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    actor,
    branch,
    'CLASS_LOG',
    coalesce(draft.id,review.id)::text,
    act,
    why,
    null,
    case when review.id is not null then to_jsonb(review) else to_jsonb(draft) end,
    jsonb_build_object('session_id',sid,'revision',coalesce(draft.revision,review.revision))
  );

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(rid,actor,p_input,result);

  return result;
end;
$function$;

create function public.verified_teaching_hours(p_session uuid) returns numeric language sql stable security definer set search_path='' as $$
 select coalesce((select extract(epoch from(l.actual_ends_at-l.actual_starts_at))/3600 from public.class_logs l join public.class_sessions s on s.id=l.session_id where l.session_id=p_session and l.status='APPROVED' and s.status='SCHEDULED' and exists(select 1 from public.attendance_submissions a where a.session_id=s.id and a.status='APPROVED') order by l.revision desc limit 1),0)
$$;
revoke all on function public.verified_teaching_hours(uuid) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.teacher_compensation_preview(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  policy public.business_rule_versions;
  rows jsonb:='[]'::jsonb;
  teacher_row record;
  batch_row record;
  event_amount numeric;
  pool_percent numeric;
  acquisition_percent numeric;
  retention3_percent numeric;
  retention6_percent numeric;
  first_period date;
  first_collected numeric;
  month3 date;
  month6 date;
  month_paid boolean;
  continuous3 boolean;
  continuous6 boolean;
begin
  if actor is null or not public.has_permission('staff.compensation.view') then
    raise exception 'Compensation access denied.';
  end if;
  if p_from is null or p_to is null or p_to<p_from then
    raise exception 'Choose a valid compensation period.';
  end if;

  select * into policy
  from public.business_rule_versions
  where domain='teacher_compensation'
    and rule_key='default_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if policy.id is null
     or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
    raise exception 'A valid teacher compensation policy is required.';
  end if;

  pool_percent:=(policy.payload->>'teaching_pool_percent')::numeric;
  acquisition_percent:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  retention3_percent:=(policy.payload->>'retention_3_month_percent')::numeric;
  retention6_percent:=(policy.payload->>'retention_6_month_percent')::numeric;

  -- Teaching pool is calculated per batch from Net Collected Tuition and
  -- allocated by approved attendance/session workload within that batch.
  for batch_row in
    with batch_revenue as (
      select batch_id,sum(tuition_collected) net_collected
      from public.finance_net_collected_tuition(p_from,p_to)
      group by batch_id
    ),
    session_weights as (
      select
        cs.batch_id,
        cs.teacher_id,
        sum(public.verified_teaching_hours(cs.id)) as session_count
      from public.class_sessions cs
      where cs.session_date between p_from and p_to
        and cs.status='SCHEDULED'
      group by cs.batch_id,cs.teacher_id
    )
    select
      r.batch_id,
      r.net_collected,
      r.net_collected*pool_percent/100 as pool_amount,
      w.teacher_id,
      w.session_count,
      sum(w.session_count) over(partition by w.batch_id) total_sessions
    from batch_revenue r
    join session_weights w on w.batch_id=r.batch_id
    where r.net_collected>0 and w.session_count>0
  loop
    event_amount:=round(batch_row.pool_amount*batch_row.session_count/nullif(batch_row.total_sessions,0),2);
    if event_amount>0 and not exists (select 1 from public.teacher_compensation_claims c
      where c.teacher_id=batch_row.teacher_id and c.source_type='BATCH_PERIOD'
        and c.source_id=batch_row.batch_id::text||':'||p_from::text||':'||p_to::text) then
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',batch_row.teacher_id,
        'lineType','TEACHING_REMUNERATION',
        'amount',event_amount,
        'sourceType','BATCH_PERIOD',
        'sourceId',batch_row.batch_id::text||':'||p_from::text||':'||p_to::text,
        'calculation',jsonb_build_object(
          'batchId',batch_row.batch_id,
          'netCollectedTuition',batch_row.net_collected,
          'poolPercent',pool_percent,
          'poolAmount',batch_row.pool_amount,
          'approvedSessions',batch_row.session_count,
          'batchApprovedSessions',batch_row.total_sessions
        )
      )
    );
    end if;
  end loop;

  -- Acquisition/retention bonuses require a structured teacher referral.
  for teacher_row in
    select
      tr.teacher_id,
      tr.admission_id,
      min(n.billing_period) first_billing_period
    from public.teacher_referrals tr
    join public.admission_cases a on a.id=tr.admission_id and a.status='ACTIVE_ENROLLMENT'
    join public.finance_net_collected_tuition(date '2000-01-01',p_to) n
      on n.admission_id=tr.admission_id and n.tuition_collected>0
    group by tr.teacher_id,tr.admission_id
  loop
    first_period:=teacher_row.first_billing_period;

    select coalesce(sum(n.tuition_collected),0)
    into first_collected
    from public.finance_net_collected_tuition(first_period,(first_period+interval '1 month - 1 day')::date) n
    where n.admission_id=teacher_row.admission_id;

    if first_period between p_from and p_to and first_collected>0
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='ACQUISITION'
          and c.source_id=teacher_row.admission_id::text) then
      rows:=rows||jsonb_build_array(
        jsonb_build_object(
          'teacherId',teacher_row.teacher_id,
          'admissionId',teacher_row.admission_id,
          'lineType','ACQUISITION_BONUS',
          'amount',round(first_collected*acquisition_percent/100,2),
          'sourceType','ACQUISITION',
          'sourceId',teacher_row.admission_id::text,
          'calculation',jsonb_build_object(
            'firstMonthNetCollectedTuition',first_collected,
            'bonusPercent',acquisition_percent
          )
        )
      );
    end if;

    month3:=(first_period+interval '2 months')::date;
    month6:=(first_period+interval '5 months')::date;

    select bool_and(tuition_collected>0)
    into continuous3
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month3,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month3 between p_from and p_to and continuous3 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_3'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month3,(month3+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_3_MONTH',
            'amount',round(event_amount*retention3_percent/100,2),
            'sourceType','RETENTION_3',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month3,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention3_percent
            )
          )
        );
      end if;
    end if;

    select bool_and(tuition_collected>0)
    into continuous6
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month6,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month6 between p_from and p_to and continuous6 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_6'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month6,(month6+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_6_MONTH',
            'amount',round(event_amount*retention6_percent/100,2),
            'sourceType','RETENTION_6',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month6,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention6_percent
            )
          )
        );
      end if;
    end if;
  end loop;

  for teacher_row in
    select teacher_id,adjustment_type,id,amount
    from public.teacher_compensation_adjustments
    where status='APPROVED'
      and effective_period between p_from and p_to
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_compensation_adjustments.teacher_id
          and c.source_type='ADJUSTMENT' and c.source_id=teacher_compensation_adjustments.id::text)
  loop
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',teacher_row.teacher_id,
        'lineType',case when teacher_row.adjustment_type='GROWTH_BONUS'
          then 'GROWTH_BONUS' else 'ADJUSTMENT' end,
        'amount',teacher_row.amount,
        'sourceType','ADJUSTMENT',
        'sourceId',teacher_row.id::text,
        'calculation',jsonb_build_object(
          'adjustmentType',teacher_row.adjustment_type
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'periodStart',p_from,
    'periodEnd',p_to,
    'policyVersion',policy.version,
    'rows',rows,
    'total',coalesce((select sum((x->>'amount')::numeric) from jsonb_array_elements(rows) x),0)
  );
end;
$function$;
notify pgrst,'reload schema';

CREATE OR REPLACE FUNCTION public.attendance_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  change_reason text:=btrim(coalesce(p_input->>'reason',''));
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
  target_session_id uuid:=nullif(p_input->>'session_id','')::uuid;
  attendance_id uuid:=nullif(p_input->>'attendance_id','')::uuid;
  approval_id uuid:=nullif(p_input->>'approval_id','')::uuid;
begin
  if actor is null or not public.has_permission('academics.view') then
    raise exception 'Academic access required.';
  end if;

  if req is null or length(change_reason)<5 or length(change_reason)>500 then
    raise exception 'A request identity and change_reason of 5–500 characters are required.';
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

  perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
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

    if length(change_reason)<5 then
      raise exception 'A review note is required.';
    end if;

    if p_input->>'decision' not in ('APPROVED','REJECTED') then
      raise exception 'Choose Approve or Reject.';
    end if;

    update public.attendance_submissions
    set status=p_input->>'decision',
        reviewer_id=actor,
        review_note=change_reason,
        reviewed_at=now()
    where id=attendance.id;

    update public.approval_requests
    set status=(p_input->>'decision')::public.approval_status,
        decided_by=actor,
        decided_at=now(),
        decision_note=change_reason
    where id=approval.id;

    result:=jsonb_build_object(
      'id',attendance.id,
      'message','Attendance '||lower(p_input->>'decision')||'. The reviewed revision is preserved in history.'
    );

  else
    select * into session_row
    from public.class_sessions
    where id=target_session_id
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
        change_reason,
        actor,
        req
      )
      returning id into id_out;

      update public.attendance_submissions
      set status='SUBMITTED',
          approval_id=id_out
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
        change_reason,
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
    change_reason,
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
$function$;
