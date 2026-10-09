-- Routine metadata stays protected without requiring year-long availability.
create or replace function public.guard_academic_schedule() returns trigger language plpgsql security definer set search_path='' as $$declare tz text;b public.batches;o public.programme_offerings;room public.academic_rooms;begin
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if tg_table_name='academic_routines' then
  select * into b from public.batches where id=new.batch_id and is_active;
  select * into o from public.programme_offerings where id=b.offering_id and status='ACTIVE';
  select * into room from public.academic_rooms where id=new.room_id and is_active;
  if b.id is null or o.id is null or room.id is null or room.branch_id<>b.branch_id or room.capacity<b.capacity or not exists(select 1 from public.staff where id=new.teacher_id and status='ACTIVE' and(branch_id is null or branch_id=b.branch_id)) then raise exception 'Choose an active programme, batch, teacher and suitable classroom in the same campus.';end if;
  if not exists(select 1 from public.subjects where id=new.subject_id and organization_id=b.organization_id and is_active) or(exists(select 1 from public.programme_offering_subjects where offering_id=o.id) and not exists(select 1 from public.programme_offering_subjects where offering_id=o.id and subject_id=new.subject_id)) then raise exception 'Select a subject taught in this programme.';end if;
  if new.starts_on<coalesce(o.teaching_starts_on,(select starts_on from public.academic_years where id=o.academic_year_id)) or new.ends_on>coalesce(o.teaching_ends_on,(select ends_on from public.academic_years where id=o.academic_year_id)) then raise exception 'Routine dates must stay inside the programme operating period.';end if;
  if new.ends_on-new.starts_on>730 then raise exception 'Use a routine period of at most two years.';end if;
 else
  select org.timezone into tz from public.batches ba join public.organizations org on org.id=ba.organization_id where ba.id=new.batch_id;
  if (new.starts_at at time zone tz)::date<>new.session_date or(new.ends_at at time zone tz)::date<>new.session_date then raise exception 'Session dates/times must use academy local time.';end if;
  perform public.check_academic_slot(new.batch_id,new.subject_id,new.teacher_id,new.room_id,new.session_date,(new.starts_at at time zone tz)::time,(new.ends_at at time zone tz)::time);
 end if;return new;
end $$;

