-- Replace only future planned classes, atomically; completed work stays untouched.
create or replace function public.manage_academic_routine(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); cmd text:=p_payload->>'action'; original public.academic_routines; prior jsonb; result jsonb; next_payload jsonb; planned public.academic_sessions; replaced int:=0;
begin
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 perform public.check_change_reason(p_payload->>'reason');
 prior:=public.lookup_operation(p_request_id,'ROUTINE_'||cmd,p_payload);if prior is not null then return prior; end if;
 select * into original from public.academic_routines where id=(p_payload->>'id')::uuid and academy_id=aid for update;
 if not found or original.revision is distinct from (p_payload->>'revision')::int then raise exception 'Routine changed. Refresh before continuing.'; end if;
 if cmd='STOP' then
  update public.academic_routines set is_active=false,revision=revision+1 where id=original.id;
  result:=jsonb_build_object('id',original.id,'message','Routine stopped. Existing sessions remain; cancel or reschedule them separately.');
 elsif cmd in('CONTINUE','REPLACE') then
  if not original.is_active then raise exception 'Only an active routine can generate or change its next period.'; end if;
  if cmd='CONTINUE' and (p_payload->>'startsOn')::date<=original.ends_on then raise exception 'The next period must start after the last generated period.'; end if;
  if cmd='REPLACE' then
   if not coalesce((p_payload->>'confirmReplacement')::boolean,false) or (p_payload->>'startsOn')::date<=(now() at time zone 'Asia/Dhaka')::date then raise exception 'Confirm replacement and choose a future effective date.'; end if;
   if exists(select 1 from public.academic_sessions where routine_id=original.id and(starts_at at time zone 'Asia/Dhaka')::date>=(p_payload->>'startsOn')::date and status in('SUBMITTED','APPROVED')) then raise exception 'Reviewed work cannot be replaced. Choose a later date.'; end if;
   for planned in select * from public.academic_sessions where routine_id=original.id and status in('SCHEDULED','RETURNED') and (starts_at at time zone 'Asia/Dhaka')::date>=(p_payload->>'startsOn')::date loop
    perform public.academic_command(gen_random_uuid(),jsonb_build_object('action','CANCEL','id',planned.id,'revision',planned.revision,'reason',p_payload->>'reason'));replaced:=replaced+1;
   end loop;
  end if;
  next_payload:=jsonb_build_object('action','ROUTINE','batchId',original.batch_id,'subjectId',original.subject_id,'teacherId',case when cmd='REPLACE' then (p_payload->>'teacherId')::uuid else original.teacher_id end,'roomId',case when cmd='REPLACE' then (p_payload->>'roomId')::uuid else original.room_id end,'startsOn',p_payload->>'startsOn','endsOn',p_payload->>'endsOn','weekdays',case when cmd='REPLACE' then p_payload->'weekdays' else to_jsonb(original.weekdays) end,'startTime',case when cmd='REPLACE' then p_payload->>'startTime' else original.starts::text end,'endTime',case when cmd='REPLACE' then p_payload->>'endTime' else original.ends::text end,'reason',p_payload->>'reason','confirmAvailability',coalesce((p_payload->>'confirmAvailability')::boolean,false));
  result:=public.academic_command(gen_random_uuid(),next_payload);
  update public.academic_routines set source_routine_id=original.id where id=(result->>'id')::uuid;
  update public.academic_routines set is_active=false,revision=revision+1 where id=original.id;
  result:=result||jsonb_build_object('replaced',replaced);
 else raise exception 'Choose continue, change future classes or stop.'; end if;
 return public.finish_operation(p_request_id,'ROUTINE_'||cmd,p_payload,result,'ACADEMIC_ROUTINE',original.id,to_jsonb(original));
end $$;

