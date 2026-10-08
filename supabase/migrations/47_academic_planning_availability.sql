-- Extend the existing academic model, preserving dated records.
alter table public.programme_offerings add column operation_kind text not null default 'COACHING' check(operation_kind in('SCHOOL','COACHING','TRAINING')),add column teaching_starts_on date,add column teaching_ends_on date,add column teaching_days integer[] not null default '{}';
alter table public.programme_offerings add constraint offering_teaching_dates check(teaching_starts_on is null or teaching_ends_on>=teaching_starts_on),add constraint offering_teaching_days check(teaching_days <@ array[0,1,2,3,4,5,6]);
alter table public.batches add column teaching_windows jsonb not null default '[]' check(jsonb_typeof(teaching_windows)='array');
alter table public.academic_rooms add column is_active boolean not null default true;
drop trigger academic_immutable on public.academic_rooms;
create trigger room_no_delete before delete on public.academic_rooms for each row execute function public.prevent_permanent_record_delete();
create table public.academic_availability(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations,resource_kind text not null check(resource_kind in('ROOM','TEACHER')),resource_id uuid not null,weekday integer not null check(weekday between 0 and 6),start_time time not null,end_time time not null,starts_on date not null,ends_on date not null,is_active boolean not null default true,created_by uuid not null references public.profiles,check(end_time>start_time),check(ends_on>=starts_on));
create index academic_availability_lookup on public.academic_availability(resource_kind,resource_id,weekday,starts_on,ends_on) where is_active;
create table public.academic_closures(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations,branch_id uuid references public.branches,resource_kind text not null check(resource_kind in('ACADEMY','ROOM','TEACHER')),resource_id uuid,starts_on date not null,ends_on date not null,label text not null check(length(btrim(label)) between 2 and 200),is_active boolean not null default true,created_by uuid not null references public.profiles,check(ends_on>=starts_on),check((resource_kind='ACADEMY' and resource_id is null)or(resource_kind<>'ACADEMY' and resource_id is not null)));
alter table public.class_sessions add column replacement_for_id uuid references public.class_sessions,add column change_kind text check(change_kind in('RESCHEDULE','SUBSTITUTE','ROOM_CHANGE','MAKEUP'));
create unique index one_live_class_replacement on public.class_sessions(replacement_for_id) where replacement_for_id is not null and status='SCHEDULED';
alter table public.academic_availability enable row level security;alter table public.academic_closures enable row level security;
revoke all on public.academic_availability,public.academic_closures from public,anon,authenticated;
create trigger availability_no_delete before delete on public.academic_availability for each row execute function public.prevent_permanent_record_delete();
create trigger closure_no_delete before delete on public.academic_closures for each row execute function public.prevent_permanent_record_delete();