-- One controlled timetable transaction, reusing existing routine/session commands.
create function public.weekly_timetable_preview(p_input jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare b public.batches;o public.programme_offerings;start_day date:=nullif(p_input->>'starts_on','')::date;end_day date:=nullif(p_input->>'ends_on','')::date;through_day date;slot jsonb;other jsonb;i int;day date;st time;et time;teacher uuid;subject uuid;room uuid;tz text;start_at timestamptz;end_at timestamptz;clash record;message text;days jsonb:='[]';issues jsonb:='[]';class_status text;period_start date;period_end date;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not public.has_permission('academics.sessions.manage') then raise exception 'Academic planning permission required.';end if;
 select * into b from public.batches where id=nullif(p_input->>'batch_id','')::uuid and is_active;
 select * into o from public.programme_offerings where id=b.offering_id and status='ACTIVE';
 if b.id is null or o.id is null or b.organization_id is distinct from(select id from public.organizations where code='SOHOJ' and is_active) then raise exception 'Choose an active batch and programme.';end if;
 select coalesce(o.teaching_starts_on,y.starts_on),coalesce(o.teaching_ends_on,y.ends_on) into period_start,period_end from(select 1)dummy left join public.academic_years y on y.id=o.academic_year_id;
 if start_day is null or end_day is null or start_day<(now() at time zone 'Asia/Dhaka')::date or end_day<start_day or end_day-start_day>730 or start_day<period_start or end_day>period_end then raise exception 'Start today or later, within the programme dates. Check the end date.';end if;
 if jsonb_typeof(p_input->'slots') is distinct from 'array' or coalesce(jsonb_array_length(p_input->'slots'),0) not between 1 and 40 then raise exception 'Add 1–40 weekly class rows.';end if;
 select timezone into tz from public.organizations where id=b.organization_id;
 through_day:=least(end_day,start_day+27);
 for slot,i in select value,ordinality::int from jsonb_array_elements(p_input->'slots') with ordinality loop
  st:=nullif(slot->>'start_time','')::time;et:=nullif(slot->>'end_time','')::time;teacher:=nullif(slot->>'teacher_id','')::uuid;subject:=nullif(slot->>'subject_id','')::uuid;room:=nullif(slot->>'room_id','')::uuid;
  if st is null or et is null or et<=st or nullif(slot->>'weekday','')::int not between 0 and 6 or nullif(slot->>'weekday','') is null then raise exception 'Row %: choose a day and valid start/end times.',i;end if;
  if not exists(select 1 from public.staff where id=teacher and status='ACTIVE' and(branch_id is null or branch_id=b.branch_id)) or not exists(select 1 from public.academic_rooms where id=room and is_active and branch_id=b.branch_id and capacity>=b.capacity) or not exists(select 1 from public.subjects where id=subject and organization_id=b.organization_id and is_active) or(exists(select 1 from public.programme_offering_subjects where offering_id=o.id) and not exists(select 1 from public.programme_offering_subjects where offering_id=o.id and subject_id=subject)) then raise exception 'Row %: check active teacher, programme subject and classroom campus/capacity.',i;end if;
  for other in select value from jsonb_array_elements(p_input->'slots') with ordinality where ordinality<i loop
   if(other->>'weekday')::int=(slot->>'weekday')::int and(other->>'start_time')::time<et and(other->>'end_time')::time>st then issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','Two rows overlap for this batch. Change their day or time.'));end if;
  end loop;
  for clash in select r.id,ba.name batch_name,t.full_name teacher_name,rm.name room_name from public.academic_routines r join public.batches ba on ba.id=r.batch_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where r.retired_at is null and r.weekday=(slot->>'weekday')::int and r.starts_on<=end_day and r.ends_on>=start_day and r.start_time<et and r.end_time>st and(r.batch_id=b.id or r.teacher_id=teacher or r.room_id=room) loop
   issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','Existing weekly routine: '||clash.batch_name||' · '||clash.teacher_name||' · '||clash.room_name));
  end loop;
  if exists(select 1 from public.class_sessions s where s.status='SCHEDULED' and s.session_date between start_day and end_day and extract(dow from s.session_date)=(slot->>'weekday')::int and(s.starts_at at time zone tz)::time<et and(s.ends_at at time zone tz)::time>st and(s.batch_id=b.id or s.teacher_id=teacher or s.room_id=room)) then issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message','A dated class already occupies this teacher, room or batch. Check the class calendar.'));end if;
  for day in select d::date from generate_series(start_day::timestamp,through_day::timestamp,interval '1 day')d where extract(dow from d)=(slot->>'weekday')::int loop
   class_status:='READY';message:='';start_at:=(day+st) at time zone tz;end_at:=(day+et) at time zone tz;
   if start_at<now() then class_status:='SKIPPED';message:='Time has already passed';
   elsif public.academic_closed(b.organization_id,b.branch_id,day,'ROOM',room) or public.academic_closed(b.organization_id,b.branch_id,day,'TEACHER',teacher) then class_status:='SKIPPED';message:='Holiday or recorded room/teacher unavailability';
   else begin perform public.check_academic_slot(b.id,subject,teacher,room,day,st,et);exception when others then get stacked diagnostics message=MESSAGE_TEXT;class_status:='CONFLICT';issues:=issues||jsonb_build_array(jsonb_build_object('row',i,'message',day::text||': '||message));end;end if;
   days:=days||jsonb_build_array(jsonb_build_object('row',i,'date',day,'start_time',st,'end_time',et,'status',class_status,'message',message));
  end loop;
 end loop;
 return jsonb_build_object('from',start_day,'through',through_day,'classes',days,'issues',issues,'ready',jsonb_array_length(issues)=0,'count',(select count(*) from jsonb_array_elements(days)x where x->>'status'='READY'));
end $$;

create function public.weekly_timetable_save(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;key public.admission_command_keys;preview jsonb;slot jsonb;i int;result jsonb;ids jsonb:='[]';scope text;subject_name text;rid uuid;why text:=btrim(coalesce(p_input->>'reason',''));
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.sessions.manage') then raise exception 'Academic planning permission required.';end if;
 if req is null or length(why) not between 5 and 500 then raise exception 'A request identity and reason are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.';end if;return key.result;end if;
 preview:=public.weekly_timetable_preview(p_input);
 if not(preview->>'ready')::boolean then raise exception 'Timetable conflicts remain. Preview again and correct the highlighted rows.';end if;
 for slot,i in select value,ordinality::int from jsonb_array_elements(p_input->'slots') with ordinality loop
  result:=public.academic_command(slot||jsonb_build_object('action','CREATE_ROUTINE','batch_id',p_input->>'batch_id','starts_on',p_input->>'starts_on','ends_on',p_input->>'ends_on','request_id',md5(req::text||':routine:'||i)::uuid,'reason',why));rid:=(result->>'id')::uuid;ids:=ids||jsonb_build_array(rid);
  select name into subject_name from public.subjects where id=(slot->>'subject_id')::uuid;scope:=coalesce(nullif(btrim(slot->>'planned_scope'),''),'Scheduled teaching · '||subject_name);
  perform public.academic_command(jsonb_build_object('action','GENERATE_SESSIONS','routine_id',rid,'starts_on',preview->>'from','ends_on',preview->>'through','skip_past',true,'planned_scope',scope,'request_id',md5(req::text||':classes:'||i)::uuid,'reason',why));
 end loop;
 result:=jsonb_build_object('id',ids->>0,'ids',ids,'class_count',preview->'count','from',preview->'from','through',preview->'through','message','Weekly routine and first four weeks of classes saved.');
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data,correlation_id) values(actor,'WEEKLY_TIMETABLE',result->>'id','SAVE_AND_GENERATE',why,result,req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.weekly_timetable_preview(jsonb),public.weekly_timetable_save(jsonb) from public,anon;
grant execute on function public.weekly_timetable_preview(jsonb),public.weekly_timetable_save(jsonb) to authenticated;
notify pgrst,'reload schema';
