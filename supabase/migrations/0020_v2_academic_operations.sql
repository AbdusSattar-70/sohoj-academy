-- Academic plans and scheduled occurrences are separate from attendance evidence.
create table public.academic_rooms (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),name text not null check(length(btrim(name))>=2),capacity integer not null check(capacity>0),created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),unique(branch_id,name)
);
create table public.curriculum_versions (
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),version integer not null,title text not null,units jsonb not null,reason text not null,published_by uuid not null references public.profiles(id),published_at timestamptz not null default now(),unique(batch_id,subject_id,version)
);
create table public.academic_routines (
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),teacher_id uuid not null references public.staff(id),room_id uuid not null references public.academic_rooms(id),weekday integer not null check(weekday between 0 and 6),start_time time not null,end_time time not null,starts_on date not null,ends_on date not null,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),retired_at timestamptz,check(end_time>start_time),check(ends_on>=starts_on)
);
create table public.class_sessions (
 id uuid primary key default gen_random_uuid(),routine_id uuid references public.academic_routines(id),batch_id uuid not null references public.batches(id),subject_id uuid not null references public.subjects(id),teacher_id uuid not null references public.staff(id),room_id uuid not null references public.academic_rooms(id),curriculum_version_id uuid references public.curriculum_versions(id),planned_scope text not null,session_date date not null,starts_at timestamptz not null,ends_at timestamptz not null,status text not null default 'SCHEDULED' check(status in('SCHEDULED','CANCELLED')),cancellation_reason text,cancelled_by uuid references public.profiles(id),cancelled_at timestamptz,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),check(ends_at>starts_at),unique(routine_id,session_date)
);
create index sessions_schedule on public.class_sessions(starts_at,ends_at) where status='SCHEDULED';
create table public.attendance_submissions (
 id uuid primary key default gen_random_uuid(),session_id uuid not null references public.class_sessions(id),revision integer not null,entries jsonb not null,reason text not null,status text not null default 'DRAFT' check(status in('DRAFT','SUBMITTED','APPROVED','REJECTED')),recorded_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),approval_id uuid unique references public.approval_requests(id),unique(session_id,revision)
);
create unique index one_pending_attendance on public.attendance_submissions(session_id) where status='SUBMITTED';