-- Legacy window calls receive the same future-class protection as the current UI.
alter function public.academic_command(uuid,jsonb) rename to academic_scheduling_command;
revoke all on function public.academic_scheduling_command(uuid,jsonb) from public,anon,authenticated;
create function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare prior jsonb; result jsonb; identity uuid; existing public.academic_resource_windows;
begin
 if p_payload->>'action'='WINDOW' then
  perform public.require_operation('academics.manage');
  prior:=public.lookup_operation(p_request_id,'ACADEMIC_WINDOW',p_payload);if prior is not null then return prior; end if;
  select * into existing from public.academic_resource_windows where academy_id=public.current_academy_id() and resource_kind=p_payload->>'kind' and resource_id=(p_payload->>'resourceId')::uuid and weekday=(p_payload->>'weekday')::int and starts=(p_payload->>'startTime')::time and ends=(p_payload->>'endTime')::time;
  result:=public.save_academic_windows(gen_random_uuid(),p_payload||jsonb_build_object('weekdays',jsonb_build_array((p_payload->>'weekday')::int))||case when existing.id is not null then jsonb_build_object('id',existing.id,'revision',existing.revision) else '{}'::jsonb end);
  identity:=coalesce(existing.id,(result->>'id')::uuid);
  return public.finish_operation(p_request_id,'ACADEMIC_WINDOW',p_payload,result,'ACADEMIC_AVAILABILITY',identity,to_jsonb(existing));
 end if;
 return public.academic_scheduling_command(p_request_id,p_payload);
end $$;
revoke all on function public.academic_command(uuid,jsonb) from public,anon;
grant execute on function public.academic_command(uuid,jsonb) to authenticated;

create or replace function public.save_academic_windows(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); identity uuid:=nullif(p_payload->>'id','')::uuid; original public.academic_resource_windows; days int[]; day_no int; prior jsonb; result jsonb; affected public.academic_sessions;
begin
 perform public.check_change_reason(p_payload->>'reason');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'WEEKLY_WINDOWS',p_payload);if prior is not null then return prior; end if;
 days:=array(select value::int from jsonb_array_elements_text(p_payload->'weekdays'));
 if cardinality(days) not between 1 and 7 or not days<@array[0,1,2,3,4,5,6] or cardinality(days)<>(select count(distinct value) from unnest(days) value) then raise exception 'Select one or more distinct weekdays.'; end if;
 if nullif(p_payload->>'startTime','') is null or nullif(p_payload->>'endTime','') is null or (p_payload->>'endTime')::time<=(p_payload->>'startTime')::time then raise exception 'Choose an end time after start.'; end if;
 if identity is not null then
  select * into original from public.academic_resource_windows where id=identity and academy_id=aid for update;
  if not found or original.revision is distinct from (p_payload->>'revision')::int then raise exception 'Availability changed. Refresh before editing.'; end if;
  if cardinality(days)<>1 or original.resource_kind is distinct from p_payload->>'kind' or original.resource_id is distinct from (p_payload->>'resourceId')::uuid then raise exception 'Editing retains the resource and one weekday.'; end if;
  if exists(select 1 from public.academic_resource_windows where academy_id=aid and id<>identity and resource_kind=original.resource_kind and resource_id=original.resource_id and weekday=days[1] and starts=(p_payload->>'startTime')::time and ends=(p_payload->>'endTime')::time) then raise exception 'This window already exists. Edit that record instead.'; end if;
  update public.academic_resource_windows set weekday=days[1],starts=(p_payload->>'startTime')::time,ends=(p_payload->>'endTime')::time,is_active=coalesce((p_payload->>'active')::boolean,true),revision=revision+1 where id=identity;
  result:=jsonb_build_object('id',identity);
 else
  if not coalesce((p_payload->>'active')::boolean,true) and exists(select 1 from public.academic_resource_windows w where w.academy_id=aid and w.resource_kind=p_payload->>'kind' and w.resource_id=(p_payload->>'resourceId')::uuid and w.weekday=any(days) and w.starts=(p_payload->>'startTime')::time and w.ends=(p_payload->>'endTime')::time and w.is_active) then raise exception 'Edit the existing window to deactivate it; existing class coverage must be checked.'; end if;
  foreach day_no in array days loop
   update public.academic_resource_windows set revision=revision+1 where academy_id=aid and resource_kind=p_payload->>'kind' and resource_id=(p_payload->>'resourceId')::uuid and weekday=day_no and starts=(p_payload->>'startTime')::time and ends=(p_payload->>'endTime')::time;
   result:=public.academic_prepared_command(gen_random_uuid(),p_payload||jsonb_build_object('action','WINDOW','weekday',day_no));
  end loop;
 end if;
 for affected in select * from public.academic_sessions where identity is not null and original.is_active and academy_id=aid and status<>'CANCELLED' and ends_at>now() and extract(dow from starts_at at time zone 'Asia/Dhaka')::int=original.weekday and (starts_at at time zone 'Asia/Dhaka')::time<original.ends and(ends_at at time zone 'Asia/Dhaka')::time>original.starts and ((p_payload->>'kind'='ROOM' and room_id=(p_payload->>'resourceId')::uuid) or(p_payload->>'kind'='TEACHER' and teacher_id=(p_payload->>'resourceId')::uuid)) loop
  if not public.resource_window_covers(aid,p_payload->>'kind',(p_payload->>'resourceId')::uuid,affected.starts_at::text,affected.ends_at::text) then raise exception 'This change removes availability for an existing class on %. Reschedule it first.',(affected.starts_at at time zone 'Asia/Dhaka')::date; end if;
 end loop;
 return public.finish_operation(p_request_id,'WEEKLY_WINDOWS',p_payload,result,'ACADEMIC_AVAILABILITY',coalesce(identity,(p_payload->>'resourceId')::uuid),to_jsonb(original));
