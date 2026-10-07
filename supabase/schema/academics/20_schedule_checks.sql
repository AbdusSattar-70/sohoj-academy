-- Coverage is the union of active windows: adjacent windows cover a longer class.
create function public.resource_window_covers(p_academy uuid,p_kind text,p_resource uuid,p_start text,p_end text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce((select range_agg(tsrange((p_start::timestamptz at time zone 'Asia/Dhaka')::date+w.starts,(p_start::timestamptz at time zone 'Asia/Dhaka')::date+w.ends,'[)')) @> tsrange(p_start::timestamptz at time zone 'Asia/Dhaka',p_end::timestamptz at time zone 'Asia/Dhaka','[)')
 from public.academic_resource_windows w where w.academy_id=p_academy and w.resource_kind=p_kind and w.resource_id=p_resource and w.is_active and w.weekday=extract(dow from p_start::timestamptz at time zone 'Asia/Dhaka')),false)
 and (p_start::timestamptz at time zone 'Asia/Dhaka')::date=(p_end::timestamptz at time zone 'Asia/Dhaka')::date
$$;
revoke all on function public.resource_window_covers(uuid,text,uuid,text,text) from public,anon,authenticated;

create function public.preview_academic_schedule(p_payload jsonb) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); cmd text:=p_payload->>'action'; bid uuid; tid uuid; rid uuid; sub uuid; sid uuid; batch public.teaching_batches; programme public.programme_runs; room public.academic_rooms;
 teacher_name text; dates date[]; d date; st timestamptz; en timestamptz; start_time time; end_time time; kind text; resource uuid; resource_name text; available jsonb; issue jsonb; issues jsonb:='[]'; warnings jsonb:='[]'; classes jsonb:='[]'; skipped jsonb:='[]'; conflict record; day_values int[];
