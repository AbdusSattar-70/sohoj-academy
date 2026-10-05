-- Generated from supabase/schema/academics/13_weekly_availability_and_routines.sql; edit the source, then run pnpm db:baseline.
-- Resource availability and bounded recurring class generation.
create table public.academic_resource_windows (
 id uuid primary key default gen_random_uuid(),academy_id uuid not null references public.academies,
 resource_kind text not null check(resource_kind in('TEACHER','ROOM')),resource_id uuid not null,
 weekday int not null check(weekday between 0 and 6),starts time not null,ends time not null,
 is_active boolean not null default true,check(ends>starts),unique(academy_id,resource_kind,resource_id,weekday,starts,ends)
);
create table public.academic_closures (
 id uuid primary key default gen_random_uuid(),academy_id uuid not null references public.academies,
 closed_on date not null,name text not null,is_active boolean not null default true,unique(academy_id,closed_on)
);
create table public.academic_routines (
 id uuid primary key default gen_random_uuid(),academy_id uuid not null references public.academies,
 batch_id uuid not null,subject_id uuid not null,teacher_id uuid not null,room_id uuid not null,
 starts_on date not null,ends_on date not null,weekdays int[] not null,starts time not null,ends time not null,
 is_active boolean not null default true,check(ends>starts),check(ends_on>=starts_on and ends_on-starts_on<=31),
 check(cardinality(weekdays)>0 and weekdays<@array[0,1,2,3,4,5,6]),
 foreign key(batch_id,academy_id) references public.teaching_batches(id,academy_id),
 foreign key(subject_id,academy_id) references public.directory_entries(id,academy_id),
 foreign key(teacher_id,academy_id) references public.people(id,academy_id),
 foreign key(room_id,academy_id) references public.academic_rooms(id,academy_id)
);
alter table public.academic_sessions add column routine_id uuid references public.academic_routines;
create unique index academic_routine_session_day on public.academic_sessions(routine_id,starts_at) where routine_id is not null;
alter function public.academic_command(uuid,jsonb) rename to academic_session_command;
revoke all on function public.academic_session_command(uuid,jsonb) from authenticated;
create function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
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
    if not exists(select 1 from public.academic_resource_windows w where w.academy_id=aid and w.resource_kind=kind and w.resource_id=resource and w.is_active and w.weekday=extract(dow from start_value at time zone 'Asia/Dhaka') and w.starts<=(start_value at time zone 'Asia/Dhaka')::time and w.ends>=(end_value at time zone 'Asia/Dhaka')::time and (start_value at time zone 'Asia/Dhaka')::date=(end_value at time zone 'Asia/Dhaka')::date) then raise exception '% availability does not cover this session. Configure the weekly window first.',kind; end if;
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
create function public.academic_resource_setup() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid;
begin
 aid:=public.require_operation('academics.manage');
 return jsonb_build_object('windows',coalesce((select jsonb_agg(to_jsonb(w)) from public.academic_resource_windows w where academy_id=aid),'[]'::jsonb),'closures',coalesce((select jsonb_agg(to_jsonb(c)) from public.academic_closures c where academy_id=aid),'[]'::jsonb),'contacts',coalesce((select jsonb_agg(to_jsonb(c)) from public.academic_notification_contacts c where academy_id=aid),'[]'::jsonb));
end $$;
alter table public.academic_resource_windows enable row level security;
alter table public.academic_closures enable row level security;
alter table public.academic_routines enable row level security;
revoke all on public.academic_resource_windows,public.academic_closures,public.academic_routines from anon,authenticated;
create trigger no_delete before delete on public.academic_resource_windows for each row execute function public.reject_record_delete();
create trigger no_delete before delete on public.academic_closures for each row execute function public.reject_record_delete();
create trigger no_delete before delete on public.academic_routines for each row execute function public.reject_record_delete();
revoke all on function public.academic_command(uuid,jsonb),public.academic_resource_setup() from public,anon;
grant execute on function public.academic_command(uuid,jsonb),public.academic_resource_setup() to authenticated;
