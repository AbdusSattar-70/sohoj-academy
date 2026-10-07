-- Generated from supabase/schema/academics/21_routine_calendar.sql; edit the source, then run pnpm db:baseline.
alter table public.academic_routines add column revision integer not null default 1;
alter table public.academic_routines add column source_routine_id uuid references public.academic_routines;
alter table public.academic_sessions add unique(id,academy_id);

create function public.academic_calendar(p_from text,p_through text,p_page integer default 1,p_status text default '') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage'); start_day date:=p_from::date; end_day date:=p_through::date;
begin
 if start_day is null or end_day is null or end_day-start_day not between 0 and 31 or p_page is null or p_page not between 1 and 10000 or p_status not in('','SCHEDULED','SUBMITTED','RETURNED','APPROVED','CANCELLED') then raise exception 'Choose a date range of 1 to 32 days, a valid status and page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'page',p_page,'pageSize',25,'from',start_day,'through',end_day,
 'total',(select count(*) from public.academic_sessions s where s.academy_id=aid and(manager or s.teacher_id=own_id) and (s.starts_at at time zone 'Asia/Dhaka')::date between start_day and end_day and(p_status='' or s.status=p_status)),
 'sessions',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.academy_id=aid and(manager or s.teacher_id=own_id) and(s.starts_at at time zone 'Asia/Dhaka')::date between start_day and end_day and(p_status='' or s.status=p_status) order by s.starts_at,s.id limit 25 offset(p_page-1)*25)x),'[]'),
 'closures',coalesce((select jsonb_agg(jsonb_build_object('date',closed_on,'name',name) order by closed_on) from public.academic_closures where academy_id=aid and is_active and closed_on between start_day and end_day),'[]'));
end $$;
create function public.academic_session_detail(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage'); item jsonb;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 select to_jsonb(x) into item from(select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.id=p_id and s.academy_id=aid and(manager or s.teacher_id=own_id))x;
 if item is null then raise exception 'Class not found or not assigned to you.'; end if;
 return jsonb_build_object('manage',manager,'sessions',jsonb_build_array(item),'total',1);
end $$;
create function public.academic_routine_register(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'page',p_page,'pageSize',25,'total',(select count(*) from public.academic_routines where academy_id=aid and(manager or teacher_id=own_id)),
 'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select rt.*,b.name batch_name,d.name subject_name,p.full_name teacher_name,r.name room_name,(select count(*) from public.academic_sessions s where s.routine_id=rt.id) session_count from public.academic_routines rt join public.teaching_batches b on b.id=rt.batch_id join public.directory_entries d on d.id=rt.subject_id join public.people p on p.id=rt.teacher_id join public.academic_rooms r on r.id=rt.room_id where rt.academy_id=aid and(manager or rt.teacher_id=own_id) order by rt.is_active desc,rt.ends_on desc,rt.id limit 25 offset(p_page-1)*25)x),'[]'));
end $$;
create function public.manage_academic_routine(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); cmd text:=p_payload->>'action'; original public.academic_routines; prior jsonb; result jsonb; next_payload jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 perform public.check_change_reason(p_payload->>'reason');
 prior:=public.lookup_operation(p_request_id,'ROUTINE_'||cmd,p_payload);if prior is not null then return prior; end if;
 select * into original from public.academic_routines where id=(p_payload->>'id')::uuid and academy_id=aid for update;
 if not found or original.revision is distinct from (p_payload->>'revision')::int then raise exception 'Routine changed. Refresh before continuing.'; end if;
 if cmd='STOP' then
  update public.academic_routines set is_active=false,revision=revision+1 where id=original.id;
  result:=jsonb_build_object('id',original.id,'message','Routine stopped. Existing sessions remain; cancel or reschedule them separately.');
 elsif cmd='CONTINUE' then
  if not original.is_active then raise exception 'Only an active routine can generate its next period.'; end if;
  if (p_payload->>'startsOn')::date<=original.ends_on then raise exception 'The next period must start after the last generated period.'; end if;
  next_payload:=jsonb_build_object('action','ROUTINE','batchId',original.batch_id,'subjectId',original.subject_id,'teacherId',original.teacher_id,'roomId',original.room_id,'startsOn',p_payload->>'startsOn','endsOn',p_payload->>'endsOn','weekdays',to_jsonb(original.weekdays),'startTime',original.starts,'endTime',original.ends,'reason',p_payload->>'reason','confirmAvailability',coalesce((p_payload->>'confirmAvailability')::boolean,false));
  result:=public.academic_command(gen_random_uuid(),next_payload);
  update public.academic_routines set source_routine_id=original.id where id=(result->>'id')::uuid;
  update public.academic_routines set is_active=false,revision=revision+1 where id=original.id;
 else raise exception 'Choose continue or stop.'; end if;
 return public.finish_operation(p_request_id,'ROUTINE_'||cmd,p_payload,result,'ACADEMIC_ROUTINE',original.id,to_jsonb(original));
end $$;
revoke all on function public.academic_calendar(text,text,integer,text),public.academic_session_detail(uuid),public.academic_routine_register(integer),public.manage_academic_routine(uuid,jsonb) from public,anon;
grant execute on function public.academic_calendar(text,text,integer,text),public.academic_session_detail(uuid),public.academic_routine_register(integer),public.manage_academic_routine(uuid,jsonb) to authenticated;