begin
 if cmd not in('CREATE','CHANGE','MAKEUP','ROUTINE') then raise exception 'Choose a scheduling action.'; end if;
 bid:=nullif(p_payload->>'batchId','')::uuid;tid:=nullif(p_payload->>'teacherId','')::uuid;rid:=nullif(p_payload->>'roomId','')::uuid;sub:=nullif(p_payload->>'subjectId','')::uuid;sid:=nullif(p_payload->>'id','')::uuid;
 select * into batch from public.teaching_batches where id=bid and academy_id=aid and is_active;
 if not found then raise exception 'Select an active batch.'; end if;
 select * into programme from public.programme_runs where id=batch.run_id and academy_id=aid and is_active;
 if not found then raise exception 'The programme offering is inactive.'; end if;
 if not exists(select 1 from public.run_subjects rs join public.directory_entries e on e.id=rs.subject_id and e.is_active where rs.run_id=programme.id and rs.subject_id=sub and rs.is_active) then raise exception 'Select a subject taught by this offering.'; end if;
 select * into room from public.academic_rooms where id=rid and academy_id=aid and is_active;
 if not found then raise exception 'Select an active classroom.'; end if;
 if room.capacity<batch.capacity then issues:=issues||jsonb_build_array(jsonb_build_object('code','CAPACITY','message',format('%s has %s seats; %s needs %s.',room.name,room.capacity,batch.name,batch.capacity),'href','/dashboard/academics/settings?section=rooms')); end if;
 select p.full_name into teacher_name from public.people p where p.id=tid and p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility='TEACHER' and r.is_active);
 if teacher_name is null then raise exception 'Select an active teacher.'; end if;
 if not exists(select 1 from public.teacher_subject_qualifications q where q.academy_id=aid and q.teacher_id=tid and q.subject_id=sub and q.is_active) then issues:=issues||jsonb_build_array(jsonb_build_object('code','QUALIFICATION','message',format('%s is not qualified for the selected subject.',teacher_name),'href','/dashboard/academics/settings?section=teachers')); end if;
 if cmd='ROUTINE' then
  if (p_payload->>'endsOn')::date-(p_payload->>'startsOn')::date not between 0 and 31 then raise exception 'Choose 1 to 32 days per generation.'; end if;
  day_values:=array(select value::int from jsonb_array_elements_text(p_payload->'weekdays'));
  if cardinality(day_values)=0 or not day_values<@array[0,1,2,3,4,5,6] then raise exception 'Select at least one weekday.'; end if;
  start_time:=(p_payload->>'startTime')::time;end_time:=(p_payload->>'endTime')::time;
  dates:=array(select day::date from generate_series((p_payload->>'startsOn')::date,(p_payload->>'endsOn')::date,interval '1 day') ds(day) where extract(dow from day)::int=any(day_values));
 else
  st:=(p_payload->>'start')::timestamptz;en:=(p_payload->>'end')::timestamptz;
  if st is null or en is null or (st at time zone 'Asia/Dhaka')::date is distinct from (en at time zone 'Asia/Dhaka')::date then raise exception 'Choose start and end on the same day.'; end if;
  dates:=array[(st at time zone 'Asia/Dhaka')::date];start_time:=(st at time zone 'Asia/Dhaka')::time;end_time:=(en at time zone 'Asia/Dhaka')::time;
 end if;
 if start_time is null or end_time is null or end_time<=start_time or end_time-start_time>interval '12 hours' then raise exception 'Choose an end time after start, within 12 hours.'; end if;
 foreach d in array dates loop
  st:=(d+start_time) at time zone 'Asia/Dhaka';en:=(d+end_time) at time zone 'Asia/Dhaka';
  if exists(select 1 from public.academic_closures c where c.academy_id=aid and c.is_active and c.closed_on=d) then
   if cmd='ROUTINE' then skipped:=skipped||jsonb_build_array(d);continue; else issues:=issues||jsonb_build_array(jsonb_build_object('code','HOLIDAY','date',d,'message',format('The academy is closed on %s.',d),'href','/dashboard/academics/settings?section=holidays')); end if;
  end if;
  classes:=classes||jsonb_build_array(jsonb_build_object('date',d,'start',st,'end',en));
  if d<programme.starts_on or d>programme.ends_on then issues:=issues||jsonb_build_array(jsonb_build_object('code','DATES','date',d,'message',format('%s is outside offering dates %s–%s.',d,programme.starts_on,programme.ends_on),'href','/dashboard/academics/programmes')); end if;
  for kind,resource,resource_name in select 'TEACHER',tid,teacher_name union all select 'ROOM',rid,room.name loop
   if not public.resource_window_covers(aid,kind,resource,st::text,en::text) then
    select coalesce(jsonb_agg(jsonb_build_object('start',w.starts,'end',w.ends) order by w.starts),'[]') into available from public.academic_resource_windows w where w.academy_id=aid and w.resource_kind=kind and w.resource_id=resource and w.is_active and w.weekday=extract(dow from d)::int;
    issue:=jsonb_build_object('code','AVAILABILITY','date',d,'resource',resource_name,'kind',kind,'windows',available,'message',format('%s: %s %s–%s is not fully covered. Active windows for this weekday: %s.',resource_name,d,start_time,end_time,available),'href','/dashboard/academics/settings?section=availability');
    if coalesce((p_payload->>'confirmAvailability')::boolean,false) then warnings:=warnings||jsonb_build_array(issue);else issues:=issues||jsonb_build_array(issue); end if;
   end if;
   for conflict in select b.* from public.academic_resource_blocks b where b.academy_id=aid and b.resource_kind=kind and b.resource_id=resource and b.is_active and b.starts_at<en and b.ends_at>st loop
    issues:=issues||jsonb_build_array(jsonb_build_object('code','BLOCK','date',d,'message',format('%s is unavailable: %s.',resource_name,conflict.reason),'href','/dashboard/academics/settings?section=teachers'));
   end loop;
  end loop;
  for conflict in select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id where s.academy_id=aid and s.status<>'CANCELLED' and (cmd<>'CHANGE' or s.id is distinct from sid) and s.starts_at<en and s.ends_at>st and(s.batch_id=bid or s.teacher_id=tid or s.room_id=rid) loop
   issues:=issues||jsonb_build_array(jsonb_build_object('code','BOOKING','date',d,'sessionId',conflict.id,'message',format('%s · %s · %s is booked on %s %s–%s.',conflict.batch_name,conflict.teacher_name,conflict.room_name,d,(conflict.starts_at at time zone 'Asia/Dhaka')::time,(conflict.ends_at at time zone 'Asia/Dhaka')::time),'href','/dashboard/academics/calendar'));
  end loop;
 end loop;
 if jsonb_array_length(classes)=0 then issues:=issues||jsonb_build_array(jsonb_build_object('code','EMPTY','message','No teaching dates: adjust dates or weekdays.')); end if;
 return jsonb_build_object('ok',jsonb_array_length(issues)=0,'issues',issues,'warnings',warnings,'classes',classes,'skipped',skipped);
end $$;
revoke all on function public.preview_academic_schedule(jsonb) from public,anon;
grant execute on function public.preview_academic_schedule(jsonb) to authenticated;