create function public.academic_closed(p_org uuid,p_branch uuid,p_day date,p_kind text default 'ACADEMY',p_resource uuid default null) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.academic_closures c where c.organization_id=p_org and c.is_active and p_day between c.starts_on and c.ends_on and(c.branch_id is null or c.branch_id=p_branch) and(c.resource_kind='ACADEMY' or(c.resource_kind=p_kind and c.resource_id=p_resource)))$$;
create function public.check_academic_slot(p_batch uuid,p_subject uuid,p_teacher uuid,p_room uuid,p_day date,p_start time,p_end time) returns void language plpgsql security definer set search_path='' as $$
declare b public.batches;o public.programme_offerings;r public.academic_rooms;org public.organizations;resource record;coverage tsmultirange;window jsonb;
begin
 select * into b from public.batches where id=p_batch and is_active;select * into o from public.programme_offerings where id=b.offering_id;select * into r from public.academic_rooms where id=p_room and is_active;select * into org from public.organizations where id=b.organization_id;
 if b.id is null or o.id is null or o.status<>'ACTIVE' or r.id is null or r.branch_id<>b.branch_id then raise exception 'Choose an active offering, batch and classroom in the same campus.';end if;
 if p_start is null or p_end is null or p_end<=p_start or p_day is null then raise exception 'Choose valid same-day class times.';end if;
 if p_day<coalesce(o.teaching_starts_on,(select starts_on from public.academic_years where id=o.academic_year_id)) or p_day>coalesce(o.teaching_ends_on,(select ends_on from public.academic_years where id=o.academic_year_id)) then raise exception 'Class date % is outside the programme operating period.',p_day;end if;
 if r.capacity<b.capacity then raise exception 'Classroom has % seats; this batch requires %.',r.capacity,b.capacity;end if;
 if not exists(select 1 from public.subjects where id=p_subject and organization_id=b.organization_id and is_active) or(exists(select 1 from public.programme_offering_subjects where offering_id=o.id) and not exists(select 1 from public.programme_offering_subjects where offering_id=o.id and subject_id=p_subject)) then raise exception 'Select a subject taught in this programme.';end if;
 if not exists(select 1 from public.staff s where s.id=p_teacher and s.status='ACTIVE' and(s.branch_id is null or s.branch_id=b.branch_id)) or not exists(select 1 from public.staff_subject_assignments where staff_id=p_teacher and subject_id=p_subject and effective_from<=p_day and(effective_to is null or effective_to>=p_day)) or not exists(select 1 from public.staff_role_assignments a join public.staff_roles role on role.id=a.staff_role_id where a.staff_id=p_teacher and role.is_teaching_role and a.effective_from<=p_day and(a.effective_to is null or a.effective_to>=p_day)) then raise exception 'Teacher qualification and teaching role must cover %.',p_day;end if;
 if nullif(current_setting('sohoj.change_kind',true),'') is not null then null;
 elsif jsonb_array_length(b.teaching_windows)>0 then
  if not exists(select 1 from jsonb_array_elements(b.teaching_windows) w where(w->>'weekday')::int=extract(dow from p_day) and(w->>'start_time')::time<=p_start and(w->>'end_time')::time>=p_end) then raise exception 'Class time is outside the batch day/time plan on %.',p_day;end if;
 elsif cardinality(o.teaching_days)>0 and not extract(dow from p_day)::int=any(o.teaching_days) then raise exception 'Choose one of the programme teaching days.';end if;
 for resource in select 'ROOM'::text kind,p_room id union all select 'TEACHER',p_teacher loop
  if public.academic_closed(b.organization_id,b.branch_id,p_day,resource.kind,resource.id) then raise exception '% is closed/unavailable on %. Choose another date/resource.',resource.kind,p_day;end if;
  select range_agg(tsrange(p_day+a.start_time,p_day+a.end_time,'[)')) into coverage from public.academic_availability a where a.organization_id=b.organization_id and a.resource_kind=resource.kind and a.resource_id=resource.id and a.is_active and a.weekday=extract(dow from p_day) and p_day between a.starts_on and a.ends_on;
  if coverage is null or not coverage @> tsrange(p_day+p_start,p_day+p_end,'[)') then raise exception '% weekly availability does not cover % %–%. Check weekday and effective dates.',resource.kind,p_day,p_start,p_end;end if;
 end loop;
end $$;
create function public.guard_academic_schedule() returns trigger language plpgsql security definer set search_path='' as $$declare d date;b public.batches;tz text;begin
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if tg_table_name='academic_routines' then
  if new.ends_on-new.starts_on>730 then raise exception 'Use a routine period of at most two years.';end if;
  for d in select x::date from generate_series(new.starts_on::timestamp,new.ends_on::timestamp,interval '1 day') x where extract(dow from x)=new.weekday loop
   select * into b from public.batches where id=new.batch_id;
   if public.academic_closed(b.organization_id,b.branch_id,d) then continue;end if;
   perform public.check_academic_slot(new.batch_id,new.subject_id,new.teacher_id,new.room_id,d,new.start_time,new.end_time);
  end loop;
 else
  select org.timezone into tz from public.batches ba join public.organizations org on org.id=ba.organization_id where ba.id=new.batch_id;
  if (new.starts_at at time zone tz)::date<>new.session_date or(new.ends_at at time zone tz)::date<>new.session_date then raise exception 'Session dates/times must use academy local time.';end if;
  perform public.check_academic_slot(new.batch_id,new.subject_id,new.teacher_id,new.room_id,new.session_date,(new.starts_at at time zone tz)::time,(new.ends_at at time zone tz)::time);
 end if;return new;
