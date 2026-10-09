-- Preferred hours never block scheduling; explicit closures and real bookings still do.
alter table public.academic_routines add column curriculum_version_id uuid references public.curriculum_versions(id),add column planned_scope text not null default '' check(length(planned_scope)<=2000);
-- Availability is optional until explicitly configured for the date. Keep actual-session safety checks.
create or replace function public.check_academic_slot(p_batch uuid,p_subject uuid,p_teacher uuid,p_room uuid,p_day date,p_start time,p_end time) returns void language plpgsql security definer set search_path='' as $$
declare b public.batches;o public.programme_offerings;r public.academic_rooms;org public.organizations;resource record;
begin
 select * into b from public.batches where id=p_batch and is_active;select * into o from public.programme_offerings where id=b.offering_id;select * into r from public.academic_rooms where id=p_room and is_active;select * into org from public.organizations where id=b.organization_id;
 if b.id is null or o.id is null or o.status<>'ACTIVE' or r.id is null or r.branch_id<>b.branch_id then raise exception 'Choose an active offering, batch and classroom in the same campus.';end if;
 if p_start is null or p_end is null or p_end<=p_start or p_day is null then raise exception 'Choose valid same-day class times.';end if;
 if p_day<coalesce(o.teaching_starts_on,(select starts_on from public.academic_years where id=o.academic_year_id)) or p_day>coalesce(o.teaching_ends_on,(select ends_on from public.academic_years where id=o.academic_year_id)) then raise exception 'Class date % is outside the programme operating period.',p_day;end if;
 if r.capacity<b.capacity then raise exception 'Classroom has % seats; this batch requires %.',r.capacity,b.capacity;end if;
 if not exists(select 1 from public.subjects where id=p_subject and organization_id=b.organization_id and is_active) or(exists(select 1 from public.programme_offering_subjects where offering_id=o.id) and not exists(select 1 from public.programme_offering_subjects where offering_id=o.id and subject_id=p_subject)) then raise exception 'Select a subject taught in this programme.';end if;
 if not exists(select 1 from public.staff s where s.id=p_teacher and s.status='ACTIVE' and(s.branch_id is null or s.branch_id=b.branch_id)) then raise exception 'Choose an active teacher/staff identity in the batch campus.';end if;
 -- Programme/batch weekdays and windows are defaults, not routine assignment restrictions.
 for resource in select 'ROOM'::text kind,p_room id union all select 'TEACHER',p_teacher loop
  if public.academic_closed(b.organization_id,b.branch_id,p_day,resource.kind,resource.id) then raise exception '% is closed/unavailable on %. Choose another date/resource.',resource.kind,p_day;end if;

 end loop;
end $$;


