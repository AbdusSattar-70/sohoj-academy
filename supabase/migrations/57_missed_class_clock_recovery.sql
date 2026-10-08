-- Recover a missed Start without copying or bypassing the class command/review engine.
create function public.teacher_class_recover_clock(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();sid uuid:=nullif(p_input->>'session_id','')::uuid;cs public.class_sessions;start_value timestamptz;end_value timestamptz;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.attendance.record') then raise exception 'Active attendance recording access required.';end if;
 if p_input->>'action'<>'CORRECT_CLOCK' then raise exception 'Use the actual-time correction action.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if not exists(select 1 from public.class_teaching_clocks where session_id=sid) then
  select * into cs from public.class_sessions where id=sid and public.can_access_class_session(id) for update;
  if cs.id is null or cs.status<>'SCHEDULED' then raise exception 'Select an accessible scheduled class.';end if;
  if not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff where id=cs.teacher_id and profile_id=actor and status='ACTIVE') then raise exception 'Only the assigned teacher may recover this class.';end if;
  start_value:=nullif(p_input->>'started_at','')::timestamptz;end_value:=nullif(p_input->>'ended_at','')::timestamptz;
  if start_value is null or end_value is null or end_value<=start_value or end_value>now() or(start_value at time zone 'Asia/Dhaka')::date<>cs.session_date or(end_value at time zone 'Asia/Dhaka')::date<>cs.session_date then raise exception 'Enter actual same-day times; end must follow start and cannot be future.';end if;
  if exists(select 1 from public.class_teaching_clocks where teacher_id=cs.teacher_id and started_at<end_value and coalesce(ended_at,'infinity'::timestamptz)>start_value) then raise exception 'Actual time overlaps another class.';end if;
  insert into public.class_teaching_clocks(session_id,teacher_id,started_at,ended_at,recorded_by,correction_reason) values(sid,cs.teacher_id,start_value,end_value,actor,p_input->>'reason');
 end if;
 -- Existing command validates reason/request identity, locks/review state and writes the audit event.
 return public.teacher_class_command(p_input);
end $$;
revoke all on function public.teacher_class_recover_clock(jsonb) from public,anon;
grant execute on function public.teacher_class_recover_clock(jsonb) to authenticated;
notify pgrst,'reload schema';