end $$;

create or replace function public.academic_session_register(p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'sessions',coalesce((select jsonb_agg(to_jsonb(x)) from(
  select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name
  from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id
  join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id
  join public.directory_entries d on d.id=s.subject_id
  where s.academy_id=aid and(manager or s.teacher_id=own_id)
  order by case when (manager and s.status='SUBMITTED') or (not manager and s.status='RETURNED') then 0 when (s.starts_at at time zone 'Asia/Dhaka')::date=(now() at time zone 'Asia/Dhaka')::date then 1 when s.starts_at>now() and s.status='SCHEDULED' then 2 else 3 end,case when s.starts_at>now() then s.starts_at end,s.starts_at desc,s.id limit 25 offset(p_page-1)*25)x),'[]'::jsonb),
  'total',(select count(*) from public.academic_sessions where academy_id=aid and(manager or teacher_id=own_id)));
end $$;


create function public.academic_teacher_agenda() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; today date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('todayTotal',(select count(*) from public.academic_sessions where academy_id=aid and teacher_id=own_id and(starts_at at time zone 'Asia/Dhaka')::date=today),
 'returnedTotal',(select count(*) from public.academic_sessions where academy_id=aid and teacher_id=own_id and status='RETURNED'),
 'today',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,d.name subject_name,r.name room_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.directory_entries d on d.id=s.subject_id join public.academic_rooms r on r.id=s.room_id where s.academy_id=aid and s.teacher_id=own_id and(s.starts_at at time zone 'Asia/Dhaka')::date=today order by s.starts_at,s.id limit 25)x),'[]'),
 'returned',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,d.name subject_name,r.name room_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.directory_entries d on d.id=s.subject_id join public.academic_rooms r on r.id=s.room_id where s.academy_id=aid and s.teacher_id=own_id and s.status='RETURNED' order by s.starts_at,s.id limit 25)x),'[]'));
end $$;
revoke all on function public.academic_teacher_agenda() from public,anon;
grant execute on function public.academic_teacher_agenda() to authenticated;