create or replace function public.can_access_class_session(p_session uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and public.has_permission('academics.view') and exists(select 1 from public.class_sessions cs join public.staff st on st.id=cs.teacher_id where cs.id=p_session and (public.has_permission('academics.sessions.manage') or public.has_permission('academics.attendance.approve') or st.profile_id=auth.uid()));
$$;
revoke all on function public.can_access_class_session(uuid) from public,anon;
grant execute on function public.can_access_class_session(uuid) to authenticated;

create or replace function public.academic_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;action text:=p_input->>'action';reason text:=btrim(coalesce(p_input->>'reason',''));key public.admission_command_keys;
 b public.batches;room public.academic_rooms;r public.academic_routines;cs public.class_sessions;cv public.curriculum_versions;teacher public.staff;year public.academic_years;
 att public.attendance_submissions;last_att public.attendance_submissions;approval public.approval_requests;
 sid uuid;rid uuid;bid uuid;subid uuid;tid uuid;roomid uuid;date_from date;date_to date;day date;st time;et time;tz text;start_at timestamptz;end_at timestamptz;
 rows jsonb;roster jsonb;entry jsonb;unit jsonb;result jsonb;created integer:=0;permission text;scope text;id_out uuid;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if req is null or length(reason)<5 or length(reason)>500 then raise exception 'A request identity and reason of 5–500 characters are required.';end if;
 permission:=case action when 'CREATE_ROOM' then 'academics.sessions.manage' when 'PUBLISH_CURRICULUM' then 'academics.curriculum.manage' when 'CREATE_ROUTINE' then 'academics.sessions.manage' when 'RETIRE_ROUTINE' then 'academics.sessions.manage' when 'GENERATE_SESSIONS' then 'academics.sessions.manage' when 'CREATE_SESSION' then 'academics.sessions.manage' when 'CANCEL_SESSION' then 'academics.sessions.manage' when 'SAVE_ATTENDANCE' then 'academics.attendance.record' when 'SUBMIT_ATTENDANCE' then 'academics.attendance.record' when 'DECIDE_ATTENDANCE' then 'academics.attendance.approve' else null end;
 if permission is null or not public.has_permission(permission) then raise exception 'Permission denied for this academic action.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 -- Serialize schedule conflict checks and attendance/session-state transitions.
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if action='CREATE_ROOM' then
  if not exists(select 1 from public.branches where id=(p_input->>'branch_id')::uuid and is_active) then raise exception 'Choose an active branch.';end if;
  insert into public.academic_rooms(branch_id,name,capacity,created_by) values((p_input->>'branch_id')::uuid,btrim(p_input->>'name'),(p_input->>'capacity')::integer,actor) returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Room created.');
 elsif action='PUBLISH_CURRICULUM' then
  select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active;
  select * into year from public.academic_years where id=b.academic_year_id;
  if b.id is null or not exists(select 1 from public.subjects where id=(p_input->>'subject_id')::uuid and organization_id=b.organization_id and is_active) then raise exception 'Choose an active batch and subject in the same organization.';end if;
  rows:=p_input->'units';
  if length(btrim(coalesce(p_input->>'title','')))<2 or rows is null or jsonb_typeof(rows)<>'array' then raise exception 'A title and curriculum units are required.';end if;
  if jsonb_array_length(rows)=0 then raise exception 'Add at least one curriculum unit.';end if;
  for unit in select x from jsonb_array_elements(rows) x loop
   if length(btrim(coalesce(unit->>'title','')))<2 or (unit->>'target_date')::date is null or (unit->>'target_date')::date not between year.starts_on and year.ends_on then raise exception 'Each unit needs a title and target date inside the academic year.';end if;
  end loop;
  insert into public.curriculum_versions(batch_id,subject_id,version,title,units,reason,published_by)
  select b.id,(p_input->>'subject_id')::uuid,coalesce(max(v.version),0)+1,btrim(p_input->>'title'),rows,btrim(p_input->>'reason'),actor from public.curriculum_versions v where v.batch_id=b.id and v.subject_id=(p_input->>'subject_id')::uuid returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Curriculum version published. Earlier versions and session references are preserved.');
 elsif action in('CREATE_ROUTINE','GENERATE_SESSIONS','CREATE_SESSION') then
  if action='GENERATE_SESSIONS' then
   select * into r from public.academic_routines where id=(p_input->>'routine_id')::uuid and retired_at is null;
   if r.id is null then raise exception 'Active routine not found.';end if;
   bid:=r.batch_id;subid:=r.subject_id;tid:=r.teacher_id;roomid:=r.room_id;st:=r.start_time;et:=r.end_time;
   date_from:=(p_input->>'starts_on')::date;date_to:=(p_input->>'ends_on')::date;
   if date_from<r.starts_on or date_to>r.ends_on then raise exception 'Generation dates must stay inside the routine period.';end if;
  else
   bid:=(p_input->>'batch_id')::uuid;subid:=(p_input->>'subject_id')::uuid;tid:=(p_input->>'teacher_id')::uuid;roomid:=(p_input->>'room_id')::uuid;
   st:=(p_input->>'start_time')::time;et:=(p_input->>'end_time')::time;
   date_from:=(p_input->>'starts_on')::date;date_to:=case when action='CREATE_SESSION' then date_from else (p_input->>'ends_on')::date end;
  end if;
  select * into b from public.batches where id=bid and is_active for update;
  select * into room from public.academic_rooms where id=roomid;
  select * into teacher from public.staff where id=tid and status='ACTIVE';
  select * into year from public.academic_years where id=b.academic_year_id;
  select timezone into tz from public.organizations where id=b.organization_id;
  if b.id is null or b.offering_id is null or room.id is null or room.branch_id is distinct from b.branch_id or teacher.id is null then raise exception 'Choose an active batch, active teacher and room in the batch branch.';end if;
  if teacher.branch_id is not null and teacher.branch_id<>b.branch_id then raise exception 'Teacher belongs to a different branch.';end if;
  if room.capacity<b.capacity then raise exception 'Room capacity is below the configured batch capacity.';end if;
  if not exists(select 1 from public.subjects where id=subid and organization_id=b.organization_id and is_active) then raise exception 'Subject is unavailable for this organization.';end if;
  if date_from is null or date_to is null or date_to<date_from or date_from<year.starts_on or date_to>year.ends_on or st is null or et is null or et<=st then raise exception 'Enter valid same-day class times and dates inside the academic year.';end if;
  if not exists(select 1 from public.staff_subject_assignments where staff_id=tid and subject_id=subid and effective_from<=date_from and (effective_to is null or effective_to>=date_to)) or not exists(select 1 from public.staff_role_assignments a join public.staff_roles sr on sr.id=a.staff_role_id where a.staff_id=tid and sr.is_teaching_role and a.effective_from<=date_from and (a.effective_to is null or a.effective_to>=date_to)) then raise exception 'Teacher must have a teaching role and subject qualification covering these dates.';end if;
  if action='CREATE_ROUTINE' then
   if (p_input->>'weekday')::integer is null or (p_input->>'weekday')::integer not between 0 and 6 then raise exception 'Choose a weekday.';end if;
   if exists(select 1 from public.academic_routines x where x.retired_at is null and x.weekday=(p_input->>'weekday')::integer and x.starts_on<=date_to and x.ends_on>=date_from and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing teacher, batch or room assignment.';end if;
   if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.session_date between date_from and date_to and extract(dow from x.session_date)=(p_input->>'weekday')::integer and (x.starts_at at time zone tz)::time<et and (x.ends_at at time zone tz)::time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing dated session.';end if;
   insert into public.academic_routines(batch_id,subject_id,teacher_id,room_id,weekday,start_time,end_time,starts_on,ends_on,created_by)
   values(bid,subid,tid,roomid,(p_input->>'weekday')::integer,st,et,date_from,date_to,actor) returning id into id_out;
   result:=jsonb_build_object('id',id_out,'message','Routine created. Generate dated sessions to make classes operational.');
  else
   if date_to-date_from>93 then raise exception 'Generate at most 94 days per request; split larger jobs.';end if;
   scope:=btrim(coalesce(p_input->>'planned_scope',''));
   if length(scope)<2 then raise exception 'Describe the planned scope for these classes.';end if;
   if nullif(p_input->>'curriculum_id','') is not null then
    select * into cv from public.curriculum_versions where id=(p_input->>'curriculum_id')::uuid and batch_id=bid and subject_id=subid;
    if cv.id is null then raise exception 'Curriculum version must match the session batch and subject.';end if;
   end if;
   for day in select d::date from generate_series(date_from::timestamp,date_to::timestamp,interval '1 day') d loop
    if action='GENERATE_SESSIONS' and extract(dow from day)<>r.weekday then continue;end if;
    if action='GENERATE_SESSIONS' and exists(select 1 from public.class_sessions where routine_id=r.id and session_date=day) then continue;end if;
    start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
    if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.starts_at<end_at and x.ends_at>start_at and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflict on %: teacher, batch or room is occupied. Nothing was posted.',day;end if;
    if exists(select 1 from public.academic_routines x where x.retired_at is null and x.id is distinct from r.id and x.weekday=extract(dow from day) and day between x.starts_on and x.ends_on and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflicts with a reserved routine on %.',day;end if;
    insert into public.class_sessions(routine_id,batch_id,subject_id,teacher_id,room_id,curriculum_version_id,planned_scope,session_date,starts_at,ends_at,created_by)
    values(r.id,bid,subid,tid,roomid,cv.id,scope,day,start_at,end_at,actor) returning id into id_out;
    created:=created+1;
   end loop;
   result:=jsonb_build_object('id',coalesce(id_out,r.id),'message',created||' dated sessions created. Existing routine dates were preserved.');
  end if;
 elsif action='RETIRE_ROUTINE' then
  update public.academic_routines set retired_at=now() where id=(p_input->>'routine_id')::uuid and retired_at is null returning id into id_out;
  if id_out is null then raise exception 'Active routine not found.';end if;
  result:=jsonb_build_object('id',id_out,'message','Routine retired. Existing dated sessions remain; cancel affected occurrences explicitly.');
 else
  if action='DECIDE_ATTENDANCE' then
   select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid and workflow_type='ATTENDANCE';
   if approval.id is null then raise exception 'Attendance approval not found.';end if;
   sid:=approval.entity_id::uuid;
  else sid:=(p_input->>'session_id')::uuid;end if;
  if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.';end if;
  select * into cs from public.class_sessions where id=sid for update;
  select * into last_att from public.attendance_submissions where session_id=sid order by revision desc limit 1;
  if action='CANCEL_SESSION' then
   if cs.status='CANCELLED' then raise exception 'Session already cancelled.';end if;
   if exists(select 1 from public.attendance_submissions where session_id=sid and status in('SUBMITTED','APPROVED')) then raise exception 'A session with submitted or approved attendance cannot be cancelled.';end if;
   update public.class_sessions set status='CANCELLED',cancellation_reason=reason,cancelled_by=actor,cancelled_at=now() where id=sid;
   result:=jsonb_build_object('id',sid,'message','Session cancelled; the original schedule and reason remain in history.');
  elsif action='SAVE_ATTENDANCE' then
   if cs.status<>'SCHEDULED' or cs.starts_at>now() then raise exception 'Attendance can be recorded only after a scheduled class has started.';end if;
   if last_att.status='SUBMITTED' then raise exception 'Attendance is awaiting a decision.';end if;
   if last_att.id is distinct from nullif(p_input->>'base_id','')::uuid then raise exception 'Attendance changed. Refresh before saving a new revision.';end if;
   -- Lock placement while the first roster is snapshotted. Later revisions retain that roster.
   perform 1 from public.batches where id=cs.batch_id for update;
   if last_att.id is null then
    select coalesce(jsonb_agg(jsonb_build_object('student_id',s.id,'enrollment_id',e.id,'number',s.student_no,'name',s.full_name) order by s.student_no),'[]'::jsonb) into roster
    from public.enrollments e join public.students s on s.id=e.student_id where e.batch_id=cs.batch_id and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date) and e.status in('ACTIVE','WITHDRAWN','COMPLETED');
   else roster:=last_att.entries;end if;
   rows:=p_input->'entries';
   if rows is null or jsonb_typeof(rows)<>'array' then raise exception 'Attendance entries are required.';end if;
   if jsonb_array_length(roster)=0 or jsonb_array_length(rows)<>jsonb_array_length(roster) or (select count(distinct x->>'enrollment_id') from jsonb_array_elements(rows) x)<>jsonb_array_length(rows) then raise exception 'Record exactly one attendance status for every roster member. Refresh if the roster changed.';end if;
   for entry in select x from jsonb_array_elements(rows) x loop
    if coalesce(entry->>'status','') not in('PRESENT','ABSENT','LATE','EXCUSED') or not exists(select 1 from jsonb_array_elements(roster) x where x->>'enrollment_id'=entry->>'enrollment_id') or length(coalesce(entry->>'note',''))>500 then raise exception 'Invalid attendance status, note or roster member.';end if;
   end loop;
   select jsonb_agg(x||jsonb_build_object('status',y->>'status','note',coalesce(y->>'note','')) order by x->>'number') into rows from jsonb_array_elements(roster) x join jsonb_array_elements(rows) y on x->>'enrollment_id'=y->>'enrollment_id';
   insert into public.attendance_submissions(session_id,revision,entries,reason,recorded_by) values(sid,coalesce(last_att.revision,0)+1,rows,reason,actor) returning id into id_out;
   result:=jsonb_build_object('id',id_out,'message','Attendance draft saved. Submit it for independent approval.');
  elsif action='SUBMIT_ATTENDANCE' then
   if cs.status<>'SCHEDULED' or last_att.id is distinct from (p_input->>'attendance_id')::uuid or last_att.status<>'DRAFT' then raise exception 'Only the latest saved draft can be submitted.';end if;
   if last_att.recorded_by<>actor then raise exception 'Only the draft author may submit it. Save your own reviewed revision first.';end if;
   insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
   values('ATTENDANCE','CLASS_SESSION',sid::text,action,jsonb_build_object('attendance_id',last_att.id,'revision',last_att.revision,'entries',last_att.entries),reason,actor,req) returning id into id_out;
   update public.attendance_submissions set status='SUBMITTED',approval_id=id_out where id=last_att.id;
   result:=jsonb_build_object('id',id_out,'message','Attendance submitted for independent approval.');
  elsif action='DECIDE_ATTENDANCE' then
   if approval.status<>'PENDING' then raise exception 'Attendance request already decided.';end if;
   select * into att from public.attendance_submissions where id=(approval.payload_snapshot->>'attendance_id')::uuid and status='SUBMITTED';
   if att.id is null then raise exception 'Submitted attendance not found.';end if;
   if actor=approval.requested_by or actor=att.recorded_by then raise exception 'Maker-checker: another authorized person must decide attendance.';end if;
   if p_input->>'decision' not in('APPROVED','REJECTED') or p_input->>'decision' is null then raise exception 'Choose Approve or Reject.';end if;
   update public.attendance_submissions set status=p_input->>'decision' where id=att.id;
   update public.approval_requests set status=(p_input->>'decision')::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
   result:=jsonb_build_object('id',att.id,'message','Attendance '||lower(p_input->>'decision')||'. Prior approved revisions remain in history.');
  end if;
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ACADEMIC_WORKFLOW',result->>'id',action,reason,result,p_input);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);
 return result;
end; $$;
revoke all on function public.academic_command(jsonb) from public,anon;
grant execute on function public.academic_command(jsonb) to authenticated;

-- Final records are immutable; state transitions retain the original payload.
create or replace function public.protect_academic_record()
returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='DELETE' then raise exception 'Academic history cannot be deleted.';end if;
 if tg_table_name='academic_routines' then
  if (to_jsonb(new)-'retired_at') is distinct from (to_jsonb(old)-'retired_at') or old.retired_at is not null or new.retired_at is null then raise exception 'Routine terms are immutable; retire and create a replacement.';end if;
 elsif tg_table_name='class_sessions' then
  if (to_jsonb(new)-array['status','cancellation_reason','cancelled_by','cancelled_at']) is distinct from (to_jsonb(old)-array['status','cancellation_reason','cancelled_by','cancelled_at']) or old.status<>'SCHEDULED' or new.status<>'CANCELLED' then raise exception 'Session schedule is immutable; cancel and create a replacement occurrence.';end if;
 else
  if (to_jsonb(new)-array['status','approval_id']) is distinct from (to_jsonb(old)-array['status','approval_id']) or not ((old.status='DRAFT' and new.status='SUBMITTED' and new.approval_id is not null) or(old.status='SUBMITTED' and new.status in('APPROVED','REJECTED') and new.approval_id=old.approval_id)) then raise exception 'Attendance evidence is immutable; create a new revision.';end if;
 end if;
 return new;
end; $$;
do $$ declare t text;begin
 foreach t in array array['academic_rooms','curriculum_versions','academic_routines','class_sessions','attendance_submissions'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
 if t in('academic_rooms','curriculum_versions') then
 execute format('create trigger academic_immutable before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 else execute format('create trigger academic_immutable before update or delete on public.%I for each row execute function public.protect_academic_record()',t);end if;
 end loop;
end; $$;
create policy academic_room_read on public.academic_rooms for select to authenticated using(public.has_permission('academics.view'));
create policy curriculum_read on public.curriculum_versions for select to authenticated using(public.has_permission('academics.curriculum.manage') or public.has_permission('academics.sessions.manage') or exists(select 1 from public.class_sessions s where s.curriculum_version_id=curriculum_versions.id and public.can_access_class_session(s.id)));
create policy routine_read on public.academic_routines for select to authenticated using(public.has_permission('academics.sessions.manage') or exists(select 1 from public.staff where id=academic_routines.teacher_id and profile_id=auth.uid()));
create policy session_read on public.class_sessions for select to authenticated using(public.can_access_class_session(id));
create policy attendance_read on public.attendance_submissions for select to authenticated using(public.can_access_class_session(session_id));
