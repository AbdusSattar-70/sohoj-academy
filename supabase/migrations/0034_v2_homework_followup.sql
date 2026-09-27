-- A submitted class log assigns homework; teachers record observed per-student
-- follow-up. Each correction appends a revision and preserves the earlier check.
create table public.homework_checks (
  id uuid primary key default gen_random_uuid(),
  class_log_id uuid not null references public.class_logs(id),
  enrollment_id uuid not null references public.enrollments(id),
  revision integer not null check(revision>0),
  status text not null check(status in ('NOT_SUBMITTED','NEEDS_WORK','COMPLETE')),
  submitted_on date,
  feedback text not null default '' check(length(feedback)<=1000),
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now(),
  unique(class_log_id,enrollment_id,revision)
);
create index homework_checks_history on public.homework_checks(class_log_id,enrollment_id,revision desc);
alter table public.homework_checks enable row level security;
revoke all on public.homework_checks from anon,authenticated;

create or replace function public.homework_workspace(p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare log_row public.class_logs; session_row public.class_sessions;
begin
  if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.'; end if;
  select * into session_row from public.class_sessions where id=p_session_id;
  select * into log_row from public.class_logs where session_id=p_session_id and status='SUBMITTED' and btrim(homework)<>'' order by revision desc limit 1;
  return jsonb_build_object(
    'assignment',case when log_row.id is null then null else jsonb_build_object('id',log_row.id,'revision',log_row.revision,'description',log_row.homework,'submittedAt',log_row.submitted_at) end,
    'students',coalesce((select jsonb_agg(jsonb_build_object(
      'enrollmentId',e.id,'studentNo',s.student_no,'name',s.full_name,
      'latestRevision',hc.revision,'status',hc.status,'submittedOn',hc.submitted_on,'feedback',hc.feedback
      ) order by s.student_no)
      from public.enrollments e join public.students s on s.id=e.student_id
      left join lateral (select * from public.homework_checks h where h.class_log_id=log_row.id and h.enrollment_id=e.id order by revision desc limit 1) hc on true
      where log_row.id is not null and e.batch_id=session_row.batch_id and e.admission_date<=session_row.session_date
      and (e.ended_on is null or e.ended_on>session_row.session_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'enrollmentId',h.enrollment_id,'revision',h.revision,'status',h.status,'submittedOn',h.submitted_on,'feedback',h.feedback,'recordedAt',h.recorded_at) order by h.recorded_at desc)
      from public.homework_checks h where h.class_log_id=log_row.id),'[]'::jsonb)
  );
end $$;

create or replace function public.homework_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid:=auth.uid(); rid uuid:=(p_input->>'request_id')::uuid;
  sid uuid:=(p_input->>'session_id')::uuid; log_id uuid:=(p_input->>'class_log_id')::uuid;
  v_enrollment_id uuid:=(p_input->>'enrollment_id')::uuid; cs public.class_sessions;
  log_row public.class_logs; previous integer; check_row public.homework_checks;
  key public.admission_command_keys; result jsonb; feedback_value text:=btrim(coalesce(p_input->>'feedback',''));
  submitted_on_value date;
begin
  if actor is null or not public.has_permission('academics.view') or not (public.has_permission('academics.attendance.record') or public.has_permission('academics.sessions.manage')) then raise exception 'Teaching permission required.'; end if;
  if rid is null or sid is null or log_id is null or v_enrollment_id is null then raise exception 'Homework request identity and scope are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into key from public.admission_command_keys where request_id=rid;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
    return key.result;
  end if;
  if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.'; end if;
  select * into cs from public.class_sessions where id=sid;
  if cs.status<>'SCHEDULED' or (not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff st where st.id=cs.teacher_id and st.profile_id=actor)) then raise exception 'Only the assigned teacher may check homework.'; end if;
  select * into log_row from public.class_logs where id=log_id and session_id=sid and status='SUBMITTED' and btrim(homework)<>'';
  if log_row.id is null then raise exception 'Submit the class log with homework before follow-up.'; end if;
  if not exists(select 1 from public.enrollments e where e.id=v_enrollment_id and e.batch_id=cs.batch_id
    and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date)
    and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')) then raise exception 'Student was not on this class roster.'; end if;
  if p_input->>'status' not in ('NOT_SUBMITTED','NEEDS_WORK','COMPLETE') or length(feedback_value)>1000
    or (p_input->>'status'='NEEDS_WORK' and length(feedback_value)<5) then raise exception 'Choose a status and explain work that needs attention.'; end if;
  submitted_on_value:=nullif(p_input->>'submitted_on','')::date;
  if submitted_on_value>current_date or (p_input->>'status'='NOT_SUBMITTED' and submitted_on_value is not null) then raise exception 'Check the homework submission date.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(log_id::text||v_enrollment_id::text,31));
  select coalesce(max(revision),0) into previous from public.homework_checks where class_log_id=log_id and enrollment_id=v_enrollment_id;
  if previous<>coalesce((p_input->>'base_revision')::integer,0) then raise exception 'Homework review changed. Refresh and try again.'; end if;
  insert into public.homework_checks(class_log_id,enrollment_id,revision,status,submitted_on,feedback,recorded_by)
  values(log_id,v_enrollment_id,previous+1,p_input->>'status',submitted_on_value,feedback_value,actor) returning * into check_row;
  result:=jsonb_build_object('id',check_row.id,'revision',check_row.revision);
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'HOMEWORK_CHECK',check_row.id::text,'RECORD',to_jsonb(check_row));
  insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
  return result;
end $$;
revoke all on function public.homework_workspace(uuid),public.homework_command(jsonb) from public,anon;
grant execute on function public.homework_workspace(uuid),public.homework_command(jsonb) to authenticated;