CREATE OR REPLACE FUNCTION public.academic_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 if action in('SAVE_ATTENDANCE','SUBMIT_ATTENDANCE','DECIDE_ATTENDANCE') then return public.attendance_command(p_input);end if;
 -- Serialize schedule conflict checks and attendance/session-state transitions.
 if action='CREATE_ROOM' then
  if not exists(select 1 from public.branches where id=(p_input->>'branch_id')::uuid and is_active) then raise exception 'Choose an active branch.';end if;
  insert into public.academic_rooms(branch_id,name,capacity,created_by) values((p_input->>'branch_id')::uuid,btrim(p_input->>'name'),(p_input->>'capacity')::integer,actor) returning id into id_out;
  result:=jsonb_build_object('id',id_out,'message','Room created.');
 elsif action='PUBLISH_CURRICULUM' then
  select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active;
  select * into year from public.academic_years where id=b.academic_year_id;
  year.starts_on:=coalesce((select teaching_starts_on from public.programme_offerings where id=b.offering_id),year.starts_on);
  year.ends_on:=coalesce((select teaching_ends_on from public.programme_offerings where id=b.offering_id),year.ends_on);
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
  select * into room from public.academic_rooms where id=roomid and is_active;
  select * into teacher from public.staff where id=tid and status='ACTIVE';
  select * into year from public.academic_years where id=b.academic_year_id;
  year.starts_on:=coalesce((select teaching_starts_on from public.programme_offerings where id=b.offering_id),year.starts_on);
  year.ends_on:=coalesce((select teaching_ends_on from public.programme_offerings where id=b.offering_id),year.ends_on);
  select timezone into tz from public.organizations where id=b.organization_id;
  if b.id is null or b.offering_id is null or room.id is null or room.branch_id is distinct from b.branch_id or teacher.id is null then raise exception 'Choose an active batch, active teacher and room in the batch branch.';end if;
  if teacher.branch_id is not null and teacher.branch_id<>b.branch_id then raise exception 'Teacher belongs to a different branch.';end if;
  if room.capacity<b.capacity then raise exception 'Room capacity is below the configured batch capacity.';end if;
  if not exists(select 1 from public.subjects where id=subid and organization_id=b.organization_id and is_active) then raise exception 'Subject is unavailable for this organization.';end if;
  if date_from is null or date_to is null or date_to<date_from or date_from<year.starts_on or date_to>year.ends_on or st is null or et is null or et<=st then raise exception 'Enter valid same-day class times and dates inside the academic year.';end if;
  -- Subject qualification is advisory. Active identity, campus, availability and conflicts remain enforced.
  if action='CREATE_ROUTINE' then
   if nullif(p_input->>'curriculum_id','') is not null then select * into cv from public.curriculum_versions where id=(p_input->>'curriculum_id')::uuid and batch_id=bid and subject_id=subid;if cv.id is null then raise exception 'Teaching plan must match the batch and subject.';end if;end if;
   if (p_input->>'weekday')::integer is null or (p_input->>'weekday')::integer not between 0 and 6 then raise exception 'Choose a weekday.';end if;
   if exists(select 1 from public.academic_routines x where x.retired_at is null and x.weekday=(p_input->>'weekday')::integer and x.starts_on<=date_to and x.ends_on>=date_from and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing teacher, batch or room assignment.';end if;
   if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.session_date between date_from and date_to and extract(dow from x.session_date)=(p_input->>'weekday')::integer and (x.starts_at at time zone tz)::time<et and (x.ends_at at time zone tz)::time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Routine conflicts with an existing dated session.';end if;
   insert into public.academic_routines(batch_id,subject_id,teacher_id,room_id,weekday,start_time,end_time,starts_on,ends_on,created_by,curriculum_version_id,planned_scope)
   values(bid,subid,tid,roomid,(p_input->>'weekday')::integer,st,et,date_from,date_to,actor,cv.id,btrim(coalesce(p_input->>'planned_scope',''))) returning id into id_out;
   result:=jsonb_build_object('id',id_out,'message','Routine created. Generate dated sessions to make classes operational.');
  else
   if date_to-date_from>93 then raise exception 'Generate at most 94 days per request; split larger jobs.';end if;
   scope:=btrim(coalesce(nullif(p_input->>'planned_scope',''),nullif(r.planned_scope,''),'Scheduled subject teaching'));
   if length(scope)<2 then raise exception 'Describe the planned scope for these classes.';end if;
   if coalesce(nullif(p_input->>'curriculum_id','')::uuid,r.curriculum_version_id) is not null then
    select * into cv from public.curriculum_versions where id=coalesce(nullif(p_input->>'curriculum_id','')::uuid,r.curriculum_version_id) and batch_id=bid and subject_id=subid;
    if cv.id is null then raise exception 'Curriculum version must match the session batch and subject.';end if;
   end if;
   for day in select d::date from generate_series(date_from::timestamp,date_to::timestamp,interval '1 day') d loop
    if action='GENERATE_SESSIONS' and extract(dow from day)<>r.weekday then continue;end if;
    if action='GENERATE_SESSIONS' and (public.academic_closed(b.organization_id,b.branch_id,day,'ROOM',roomid) or public.academic_closed(b.organization_id,b.branch_id,day,'TEACHER',tid)) then continue;end if;
    if action='GENERATE_SESSIONS' and exists(select 1 from public.class_sessions where routine_id=r.id and session_date=day) then continue;end if;
    start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
    if action='GENERATE_SESSIONS' and coalesce((p_input->>'skip_past')::boolean,false) and start_at<now() then continue;end if;
    if exists(select 1 from public.class_sessions x where x.status='SCHEDULED' and x.starts_at<end_at and x.ends_at>start_at and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflict on %: teacher, batch or room is occupied. Nothing was posted.',day;end if;
    if exists(select 1 from public.academic_routines x where x.retired_at is null and x.id is distinct from coalesce(r.id,(with recursive lineage as(select id,routine_id,replacement_for_id from public.class_sessions where id=nullif(current_setting('sohoj.replacement_for',true),'')::uuid union all select ancestor.id,ancestor.routine_id,ancestor.replacement_for_id from public.class_sessions ancestor join lineage previous on ancestor.id=previous.replacement_for_id) select routine_id from lineage where routine_id is not null limit 1)) and x.weekday=extract(dow from day) and day between x.starts_on and x.ends_on and x.start_time<et and x.end_time>st and (x.batch_id=bid or x.teacher_id=tid or x.room_id=roomid)) then raise exception 'Session conflicts with a reserved routine on %.',day;end if;
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
end; $function$;

-- Routine is a reservation; dated sessions verify actual resource availability.
create or replace function public.weekly_timetable_preview(p_input jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare b public.batches;o public.programme_offerings;start_day date:=nullif(p_input->>'starts_on','')::date;end_day date:=nullif(p_input->>'ends_on','')::date;through_day date;slot jsonb;other jsonb;i int;day date;st time;et time;teacher uuid;subject uuid;room uuid;tz text;start_at timestamptz;end_at timestamptz;clash record;message text;days jsonb:='[]';issues jsonb:='[]';class_status text;period_start date;period_end date;replace_id uuid:=nullif(p_input->>'replace_routine_id','')::uuid;warnings jsonb:='[]';resource record;resource_name text;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not public.has_permission('academics.sessions.manage') then raise exception 'Academic planning permission required.';end if;
 select * into b from public.batches where id=nullif(p_input->>'batch_id','')::uuid and is_active;
 select * into o from public.programme_offerings where id=b.offering_id and status='ACTIVE';
 if b.id is null or o.id is null or b.organization_id is distinct from(select id from public.organizations where code='SOHOJ' and is_active) then raise exception 'Choose an active batch and programme.';end if;
 select coalesce(o.teaching_starts_on,y.starts_on),coalesce(o.teaching_ends_on,y.ends_on) into period_start,period_end from(select 1)dummy left join public.academic_years y on y.id=o.academic_year_id;
 if start_day is null or end_day is null or start_day<(now() at time zone 'Asia/Dhaka')::date or end_day<start_day or end_day-start_day>730 or start_day<period_start or end_day>period_end then raise exception 'Start today or later, within the programme dates. Check the end date.';end if;
 if jsonb_typeof(p_input->'slots') is distinct from 'array' or coalesce(jsonb_array_length(p_input->'slots'),0) not between 1 and 40 then raise exception 'Add 1–40 weekly class rows.';end if;
 select timezone into tz from public.organizations where id=b.organization_id;
 if replace_id is not null then
  if not exists(select 1 from public.academic_routines where id=replace_id and batch_id=b.id and retired_at is null) then raise exception 'Active routine to replace was not found in this batch.';end if;
  if exists(select 1 from public.class_sessions cs where cs.routine_id=replace_id and cs.status='SCHEDULED' and cs.session_date>=start_day and(cs.starts_at<=now() or exists(select 1 from public.class_teaching_clocks where session_id=cs.id) or exists(select 1 from public.attendance_submissions where session_id=cs.id) or exists(select 1 from public.class_logs where session_id=cs.id))) then raise exception 'A class has already started or has attendance/teaching evidence. Choose a later change date.';end if;
 end if;
 through_day:=least(end_day,start_day+27);
 for slot,i in select value,ordinality::int from jsonb_array_elements(p_input->'slots') with ordinality loop
  st:=nullif(slot->>'start_time','')::time;et:=nullif(slot->>'end_time','')::time;teacher:=nullif(slot->>'teacher_id','')::uuid;subject:=nullif(slot->>'subject_id','')::uuid;room:=nullif(slot->>'room_id','')::uuid;
  if st is null or et is null or et<=st or nullif(slot->>'weekday','')::int not between 0 and 6 or nullif(slot->>'weekday','') is null then raise exception 'Row %: choose a day and valid start/end times.',i;end if;
  if not exists(select 1 from public.staff where id=teacher and status='ACTIVE' and(branch_id is null or branch_id=b.branch_id)) or not exists(select 1 from public.academic_rooms where id=room and is_active and branch_id=b.branch_id and capacity>=b.capacity) or not exists(select 1 from public.subjects where id=subject and organization_id=b.organization_id and is_active) or(exists(select 1 from public.programme_offering_subjects where offering_id=o.id) and not exists(select 1 from public.programme_offering_subjects where offering_id=o.id and subject_id=subject)) then raise exception 'Row %: check active teacher, programme subject and classroom campus/capacity.',i;end if;
  if nullif(slot->>'curriculum_id','') is not null and not exists(select 1 from public.curriculum_versions where id=(slot->>'curriculum_id')::uuid and batch_id=b.id and subject_id=subject) then raise exception 'Row %: teaching plan must match the batch and subject.',i;end if;
  for resource in select 'ROOM'::text kind,room id union all select 'TEACHER',teacher loop
   if exists(select 1 from generate_series(start_day::timestamp,through_day::timestamp,interval '1 day') dd where extract(dow from dd)=(slot->>'weekday')::int and exists(select 1 from public.academic_availability a where a.resource_kind=resource.kind and a.resource_id=resource.id and a.is_active and dd::date between a.starts_on and a.ends_on) and not coalesce((select range_agg(tsrange(dd::date+a.start_time,dd::date+a.end_time,'[)')) @> tsrange(dd::date+st,dd::date+et,'[)') from public.academic_availability a where a.resource_kind=resource.kind and a.resource_id=resource.id and a.is_active and a.weekday=extract(dow from dd) and dd::date between a.starts_on and a.ends_on),false)) then
    if resource.kind='ROOM' then select name into resource_name from public.academic_rooms where id=resource.id;else select full_name into resource_name from public.staff where id=resource.id;end if;
    warnings:=warnings||jsonb_build_array(jsonb_build_object('row',i,'message',resource_name||': outside saved preferred hours. This is a preference, not a booking conflict; you may save this routine.'));
   end if;
  end loop;
  for other in select value from jsonb_array_elements(p_input->'slots') with ordinality where ordinality<i loop
   if(other->>'weekday')::int=(slot->>'weekday')::int and(other->>'start_time')::time<et and(other->>'end_time')::time>st then issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','Two rows overlap for this batch. Change their day or time.'));end if;
  end loop;
  for clash in select r.id,ba.name batch_name,t.full_name teacher_name,rm.name room_name from public.academic_routines r join public.batches ba on ba.id=r.batch_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where r.retired_at is null and r.id is distinct from replace_id and r.weekday=(slot->>'weekday')::int and r.starts_on<=end_day and r.ends_on>=start_day and r.start_time<et and r.end_time>st and(r.batch_id=b.id or r.teacher_id=teacher or r.room_id=room) loop
   issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','Existing weekly routine: '||clash.batch_name||' · '||clash.teacher_name||' · '||clash.room_name));
  end loop;
  if exists(select 1 from public.class_sessions s where s.status='SCHEDULED' and (replace_id is null or s.routine_id is distinct from replace_id) and s.session_date between start_day and end_day and extract(dow from s.session_date)=(slot->>'weekday')::int and(s.starts_at at time zone tz)::time<et and(s.ends_at at time zone tz)::time>st and(s.batch_id=b.id or s.teacher_id=teacher or s.room_id=room)) then issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','A dated class already occupies this teacher, room or batch. Check the class calendar.'));end if;
  for day in select d::date from generate_series(start_day::timestamp,through_day::timestamp,interval '1 day')d where extract(dow from d)=(slot->>'weekday')::int loop
   class_status:='READY';message:='';start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
   if start_at<now() then class_status:='SKIPPED';message:='Time has already passed';
   elsif public.academic_closed(b.organization_id,b.branch_id,day,'ROOM',room) or public.academic_closed(b.organization_id,b.branch_id,day,'TEACHER',teacher) then class_status:='SKIPPED';message:='Holiday or recorded room/teacher unavailability';
   else begin perform public.check_academic_slot(b.id,subject,teacher,room,day,st,et);exception when others then get stacked diagnostics message=MESSAGE_TEXT;class_status:='CONFLICT';issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message',day::text||': '||message));end;end if;
   days:=days||jsonb_build_array(jsonb_build_object('row',i,'date',day,'start_time',st,'end_time',et,'status',class_status,'message',message));
  end loop;
 end loop;
 return jsonb_build_object('from',start_day,'through',through_day,'classes',days,'issues',issues,'warnings',warnings,'ready',jsonb_array_length(issues)=0,'count',(select count(*) from jsonb_array_elements(days)x where x->>'status'='READY'));
end $$;

create or replace function public.weekly_timetable_save(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;key public.admission_command_keys;preview jsonb;slot jsonb;i int;result jsonb;ids jsonb:='[]';scope text;subject_name text;rid uuid;why text:=btrim(coalesce(p_input->>'reason',''));replace_id uuid:=nullif(p_input->>'replace_routine_id','')::uuid;old_class record;cancelled int:=0;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.sessions.manage') then raise exception 'Academic planning permission required.';end if;
 if req is null or length(why) not between 5 and 500 then raise exception 'A request identity and reason are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 preview:=public.weekly_timetable_preview(p_input);
 if not(preview->>'ready')::boolean then raise exception 'Timetable conflicts remain. Preview again and correct the highlighted rows.';end if;
 if replace_id is not null then
  perform public.academic_command(jsonb_build_object('action','RETIRE_ROUTINE','routine_id',replace_id,'request_id',md5(req::text||':retire')::uuid,'reason',why));
  for old_class in select id from public.class_sessions where routine_id=replace_id and status='SCHEDULED' and session_date>=(p_input->>'starts_on')::date loop
   perform public.academic_schedule_command(jsonb_build_object('action','CANCEL','session_id',old_class.id,'request_id',md5(req::text||':cancel:'||old_class.id)::uuid,'reason',why));cancelled:=cancelled+1;
  end loop;
 end if;
 for slot,i in select value,ordinality::int from jsonb_array_elements(p_input->'slots') with ordinality loop
  result:=public.academic_command(slot||jsonb_build_object('action','CREATE_ROUTINE','batch_id',p_input->>'batch_id','starts_on',p_input->>'starts_on','ends_on',p_input->>'ends_on','request_id',md5(req::text||':routine:'||i)::uuid,'reason',why));rid:=(result->>'id')::uuid;ids:=ids||jsonb_build_array(rid);
  select name into subject_name from public.subjects where id=(slot->>'subject_id')::uuid;scope:=coalesce(nullif(btrim(slot->>'planned_scope'),''),'Scheduled teaching · '||subject_name);
  perform public.academic_command(jsonb_build_object('action','GENERATE_SESSIONS','routine_id',rid,'starts_on',preview->>'from','ends_on',preview->>'through','skip_past',true,'curriculum_id',slot->>'curriculum_id','planned_scope',scope,'request_id',md5(req::text||':classes:'||i)::uuid,'reason',why));
 end loop;
 result:=jsonb_build_object('id',ids->>0,'ids',ids,'class_count',preview->'count','from',preview->'from','through',preview->'through','replaced_routine_id',replace_id,'cancelled_classes',cancelled,'message','Weekly routine and first four weeks of classes saved.');
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'WEEKLY_TIMETABLE',result->>'id','SAVE_AND_GENERATE',why,result,req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.weekly_timetable_preview(jsonb),public.weekly_timetable_save(jsonb) from public,anon;
grant execute on function public.weekly_timetable_preview(jsonb),public.weekly_timetable_save(jsonb) to authenticated;
notify pgrst,'reload schema';
