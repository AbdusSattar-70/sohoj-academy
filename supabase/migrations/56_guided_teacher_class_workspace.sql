-- Capture actual class clocks; keep existing attendance, teaching evidence and independent review.
create table public.class_teaching_clocks (
 session_id uuid primary key references public.class_sessions(id),
 teacher_id uuid not null references public.staff(id),
 started_at timestamptz not null,
 ended_at timestamptz,
 recorded_by uuid not null references public.profiles(id),
 correction_reason text,
 check(ended_at is null or ended_at>started_at)
);
create unique index one_running_class_per_teacher on public.class_teaching_clocks(teacher_id) where ended_at is null;
alter table public.class_teaching_clocks enable row level security;
revoke all on public.class_teaching_clocks from public,anon,authenticated;
grant select on public.class_teaching_clocks to authenticated;
create policy teaching_clock_read on public.class_teaching_clocks for select to authenticated using(public.can_access_class_session(session_id));

create function public.teacher_class_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); req uuid:=nullif(p_input->>'request_id','')::uuid;
 sid uuid:=nullif(p_input->>'session_id','')::uuid; act text:=p_input->>'action';
 why text:=btrim(coalesce(p_input->>'reason','')); cs public.class_sessions;
 clock_row public.class_teaching_clocks; key public.admission_command_keys;
 attendance public.attendance_submissions; result jsonb; report jsonb;
 start_value timestamptz; end_value timestamptz; previous jsonb;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.attendance.record') then raise exception 'Active attendance recording access required.';end if;
 if req is null or sid is null or length(why) not between 5 and 500 then raise exception 'Select a class and valid request/reason.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 select * into cs from public.class_sessions where id=sid and public.can_access_class_session(id) for update;
 if cs.id is null or cs.status<>'SCHEDULED' then raise exception 'Select an accessible scheduled class.';end if;
 if not exists(select 1 from public.staff where id=cs.teacher_id and status='ACTIVE') then raise exception 'Assigned teacher is inactive. Ask admin to update the assignment.';end if;
 if not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff where id=cs.teacher_id and profile_id=actor and status='ACTIVE') then raise exception 'Only the assigned teacher may operate this class.';end if;
 select * into clock_row from public.class_teaching_clocks where session_id=sid for update;
 previous:=to_jsonb(clock_row);
 if act='START' then
  if cs.session_date<>(now() at time zone 'Asia/Dhaka')::date or cs.starts_at>now() then raise exception 'Start this class on its scheduled date, at or after its scheduled start. Reschedule if necessary.';end if;
  if clock_row.session_id is not null then raise exception 'This class has already started. Refresh to continue.';end if;
  if exists(select 1 from public.class_logs where session_id=sid) then raise exception 'Teaching evidence already exists. Continue or correct that report instead of starting a second clock.';end if;
  if exists(select 1 from public.class_teaching_clocks where teacher_id=cs.teacher_id and ended_at is null) then raise exception 'Finish the teacher''s running class before starting another.';end if;
  insert into public.class_teaching_clocks(session_id,teacher_id,started_at,recorded_by) values(sid,cs.teacher_id,now(),actor) returning * into clock_row;
 elsif act='END' then
  if clock_row.session_id is null or clock_row.ended_at is not null then raise exception 'Start the class first, or refresh its saved ending.';end if;
  if (now() at time zone 'Asia/Dhaka')::date<>cs.session_date then raise exception 'The class date has passed. Correct the actual start/end times with a reason.';end if;
  update public.class_teaching_clocks set ended_at=now() where session_id=sid returning * into clock_row;
 elsif act='CORRECT_CLOCK' then
  if clock_row.session_id is null then raise exception 'No class clock to correct. Use the existing teaching report recovery form.';end if;
  if exists(select 1 from public.class_logs where session_id=sid and status in('SUBMITTED','APPROVED')) then raise exception 'Reviewed/submitted times stay in history. Use a correction report after review.';end if;
  start_value:=nullif(p_input->>'started_at','')::timestamptz;end_value:=nullif(p_input->>'ended_at','')::timestamptz;
  if start_value is null or end_value is null or end_value<=start_value or end_value>now() or(start_value at time zone 'Asia/Dhaka')::date<>cs.session_date or(end_value at time zone 'Asia/Dhaka')::date<>cs.session_date then raise exception 'Enter actual same-day times; end must follow start and cannot be future.';end if;
  if exists(select 1 from public.class_teaching_clocks where teacher_id=cs.teacher_id and session_id<>sid and started_at<end_value and coalesce(ended_at,'infinity'::timestamptz)>start_value) then raise exception 'Actual time overlaps another class. Correct that record first.';end if;
  update public.class_teaching_clocks set started_at=start_value,ended_at=end_value,correction_reason=why where session_id=sid returning * into clock_row;
 elsif act in('SAVE_REPORT','SUBMIT_REPORT') then
  if clock_row.ended_at is null then raise exception 'Record the class ending before saving the final teaching report.';end if;
  select * into attendance from public.attendance_submissions where session_id=sid order by revision desc limit 1;
  if attendance.id is null or attendance.status='REJECTED' then raise exception 'Save student attendance first, including every student.';end if;
  report:=public.class_log_command((p_input-'action'-'request_id')||jsonb_build_object('action','SAVE_DRAFT','request_id',gen_random_uuid(),'actual_starts_at',clock_row.started_at,'actual_ends_at',clock_row.ended_at));
  if act='SUBMIT_REPORT' then
   if attendance.status='DRAFT' then
    perform public.academic_command(jsonb_build_object('action','SUBMIT_ATTENDANCE','request_id',gen_random_uuid(),'session_id',sid,'attendance_id',attendance.id,'reason',why));
   end if;
   perform public.class_log_command(jsonb_build_object('action','SUBMIT','request_id',gen_random_uuid(),'session_id',sid,'reason',why));
  end if;
 else raise exception 'Unsupported class action.';end if;
 result:=jsonb_build_object('id',sid,'clock',to_jsonb(clock_row),'message',case act when 'START' then 'Class started. Take student attendance next.' when 'END' then 'Class ending recorded. Review and submit the report.' when 'CORRECT_CLOCK' then 'Actual times corrected with audit history.' when 'SAVE_REPORT' then 'Class report draft saved.' else 'Student attendance and teaching report submitted for admin review.' end);
 insert into public.audit_events(actor_profile_id,branch_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) select actor,b.branch_id,'CLASS_TEACHING_CLOCK',sid::text,act,why,previous,to_jsonb(clock_row),req from public.batches b where b.id=cs.batch_id;
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end $$;