end $$;
create trigger routine_slot_guard before insert on public.academic_routines for each row execute function public.guard_academic_schedule();
create trigger session_slot_guard before insert on public.class_sessions for each row execute function public.guard_academic_schedule();

create function public.academic_planning_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;act text:=p_input->>'action';why text:=btrim(p_input->>'reason');org uuid;key public.admission_command_keys;rid uuid:=nullif(p_input->>'id','')::uuid;resource uuid;kind text;branch uuid;old_data jsonb;result jsonb;w jsonb;b public.batches;o public.programme_offerings;r public.academic_rooms;windows jsonb;
begin
 if actor is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Academic scheduling permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 500 then raise exception 'Request identity and short reason required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity reused with different input.';end if;return key.result;end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 if act='OFFERING_PLAN' then
  select * into o from public.programme_offerings where id=rid and organization_id=org for update;if not found then raise exception 'Programme offering not found.';end if;old_data:=to_jsonb(o);
  if p_input->>'operation_kind' not in('SCHOOL','COACHING','TRAINING') or (p_input->>'starts_on')::date is null or(p_input->>'ends_on')::date<(p_input->>'starts_on')::date or jsonb_typeof(p_input->'days')<>'array' then raise exception 'Select operation, dates and teaching days.';end if;
  update public.programme_offerings set operation_kind=p_input->>'operation_kind',teaching_starts_on=(p_input->>'starts_on')::date,teaching_ends_on=(p_input->>'ends_on')::date,teaching_days=array(select distinct value::int from jsonb_array_elements_text(p_input->'days')) where id=rid;
 elsif act='BATCH_PLAN' then
  select * into b from public.batches where id=rid and organization_id=org for update;if not found then raise exception 'Batch not found.';end if;old_data:=to_jsonb(b);windows:=p_input->'windows';
  if windows is null or jsonb_typeof(windows)<>'array' or jsonb_array_length(windows)>7 then raise exception 'Use at most one default time window per weekday.';end if;
  if(select count(distinct value->>'weekday') from jsonb_array_elements(windows))<>jsonb_array_length(windows) then raise exception 'Each weekday needs one batch window.';end if;
  for w in select value from jsonb_array_elements(windows) loop if (w->>'weekday')::int is null or(w->>'weekday')::int not between 0 and 6 or(w->>'start_time')::time is null or(w->>'end_time')::time<=(w->>'start_time')::time then raise exception 'Choose valid weekdays and start/end times.';end if;end loop;
  update public.batches set teaching_windows=windows where id=rid;
 elsif act='ROOM' then
  branch:=(p_input->>'branch_id')::uuid;if not exists(select 1 from public.branches where id=branch and organization_id=org and is_active) then raise exception 'Choose an active campus.';end if;
  if coalesce(length(btrim(p_input->>'name')),0) not between 2 and 120 or coalesce((p_input->>'capacity')::int,0) not between 1 and 10000 then raise exception 'Enter classroom name and actual seat capacity.';end if;
  if rid is null then insert into public.academic_rooms(branch_id,name,capacity,is_active,created_by) values(branch,btrim(p_input->>'name'),(p_input->>'capacity')::int,coalesce((p_input->>'is_active')::boolean,true),actor) returning id into rid;
  else select * into r from public.academic_rooms where id=rid and branch_id in(select id from public.branches where organization_id=org) for update;if not found then raise exception 'Classroom not found.';end if;old_data:=to_jsonb(r);if r.branch_id<>branch then raise exception 'Keep the classroom campus; create another room for another campus.';end if;
   update public.academic_rooms set name=btrim(p_input->>'name'),capacity=(p_input->>'capacity')::int,is_active=(p_input->>'is_active')::boolean where id=rid;
  end if;
 elsif act in('AVAILABILITY','CLOSURE') then
  kind:=p_input->>'resource_kind';resource:=nullif(p_input->>'resource_id','')::uuid;branch:=nullif(p_input->>'branch_id','')::uuid;
  if kind='ROOM' then if not exists(select 1 from public.academic_rooms rm join public.branches br on br.id=rm.branch_id where rm.id=resource and br.organization_id=org and rm.is_active) then raise exception 'Choose an active classroom.';end if;
  elsif kind='TEACHER' then if not exists(select 1 from public.staff where id=resource and status='ACTIVE' and(branch_id is null or branch_id in(select id from public.branches where organization_id=org))) then raise exception 'Choose an active teacher.';end if;
  elsif kind<>'ACADEMY' or act='AVAILABILITY' then raise exception 'Choose teacher/classroom availability or academy holiday.';end if;
  if branch is not null and not exists(select 1 from public.branches where id=branch and organization_id=org) then raise exception 'Campus not found.';end if;
  if rid is not null then
   if act='AVAILABILITY' then select to_jsonb(a) into old_data from public.academic_availability a where id=rid and organization_id=org;else select to_jsonb(c) into old_data from public.academic_closures c where id=rid and organization_id=org;end if;
   if old_data is null then raise exception 'Record not found.';end if;
  end if;
  if act='AVAILABILITY' then
   if rid is null then insert into public.academic_availability(organization_id,resource_kind,resource_id,weekday,start_time,end_time,starts_on,ends_on,created_by) values(org,kind,resource,(p_input->>'weekday')::int,(p_input->>'start_time')::time,(p_input->>'end_time')::time,(p_input->>'starts_on')::date,(p_input->>'ends_on')::date,actor) returning id into rid;
   else update public.academic_availability set resource_kind=kind,resource_id=resource,weekday=(p_input->>'weekday')::int,start_time=(p_input->>'start_time')::time,end_time=(p_input->>'end_time')::time,starts_on=(p_input->>'starts_on')::date,ends_on=(p_input->>'ends_on')::date,is_active=coalesce((p_input->>'is_active')::boolean,true) where id=rid;end if;
  else
   if rid is null then insert into public.academic_closures(organization_id,branch_id,resource_kind,resource_id,starts_on,ends_on,label,created_by) values(org,branch,kind,resource,(p_input->>'starts_on')::date,(p_input->>'ends_on')::date,btrim(p_input->>'name'),actor) returning id into rid;
   else update public.academic_closures set branch_id=branch,resource_kind=kind,resource_id=resource,starts_on=(p_input->>'starts_on')::date,ends_on=(p_input->>'ends_on')::date,label=btrim(p_input->>'name'),is_active=coalesce((p_input->>'is_active')::boolean,true) where id=rid;end if;
  end if;
 else raise exception 'Choose a supported planning action.';end if;
 -- Edits cannot strand already scheduled classes or active routine reservations.
 if act in('ROOM','AVAILABILITY','OFFERING_PLAN','BATCH_PLAN','CLOSURE') then
  for b in select distinct ba.* from public.batches ba join public.class_sessions s on s.batch_id=ba.id where ba.organization_id=org and s.status='SCHEDULED' and s.starts_at>now() and ((act='ROOM' and s.room_id=rid) or(act='OFFERING_PLAN' and ba.offering_id=rid) or(act='BATCH_PLAN' and ba.id=rid) or(act in('AVAILABILITY','CLOSURE') and((kind='ROOM' and s.room_id=resource)or(kind='TEACHER' and s.teacher_id=resource)or(kind='ACADEMY' and(branch is null or ba.branch_id=branch))))) loop
   for w in select to_jsonb(s) from public.class_sessions s where s.batch_id=b.id and s.status='SCHEDULED' and s.starts_at>now() loop
    perform public.check_academic_slot(b.id,(w->>'subject_id')::uuid,(w->>'teacher_id')::uuid,(w->>'room_id')::uuid,(w->>'session_date')::date,((w->>'starts_at')::timestamptz at time zone 'Asia/Dhaka')::time,((w->>'ends_at')::timestamptz at time zone 'Asia/Dhaka')::time);
   end loop;
  end loop;
 end if;
 result:=jsonb_build_object('id',rid,'message','Academic plan saved.');insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'ACADEMIC_PLAN',rid::text,act,why,old_data,p_input,req);insert into public.admission_command_keys values(req,actor,p_input,result,now());return result;
