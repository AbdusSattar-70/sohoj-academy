-- Distinguish teachers with the same name without merging permanent identities.
create function public.teacher_resource_name(p_id uuid) returns text language sql stable security definer set search_path=public,pg_temp as $$
 select p.full_name||case when p.staff_no is not null then ' · SA-STF-'||lpad(p.staff_no::text,greatest(5,length(p.staff_no::text)),'0') else '' end from public.people p where p.id=p_id and p.academy_id=public.current_academy_id()
$$;
revoke all on function public.teacher_resource_name(uuid) from public,anon,authenticated;

create or replace function public.academic_operation_choices(p_section text default 'SESSION') returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage');
begin
 if p_section not in('SESSION','QUALIFICATIONS','AVAILABILITY','CONTACTS') then raise exception 'Choose an academic work area.'; end if;
 return jsonb_build_object(
 'rooms',case when p_section in('SESSION','AVAILABILITY','QUALIFICATIONS') then coalesce((select jsonb_agg(to_jsonb(r) order by name) from public.academic_rooms r where academy_id=aid and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'teachers',case when p_section in('SESSION','QUALIFICATIONS','AVAILABILITY') then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',public.teacher_resource_name(p.id)) order by p.full_name)
   from public.people p where p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities x where x.person_id=p.id and x.responsibility='TEACHER' and x.is_active)),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',case when p_section in('SESSION','QUALIFICATIONS') then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name) order by sort_order,name) from public.directory_entries d where academy_id=aid and kind='SUBJECT' and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'qualifications',case when p_section='SESSION' then coalesce((select jsonb_agg(jsonb_build_object('teacherId',q.teacher_id,'subjectId',q.subject_id)) from public.teacher_subject_qualifications q where q.academy_id=aid and q.is_active),'[]'::jsonb) else '[]'::jsonb end,
 'batches',case when p_section in('SESSION','CONTACTS') then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||r.title,'startsOn',r.starts_on,'endsOn',r.ends_on,'defaultDays',r.default_weekdays,'slots',b.planned_slots,'subjectIds',coalesce((select jsonb_agg(rs.subject_id) from public.run_subjects rs where rs.run_id=r.id and rs.is_active),'[]'::jsonb)) order by b.name)
   from public.teaching_batches b join public.programme_runs r on r.id=b.run_id where b.academy_id=aid and b.is_active and r.is_active),'[]'::jsonb) else '[]'::jsonb end);
end $$;


create or replace function public.academic_settings_register(p_section text,p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); rows_value jsonb; total_value bigint;
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 if p_section='ROOMS' then
  select count(*) into total_value from public.academic_rooms where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select * from public.academic_rooms where academy_id=aid order by name,id limit 25 offset(p_page-1)*25)x;
 elsif p_section='WINDOWS' then
  select count(*) into total_value from public.academic_resource_windows where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select w.*,coalesce(public.teacher_resource_name(p.id),r.name) resource_name
   from public.academic_resource_windows w left join public.people p on w.resource_kind='TEACHER' and p.id=w.resource_id
   left join public.academic_rooms r on w.resource_kind='ROOM' and r.id=w.resource_id
   where w.academy_id=aid order by w.weekday,w.starts,w.id limit 25 offset(p_page-1)*25)x;
 elsif p_section='CLOSURES' then
  select count(*) into total_value from public.academic_closures where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select * from public.academic_closures where academy_id=aid order by closed_on desc,id limit 25 offset(p_page-1)*25)x;
 elsif p_section='CONTACTS' then
  select count(*) into total_value from public.academic_notification_contacts where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select c.*,b.name batch_name from public.academic_notification_contacts c join public.teaching_batches b on b.id=c.batch_id where c.academy_id=aid order by c.name,c.id limit 25 offset(p_page-1)*25)x;
 elsif p_section='EMAILS' then
  select count(*) into total_value from public.academic_email_queue where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select id,session_id,recipient,status,attempts,last_error,created_at from public.academic_email_queue where academy_id=aid order by created_at desc,id limit 25 offset(p_page-1)*25)x;
 else raise exception 'Choose a settings section.'; end if;
 return jsonb_build_object('rows',coalesce(rows_value,'[]'::jsonb),'total',total_value,'page',p_page,'pageSize',25);
end $$;

create or replace function public.preview_academic_schedule(p_payload jsonb) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
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
 select public.teacher_resource_name(p.id) into teacher_name from public.people p where p.id=tid and p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility='TEACHER' and r.is_active);
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