-- Exam preparation must not be confused with ordinary class questions.
alter table public.class_question_documents add column assessment_id uuid references public.academic_assessments(id);
create index question_documents_exam on public.class_question_documents(assessment_id,updated_at desc) where assessment_id is not null;
create function public.teacher_class_question_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;exam uuid:=nullif(p_input->>'assessment_id','')::uuid;key public.admission_command_keys;result jsonb;existing public.class_question_documents;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.view') then raise exception 'Active academic access required.';end if;
 if req is null then raise exception 'Request identity required.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity reused with different input.';end if;return key.result;end if;
 if nullif(p_input->>'id','') is not null then select * into existing from public.class_question_documents where id=(p_input->>'id')::uuid;end if;
 if p_input->>'action'='SAVE' and exam is not null then
  if existing.id is not null and existing.assessment_id is distinct from exam then raise exception 'Create a separate draft for a different exam.';end if;
  if not exists(select 1 from public.academic_assessments a join public.class_sessions s on s.batch_id=a.batch_id and s.subject_id=a.subject_id where a.id=exam and a.status='PUBLISHED' and s.id=coalesce(existing.session_id,nullif(p_input->>'session_id','')::uuid) and public.can_access_class_session(s.id)) then raise exception 'Select a published exam for the assigned class batch and subject.';end if;
 end if;
 result:=public.class_question_document_command(p_input||jsonb_build_object('request_id',gen_random_uuid()));
 if p_input->>'action'='SAVE' and exam is not null then
  update public.class_question_documents set assessment_id=exam where id=(result->>'id')::uuid;
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'CLASS_QUESTION_DOCUMENT',result->>'id','LINK_EXAM','Prepared questions for the selected published assessment',jsonb_build_object('assessment_id',exam),req);
 end if;
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.teacher_class_question_command(jsonb) from public,anon;
grant execute on function public.teacher_class_question_command(jsonb) to authenticated;