create or replace function public.academic_prepared_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid; cmd text:=p_payload->>'action'; prior jsonb; rid uuid; d date; result jsonb; payload jsonb; start_value timestamptz; end_value timestamptz; resource uuid; kind text; day_value int; s public.academic_sessions;
begin
 aid:=public.require_operation('academics.view');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_'||cmd,p_payload);if prior is not null then return prior; end if;
 if cmd in('CREATE','CHANGE','MAKEUP','ROUTINE') then
  perform public.require_operation('academics.manage');
  if cmd='ROUTINE' then
   if (p_payload->>'endsOn')::date-(p_payload->>'startsOn')::date not between 0 and 31 then raise exception 'Generate at most 32 days per routine.'; end if;
  else
   start_value:=(p_payload->>'start')::timestamptz;end_value:=(p_payload->>'end')::timestamptz;
   if exists(select 1 from public.academic_closures where academy_id=aid and is_active and closed_on=(start_value at time zone 'Asia/Dhaka')::date) then raise exception 'The academy is closed on this date.'; end if;
   for kind,resource in select 'TEACHER',(p_payload->>'teacherId')::uuid union all select 'ROOM',(p_payload->>'roomId')::uuid loop
    if not public.resource_window_covers(aid,kind,resource,start_value::text,end_value::text) then raise exception '% availability does not cover % %–% (Bangladesh time). Check the selected resource, weekday, Active status and full time window.',kind,(start_value at time zone 'Asia/Dhaka')::date,(start_value at time zone 'Asia/Dhaka')::time,(end_value at time zone 'Asia/Dhaka')::time; end if;
   end loop;
  end if;
 end if;
 if cmd not in('WINDOW','CLOSURE','ROUTINE','CONTACT_INACTIVE') then return public.academic_session_command(p_request_id,p_payload); end if;
 perform public.require_operation('academics.manage');perform public.check_change_reason(p_payload->>'reason');
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_'||cmd,p_payload);if prior is not null then return prior; end if;
 if cmd='WINDOW' then
  kind:=p_payload->>'kind';resource:=(p_payload->>'resourceId')::uuid;
  if(kind='ROOM' and not exists(select 1 from public.academic_rooms where id=resource and academy_id=aid)) or(kind='TEACHER' and not exists(select 1 from public.people p join public.person_responsibilities x on x.person_id=p.id and x.responsibility='TEACHER' and x.is_active where p.id=resource and p.academy_id=aid)) then raise exception 'Select an academy resource.'; end if;
  insert into public.academic_resource_windows(academy_id,resource_kind,resource_id,weekday,starts,ends,is_active) values(aid,kind,resource,(p_payload->>'weekday')::int,(p_payload->>'startTime')::time,(p_payload->>'endTime')::time,coalesce((p_payload->>'active')::boolean,true)) on conflict(academy_id,resource_kind,resource_id,weekday,starts,ends) do update set is_active=excluded.is_active returning id into rid;
 elsif cmd='CLOSURE' then
  if exists(select 1 from public.academic_sessions where academy_id=aid and status<>'CANCELLED' and(starts_at at time zone 'Asia/Dhaka')::date=(p_payload->>'date')::date) then raise exception 'Cancel or reschedule existing classes before marking the day closed.'; end if;
  insert into public.academic_closures(academy_id,closed_on,name,is_active) values(aid,(p_payload->>'date')::date,p_payload->>'name',coalesce((p_payload->>'active')::boolean,true)) on conflict(academy_id,closed_on) do update set name=excluded.name,is_active=excluded.is_active returning id into rid;
 elsif cmd='CONTACT_INACTIVE' then
  update public.academic_notification_contacts set is_active=false where id=(p_payload->>'id')::uuid and academy_id=aid returning id into rid;
  if rid is null then raise exception 'Contact not found.'; end if;
 else
  insert into public.academic_routines(academy_id,batch_id,subject_id,teacher_id,room_id,starts_on,ends_on,weekdays,starts,ends) values(aid,(p_payload->>'batchId')::uuid,(p_payload->>'subjectId')::uuid,(p_payload->>'teacherId')::uuid,(p_payload->>'roomId')::uuid,(p_payload->>'startsOn')::date,(p_payload->>'endsOn')::date,array(select value::int from jsonb_array_elements_text(p_payload->'weekdays')),(p_payload->>'startTime')::time,(p_payload->>'endTime')::time) returning id into rid;
  for d in select generate_series((p_payload->>'startsOn')::date,(p_payload->>'endsOn')::date,interval '1 day')::date loop
   if extract(dow from d)::int=any(array(select value::int from jsonb_array_elements_text(p_payload->'weekdays'))) and not exists(select 1 from public.academic_closures where academy_id=aid and closed_on=d and is_active) then
    payload:=p_payload||jsonb_build_object('action','CREATE','start',((d+(p_payload->>'startTime')::time) at time zone 'Asia/Dhaka'),'end',((d+(p_payload->>'endTime')::time) at time zone 'Asia/Dhaka'));
    result:=public.academic_command(gen_random_uuid(),payload);
    update public.academic_sessions set routine_id=rid where id=(result->>'id')::uuid;
   end if;
  end loop;
 end if;
 return public.finish_operation(p_request_id,'ACADEMIC_'||cmd,p_payload,jsonb_build_object('id',rid),'ACADEMIC_SETUP',rid,null);