end $$;
revoke all on function public.academic_closed(uuid,uuid,date,text,uuid),public.check_academic_slot(uuid,uuid,uuid,uuid,date,time,time),public.guard_academic_schedule(),public.academic_planning_command(jsonb) from public,anon,authenticated;
grant execute on function public.academic_planning_command(jsonb) to authenticated;
notify pgrst,'reload schema';
create function public.academic_planning_workspace(p_section text,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total int;choices jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Academic planning permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_section not in('offerings','batches','rooms','availability','closures','routines') then raise exception 'Choose an academic planning section/page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where organization_id=org and is_active),'[]'),
 'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name||' · '||o.code,'days',o.teaching_days,'starts_on',coalesce(o.teaching_starts_on,y.starts_on),'ends_on',coalesce(o.teaching_ends_on,y.ends_on))) from public.programme_offerings o left join public.academic_years y on y.id=o.academic_year_id where o.organization_id=org and o.status in('DRAFT','ACTIVE')),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||o.name,'offering_id',o.id,'branch_id',b.branch_id,'capacity',b.capacity,'windows',b.teaching_windows,'days',o.teaching_days)) from public.batches b join public.programme_offerings o on o.id=b.offering_id where b.organization_id=org and b.is_active),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'offerings',coalesce((select jsonb_agg(offering_id) from public.programme_offering_subjects where subject_id=s.id),'[]'))) from public.subjects s where s.organization_id=org and s.is_active),'[]'),
 'teachers',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name||' · '||s.staff_no,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id and(effective_to is null or effective_to>=current_date)),'[]'))) from public.staff s where s.status='ACTIVE' and(s.branch_id is null or s.branch_id in(select id from public.branches where organization_id=org)) and exists(select 1 from public.staff_role_assignments a join public.staff_roles r on r.id=a.staff_role_id where a.staff_id=s.id and r.is_teaching_role and(a.effective_to is null or a.effective_to>=current_date))),'[]'),
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'branch_id',r.branch_id,'capacity',r.capacity)) from public.academic_rooms r join public.branches b on b.id=r.branch_id where b.organization_id=org and r.is_active),'[]')) into choices;
 with items as(
 select to_jsonb(o)||jsonb_build_object('label',o.name) item,o.id from public.programme_offerings o where p_section='offerings' and o.organization_id=org
 union all select to_jsonb(b)||jsonb_build_object('label',b.name||' · '||o.name),b.id from public.batches b join public.programme_offerings o on o.id=b.offering_id where p_section='batches' and b.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',r.name),r.id from public.academic_rooms r join public.branches b on b.id=r.branch_id where p_section='rooms' and b.organization_id=org
 union all select to_jsonb(a)||jsonb_build_object('label',coalesce(r.name,s.full_name)||' · '||a.resource_kind),a.id from public.academic_availability a left join public.academic_rooms r on r.id=a.resource_id and a.resource_kind='ROOM' left join public.staff s on s.id=a.resource_id and a.resource_kind='TEACHER' where p_section='availability' and a.organization_id=org
 union all select to_jsonb(c)||jsonb_build_object('label',c.label),c.id from public.academic_closures c where p_section='closures' and c.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',b.name||' · '||s.name,'teacher',t.full_name,'room',rm.name),r.id from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where p_section='routines' and b.organization_id=org),paged as(select * from items order by item->>'label',id limit 25 offset(p_page-1)*25)
 select (select count(*) from items),coalesce((select jsonb_agg(item order by item->>'label',id) from paged),'[]') into total,rows;
 return jsonb_build_object('section',p_section,'page',p_page,'total',total,'choices',choices,'rows',rows);
end $$;
revoke all on function public.academic_planning_workspace(text,integer) from public,anon;
grant execute on function public.academic_planning_workspace(text,integer) to authenticated;
