-- V3 teacher review: class logs use the same draft/submitted/reviewed
-- lifecycle as attendance, assessments and questions.

alter table public.class_logs
  add column if not exists reviewer_id uuid references public.profiles(id),
  add column if not exists review_note text,
  add column if not exists reviewed_at timestamptz;

alter table public.class_logs
  drop constraint if exists class_logs_status_check;

alter table public.class_logs
  add constraint class_logs_status_check
  check(status in ('DRAFT','SUBMITTED','APPROVED','REJECTED'));

alter table public.class_logs
  drop constraint if exists class_logs_review_fields_check;

alter table public.class_logs
  add constraint class_logs_review_fields_check
  check (
    (status in ('APPROVED','REJECTED') and reviewer_id is not null and reviewed_at is not null)
    or status in ('DRAFT','SUBMITTED')
  );

create unique index if not exists class_logs_one_pending_per_session
  on public.class_logs(session_id)
  where status = 'SUBMITTED';

create or replace function public.guard_submitted_class_log()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Class-log history cannot be deleted.';
  end if;

  if old.status = 'DRAFT' then
    if new.status = 'DRAFT' then
      return new;
    end if;

    if new.status = 'SUBMITTED'
      and (to_jsonb(new) - array['status','submitted_at','reviewer_id','review_note','reviewed_at'])
          is distinct from
          (to_jsonb(old) - array['status','submitted_at','reviewer_id','review_note','reviewed_at']) then
      raise exception 'Submit the saved class-log draft without changing its contents.';
    end if;

    if new.status not in ('DRAFT','SUBMITTED') then
      raise exception 'A class-log draft must be submitted before review.';
    end if;

    return new;
  end if;

  if old.status = 'SUBMITTED' then
    if new.status not in ('APPROVED','REJECTED') then
      raise exception 'Submitted class-log evidence must be approved or rejected.';
    end if;

    if (to_jsonb(new) - array['status','reviewer_id','review_note','reviewed_at'])
       is distinct from
       (to_jsonb(old) - array['status','reviewer_id','review_note','reviewed_at']) then
      raise exception 'Submitted class-log evidence is immutable; create a new revision after rejection or approval.';
    end if;

    if new.reviewer_id is null or new.reviewed_at is null or length(btrim(coalesce(new.review_note,''))) < 5 then
      raise exception 'A class-log review requires a reviewer, time and review note.';
    end if;

    return new;
  end if;

  raise exception 'Finalized class-log evidence is immutable; create a new revision.';
end;
$$;

create or replace function public.class_log_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
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

    if p_input->>'decision' not in ('APPROVED','REJECTED') then
      raise exception 'Choose Approve or Reject.';
    end if;

    if length(trim(coalesce(p_input->>'review_note',''))) < 5
      or length(trim(coalesce(p_input->>'review_note',''))) > 1000 then
      raise exception 'Enter a review note of 5–1000 characters.';
    end if;

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
          reason,authored_by
        )
        values(
          sid,new_revision,latest.id,'DRAFT',progress,summary,
          unfinished,homework_value,next_value,why,actor
        )
        returning * into draft;
      else
        update public.class_logs
        set unit_progress=progress,
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
$$;

revoke all on function public.class_log_workspace(uuid),public.class_log_command(jsonb)
from public,anon;

grant execute on function public.class_log_workspace(uuid),public.class_log_command(jsonb)
to authenticated;