end $$;

create or replace function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid; cmd text:=p_payload->>'action'; prior jsonb; d date; weekdays int[]; start_time time; end_time time; kind text; resource uuid; day_no int; checked jsonb;
begin
 aid:=public.require_operation('academics.view');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_'||cmd,p_payload);
 if prior is not null then return prior; end if;
 if cmd in('CREATE','CHANGE','MAKEUP','ROUTINE') then
  checked:=public.preview_academic_schedule(p_payload);
  if not (checked->>'ok')::boolean then raise exception '%',checked->'issues'->0->>'message'; end if;
 end if;
 if cmd='ROUTINE' then
  perform public.require_operation('academics.manage');
  if (p_payload->>'endsOn')::date-(p_payload->>'startsOn')::date not between 0 and 31 then raise exception 'Choose a date range of 1 to 32 days.'; end if;
  weekdays:=array(select value::int from jsonb_array_elements_text(p_payload->'weekdays'));
  if cardinality(weekdays)=0 or not weekdays<@array[0,1,2,3,4,5,6] then raise exception 'Select at least one valid weekday.'; end if;
  if not exists(select 1 from generate_series((p_payload->>'startsOn')::date,(p_payload->>'endsOn')::date,interval '1 day') dates(day) where extract(dow from day)::int=any(weekdays) and not exists(select 1 from public.academic_closures c where c.academy_id=aid and c.is_active and c.closed_on=day::date)) then raise exception 'No teaching dates match this routine. Adjust dates or weekdays.'; end if;
 end if;
 if cmd in('CREATE','CHANGE','MAKEUP','ROUTINE') and coalesce((p_payload->>'confirmAvailability')::boolean,false) then
  perform public.require_operation('academics.manage');
  perform public.check_change_reason(p_payload->>'reason');
  if cmd='ROUTINE' then
   start_time:=(p_payload->>'startTime')::time;end_time:=(p_payload->>'endTime')::time;
  else
   d:=((p_payload->>'start')::timestamptz at time zone 'Asia/Dhaka')::date;
   if d is distinct from ((p_payload->>'end')::timestamptz at time zone 'Asia/Dhaka')::date then raise exception 'A class must start and finish on the same day.'; end if;
   weekdays:=array[extract(dow from d)::int];
   start_time:=((p_payload->>'start')::timestamptz at time zone 'Asia/Dhaka')::time;
   end_time:=((p_payload->>'end')::timestamptz at time zone 'Asia/Dhaka')::time;
  end if;
  if end_time<=start_time then raise exception 'End time must be after start time.'; end if;
  for kind,resource in select 'TEACHER',(p_payload->>'teacherId')::uuid union all select 'ROOM',(p_payload->>'roomId')::uuid loop
   foreach day_no in array weekdays loop
    if not exists(select 1 from public.academic_resource_windows w where w.academy_id=aid and w.resource_kind=kind and w.resource_id=resource and w.weekday=day_no and w.is_active and w.starts<=start_time and w.ends>=end_time) then
     perform public.academic_prepared_command(gen_random_uuid(),jsonb_build_object('action','WINDOW','kind',kind,'resourceId',resource,'weekday',day_no,'startTime',start_time,'endTime',end_time,'active',true,'reason',p_payload->>'reason'));
    end if;
   end loop;
  end loop;
 end if;
 return public.academic_prepared_command(p_request_id,p_payload);
end $$;
revoke all on function public.academic_command(uuid,jsonb) from public,anon;
grant execute on function public.academic_command(uuid,jsonb) to authenticated;
