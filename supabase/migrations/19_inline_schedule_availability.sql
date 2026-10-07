-- Generated from supabase/schema/academics/19_inline_schedule_availability.sql; edit the source, then run pnpm db:baseline.
-- Explicit administrator confirmation can prepare availability in the same transaction.
alter function public.academic_command(uuid,jsonb) rename to academic_prepared_command;
revoke all on function public.academic_prepared_command(uuid,jsonb) from public,anon,authenticated;
create function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid; cmd text:=p_payload->>'action'; prior jsonb; d date; weekdays int[]; start_time time; end_time time; kind text; resource uuid; day_no int;
begin
 aid:=public.require_operation('academics.view');
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_'||cmd,p_payload);
 if prior is not null then return prior; end if;
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
