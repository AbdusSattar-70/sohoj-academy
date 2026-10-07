-- Generated from supabase/schema/academics/23_default_plans_and_availability.sql; edit the source, then run pnpm db:baseline.
alter table public.programme_runs add column default_weekdays integer[] not null default '{}' check(default_weekdays<@array[0,1,2,3,4,5,6] and cardinality(default_weekdays)<=7);
alter table public.teaching_batches add column planned_slots jsonb not null default '[]' check(jsonb_typeof(planned_slots)='array' and jsonb_array_length(planned_slots)<=7);
alter table public.academic_resource_windows add column revision integer not null default 1;
create function public.save_academic_plan(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); target text:=p_payload->>'target'; identity uuid:=(p_payload->>'id')::uuid; prior jsonb; before_value jsonb; result jsonb; slot jsonb; days int[]; duplicate_days int[]:='{}';
begin
 perform public.check_change_reason(p_payload->>'reason');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_PLAN_'||target,p_payload);if prior is not null then return prior; end if;
 if target='RUN' then
  select to_jsonb(r) into before_value from public.programme_runs r where id=identity and academy_id=aid for update;
  if before_value is null or (before_value->>'revision')::int is distinct from (p_payload->>'revision')::int then raise exception 'Offering changed. Refresh before saving.'; end if;
  days:=array(select value::int from jsonb_array_elements_text(p_payload->'weekdays'));
  if cardinality(days)>7 or not days<@array[0,1,2,3,4,5,6] or cardinality(days)<>(select count(distinct value) from unnest(days) value) then raise exception 'Choose distinct valid weekdays.'; end if;
  update public.programme_runs r set default_weekdays=days,revision=revision+1 where id=identity returning to_jsonb(r) into result;
 elsif target='BATCH' then
  select to_jsonb(b) into before_value from public.teaching_batches b where id=identity and academy_id=aid for update;
  if before_value is null or (before_value->>'revision')::int is distinct from (p_payload->>'revision')::int then raise exception 'Batch changed. Refresh before saving.'; end if;
  if jsonb_typeof(p_payload->'slots') is distinct from 'array' or jsonb_array_length(p_payload->'slots')>7 then raise exception 'Choose up to seven day/time slots.'; end if;
  for slot in select value from jsonb_array_elements(p_payload->'slots') loop
   if slot->>'weekday' is null or (slot->>'weekday')::int not between 0 and 6 or (slot->>'weekday')::int=any(duplicate_days) or nullif(slot->>'start','') is null or nullif(slot->>'end','') is null or (slot->>'end')::time<=(slot->>'start')::time or (slot->>'end')::time-(slot->>'start')::time>interval '12 hours' then raise exception 'Each selected weekday needs one valid start/end time within 12 hours.'; end if;
   duplicate_days:=array_append(duplicate_days,(slot->>'weekday')::int);
  end loop;
  update public.teaching_batches b set planned_slots=p_payload->'slots',revision=revision+1 where id=identity returning to_jsonb(b) into result;
 else raise exception 'Choose offering or batch planning.'; end if;
 return public.finish_operation(p_request_id,'ACADEMIC_PLAN_'||target,p_payload,result,'ACADEMIC_PLAN',identity,before_value);
end $$;

create function public.save_academic_windows(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
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
  foreach day_no in array days loop
   result:=public.academic_command(gen_random_uuid(),p_payload||jsonb_build_object('action','WINDOW','weekday',day_no));
  end loop;
 end if;
 for affected in select * from public.academic_sessions where identity is not null and original.is_active and academy_id=aid and status<>'CANCELLED' and ends_at>now() and extract(dow from starts_at at time zone 'Asia/Dhaka')::int=original.weekday and (starts_at at time zone 'Asia/Dhaka')::time<original.ends and(ends_at at time zone 'Asia/Dhaka')::time>original.starts and ((p_payload->>'kind'='ROOM' and room_id=(p_payload->>'resourceId')::uuid) or(p_payload->>'kind'='TEACHER' and teacher_id=(p_payload->>'resourceId')::uuid)) loop
  if not public.resource_window_covers(aid,p_payload->>'kind',(p_payload->>'resourceId')::uuid,affected.starts_at::text,affected.ends_at::text) then raise exception 'This change removes availability for an existing class on %. Reschedule it first.',(affected.starts_at at time zone 'Asia/Dhaka')::date; end if;
 end loop;
 return public.finish_operation(p_request_id,'WEEKLY_WINDOWS',p_payload,result,'ACADEMIC_AVAILABILITY',coalesce(identity,(p_payload->>'resourceId')::uuid),to_jsonb(original));
end $$;
revoke all on function public.save_academic_plan(uuid,jsonb),public.save_academic_windows(uuid,jsonb) from public,anon;
grant execute on function public.save_academic_plan(uuid,jsonb),public.save_academic_windows(uuid,jsonb) to authenticated;

create or replace function public.academic_operation_choices(p_section text default 'SESSION') returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage');
begin
 if p_section not in('SESSION','QUALIFICATIONS','AVAILABILITY','CONTACTS') then raise exception 'Choose an academic work area.'; end if;
 return jsonb_build_object(
 'rooms',case when p_section in('SESSION','AVAILABILITY','QUALIFICATIONS') then coalesce((select jsonb_agg(to_jsonb(r) order by name) from public.academic_rooms r where academy_id=aid and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'teachers',case when p_section in('SESSION','QUALIFICATIONS','AVAILABILITY') then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name) order by p.full_name)
   from public.people p where p.academy_id=aid and p.is_active and exists(select 1 from public.person_responsibilities x where x.person_id=p.id and x.responsibility='TEACHER' and x.is_active)),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',case when p_section in('SESSION','QUALIFICATIONS') then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name) order by sort_order,name) from public.directory_entries d where academy_id=aid and kind='SUBJECT' and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'qualifications',case when p_section='SESSION' then coalesce((select jsonb_agg(jsonb_build_object('teacherId',q.teacher_id,'subjectId',q.subject_id)) from public.teacher_subject_qualifications q where q.academy_id=aid and q.is_active),'[]'::jsonb) else '[]'::jsonb end,
 'batches',case when p_section in('SESSION','CONTACTS') then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||r.title,'startsOn',r.starts_on,'endsOn',r.ends_on,'defaultDays',r.default_weekdays,'slots',b.planned_slots,'subjectIds',coalesce((select jsonb_agg(rs.subject_id) from public.run_subjects rs where rs.run_id=r.id and rs.is_active),'[]'::jsonb)) order by b.name)
   from public.teaching_batches b join public.programme_runs r on r.id=b.run_id where b.academy_id=aid and b.is_active and r.is_active),'[]'::jsonb) else '[]'::jsonb end);
end $$;