create function public.teacher_class_workspace(p_session_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; today date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not public.has_permission('academics.view') then raise exception 'Active academic access required.';end if;
 if p_session_id is not null and not public.can_access_class_session(p_session_id) then raise exception 'Class outside assigned scope.';end if;
 with upcoming as(
  select s.id session_id,s.batch_id,s.subject_id,s.session_date,s.starts_at,b.name batch,su.name subject,s.planned_scope,
   (select jsonb_build_object('status',d.status,'id',d.id,'topic',d.topic,'draft_url',d.draft_url,'page_reference',d.page_reference,'review_note',d.review_note) from public.class_question_documents d where d.session_id=s.id and d.assessment_id is null and d.author_id=auth.uid() order by d.updated_at desc,d.id limit 1) document
  from public.class_sessions s join public.staff t on t.id=s.teacher_id join public.batches b on b.id=s.batch_id join public.subjects su on su.id=s.subject_id
  where t.profile_id=auth.uid() and t.status='ACTIVE' and s.status='SCHEDULED' and public.can_access_class_session(s.id) and s.session_date between today and today+7
  order by s.starts_at,s.id limit 25
 ), reminders as(
  select 'CLASS:'||u.session_id::text id,u.session_id,u.session_date date,u.batch,u.subject,u.planned_scope topic,u.document,'CLASS' kind,null::text title,null::uuid assessment_id from upcoming u
  union all
  select 'EXAM:'||a.id::text,source.id,a.assessment_date,b.name,su.name,source.planned_scope,
   (select jsonb_build_object('status',d.status,'id',d.id,'topic',d.topic,'draft_url',d.draft_url,'page_reference',d.page_reference,'review_note',d.review_note) from public.class_question_documents d where d.assessment_id=a.id and d.author_id=auth.uid() order by d.updated_at desc,d.id limit 1),'EXAM',a.title,a.id
  from public.academic_assessments a join public.batches b on b.id=a.batch_id join public.subjects su on su.id=a.subject_id
  join lateral(select s.id,s.planned_scope from public.class_sessions s join public.staff t on t.id=s.teacher_id where s.batch_id=a.batch_id and s.subject_id=a.subject_id and t.profile_id=auth.uid() and t.status='ACTIVE' and s.status='SCHEDULED' and public.can_access_class_session(s.id) and s.session_date<=a.assessment_date order by s.session_date desc,s.starts_at desc limit 1) source on true
  where a.status='PUBLISHED' and a.assessment_date between today and today+7
 )
 select jsonb_build_object('clock',(select to_jsonb(c) from public.class_teaching_clocks c where c.session_id=p_session_id),
 'reminders',coalesce((select jsonb_agg(to_jsonb(x) order by x.date,x.kind) from(select * from reminders order by date,kind,session_id limit 25)x),'[]'::jsonb)) into result;
 return result;
end $$;
revoke all on function public.teacher_class_command(jsonb),public.teacher_class_workspace(uuid) from public,anon;
grant execute on function public.teacher_class_command(jsonb),public.teacher_class_workspace(uuid) to authenticated;
notify pgrst,'reload schema';

create trigger teaching_clock_no_delete before delete on public.class_teaching_clocks for each row execute function public.prevent_permanent_record_delete();
create function public.guard_started_class_schedule() returns trigger language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from public.class_teaching_clocks where session_id=old.id) and(new.teacher_id,new.batch_id,new.subject_id,new.session_date,new.starts_at,new.ends_at) is distinct from(old.teacher_id,old.batch_id,old.subject_id,old.session_date,old.starts_at,old.ends_at) then raise exception 'This class already started. Preserve its schedule; use the actual-time correction or a new session.';end if;
 if new.status='CANCELLED' and exists(select 1 from public.class_teaching_clocks where session_id=old.id and ended_at is null) then raise exception 'Finish or correct the running class clock before cancelling this occurrence.';end if;
 return new;
end $$;
revoke all on function public.guard_started_class_schedule() from public,anon,authenticated;
create trigger started_class_schedule_guard before update on public.class_sessions for each row execute function public.guard_started_class_schedule();
