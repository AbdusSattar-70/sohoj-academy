-- Configure existing staff teaching subjects without creating another person.
create or replace function public.academic_planning_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;act text:=p_input->>'action';why text:=btrim(p_input->>'reason');org uuid;key public.admission_command_keys;rid uuid:=nullif(p_input->>'id','')::uuid;resource uuid;kind text;branch uuid;old_data jsonb;result jsonb;w jsonb;b public.batches;o public.programme_offerings;r public.academic_rooms;windows jsonb;
begin
 if actor is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Academic scheduling permission required.';end if;
 if req is null or coalesce(length(why),0) not between 5 and 500 then raise exception 'Request identity and short reason required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity reused with different input.';end if;return key.result;end if;
 if act='OFFERING_PLAN' then
  select * into o from public.programme_offerings where id=rid and organization_id=org for update;if not found then raise exception 'Programme offering not found.';end if;old_data:=to_jsonb(o);
  if p_input->>'operation_kind' not in('SCHOOL','COACHING','TRAINING') or (p_input->>'starts_on')::date is null or(p_input->>'ends_on')::date<(p_input->>'starts_on')::date or jsonb_typeof(p_input->'days')<>'array' then raise exception 'Select operation, dates and teaching days.';end if;
  update public.programme_offerings set operation_kind=p_input->>'operation_kind',teaching_starts_on=(p_input->>'starts_on')::date,teaching_ends_on=(p_input->>'ends_on')::date,teaching_days=array(select distinct value::int from jsonb_array_elements_text(p_input->'days')) where id=rid;
 elsif act='QUALIFICATION' then
  if not public.has_permission('staff.manage') then raise exception 'Staff management permission required to assign teaching subjects.';end if;
  resource:=nullif(p_input->>'teacher_id','')::uuid;kind:='TEACHER';
  if not exists(select 1 from public.staff s where s.id=resource and s.status='ACTIVE' and(s.branch_id is null or s.branch_id in(select id from public.branches where organization_id=org))) or not exists(select 1 from public.subjects su where su.id=nullif(p_input->>'subject_id','')::uuid and su.organization_id=org and su.is_active) then raise exception 'Choose an active teacher and subject.';end if;
  if nullif(p_input->>'starts_on','')::date is null or(nullif(p_input->>'ends_on','')::date is not null and nullif(p_input->>'ends_on','')::date<nullif(p_input->>'starts_on','')::date) then raise exception 'Set valid qualification dates.';end if;
  if rid is null then
   if exists(select 1 from public.staff_subject_assignments ss where ss.staff_id=resource and ss.subject_id=(p_input->>'subject_id')::uuid and daterange(ss.effective_from,ss.effective_to,'[]')&&daterange((p_input->>'starts_on')::date,nullif(p_input->>'ends_on','')::date,'[]')) then raise exception 'An overlapping teaching subject assignment already exists. Edit it instead.';end if;
   insert into public.staff_subject_assignments(staff_id,subject_id,effective_from,effective_to,assigned_by) values(resource,(p_input->>'subject_id')::uuid,(p_input->>'starts_on')::date,nullif(p_input->>'ends_on','')::date,actor) returning id into rid;
  else
   select to_jsonb(ss) into old_data from public.staff_subject_assignments ss where ss.id=rid and ss.staff_id=resource and ss.subject_id=(p_input->>'subject_id')::uuid for update;
   if old_data is null then raise exception 'Keep the teacher and subject identity when correcting dates. Create another assignment for another subject.';end if;
   if exists(select 1 from public.staff_subject_assignments ss where ss.id<>rid and ss.staff_id=resource and ss.subject_id=(p_input->>'subject_id')::uuid and daterange(ss.effective_from,ss.effective_to,'[]')&&daterange((p_input->>'starts_on')::date,nullif(p_input->>'ends_on','')::date,'[]')) then raise exception 'Another assignment overlaps these dates.';end if;
   update public.staff_subject_assignments set effective_from=(p_input->>'starts_on')::date,effective_to=nullif(p_input->>'ends_on','')::date where id=rid;
  end if;
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
 if act in('ROOM','AVAILABILITY','OFFERING_PLAN','BATCH_PLAN','CLOSURE','QUALIFICATION') then
  for b in select distinct ba.* from public.batches ba join public.class_sessions s on s.batch_id=ba.id where ba.organization_id=org and s.status='SCHEDULED' and s.starts_at>now() and ((act='ROOM' and s.room_id=rid) or(act='OFFERING_PLAN' and ba.offering_id=rid) or(act='BATCH_PLAN' and ba.id=rid) or(act in('AVAILABILITY','CLOSURE','QUALIFICATION') and((kind='ROOM' and s.room_id=resource)or(kind='TEACHER' and s.teacher_id=resource)or(kind='ACADEMY' and(branch is null or ba.branch_id=branch))))) loop
   for w in select to_jsonb(s) from public.class_sessions s where s.batch_id=b.id and s.status='SCHEDULED' and s.starts_at>now() loop
    perform public.check_academic_slot(b.id,(w->>'subject_id')::uuid,(w->>'teacher_id')::uuid,(w->>'room_id')::uuid,(w->>'session_date')::date,((w->>'starts_at')::timestamptz at time zone 'Asia/Dhaka')::time,((w->>'ends_at')::timestamptz at time zone 'Asia/Dhaka')::time);
   end loop;
  end loop;
 end if;
 result:=jsonb_build_object('id',rid,'message','Academic plan saved.');insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'ACADEMIC_PLAN',rid::text,act,why,old_data,p_input,req);insert into public.admission_command_keys values(req,actor,p_input,result,now());return result;
end $$;
create or replace function public.academic_planning_workspace(p_section text,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total int;choices jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Academic planning permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_section not in('offerings','batches','rooms','availability','closures','routines','qualifications') then raise exception 'Choose an academic planning section/page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where organization_id=org and is_active),'[]'),
 'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name||' · '||o.code,'days',o.teaching_days,'operation_kind',o.operation_kind,'starts_on',coalesce(o.teaching_starts_on,y.starts_on),'ends_on',coalesce(o.teaching_ends_on,y.ends_on))) from public.programme_offerings o left join public.academic_years y on y.id=o.academic_year_id where o.organization_id=org and o.status in('DRAFT','ACTIVE')),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||o.name,'offering_id',o.id,'branch_id',b.branch_id,'capacity',b.capacity,'windows',b.teaching_windows,'days',o.teaching_days)) from public.batches b join public.programme_offerings o on o.id=b.offering_id where b.organization_id=org and b.is_active),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'offerings',coalesce((select jsonb_agg(offering_id) from public.programme_offering_subjects where subject_id=s.id),'[]'))) from public.subjects s where s.organization_id=org and s.is_active),'[]'),
 'teachers',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name||' · '||s.staff_no,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id and(effective_to is null or effective_to>=current_date)),'[]'))) from public.staff s where s.status='ACTIVE' and(s.branch_id is null or s.branch_id in(select id from public.branches where organization_id=org)) and exists(select 1 from public.staff_role_assignments a join public.staff_roles r on r.id=a.staff_role_id where a.staff_id=s.id and r.is_teaching_role and(a.effective_to is null or a.effective_to>=current_date))),'[]'),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'name',v.title||' · v'||v.version,'batch_id',v.batch_id,'subject_id',v.subject_id)) from public.curriculum_versions v join public.batches b on b.id=v.batch_id where b.organization_id=org),'[]'),
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'branch_id',r.branch_id,'capacity',r.capacity)) from public.academic_rooms r join public.branches b on b.id=r.branch_id where b.organization_id=org and r.is_active),'[]')) into choices;
 with items as(
 select to_jsonb(o)||jsonb_build_object('label',o.name) item,o.id from public.programme_offerings o where p_section='offerings' and o.organization_id=org
 union all select to_jsonb(b)||jsonb_build_object('label',b.name||' · '||o.name),b.id from public.batches b join public.programme_offerings o on o.id=b.offering_id where p_section='batches' and b.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',r.name),r.id from public.academic_rooms r join public.branches b on b.id=r.branch_id where p_section='rooms' and b.organization_id=org
 union all select to_jsonb(a)||jsonb_build_object('label',coalesce(r.name,s.full_name)||' · '||a.resource_kind),a.id from public.academic_availability a left join public.academic_rooms r on r.id=a.resource_id and a.resource_kind='ROOM' left join public.staff s on s.id=a.resource_id and a.resource_kind='TEACHER' where p_section='availability' and a.organization_id=org
 union all select to_jsonb(ss)||jsonb_build_object('label',st.full_name||' · '||su.name,'teacher_id',ss.staff_id,'starts_on',ss.effective_from,'ends_on',ss.effective_to,'is_active',ss.effective_to is null or ss.effective_to>=current_date),ss.id from public.staff_subject_assignments ss join public.staff st on st.id=ss.staff_id join public.subjects su on su.id=ss.subject_id where p_section='qualifications' and su.organization_id=org
 union all select to_jsonb(c)||jsonb_build_object('label',c.label),c.id from public.academic_closures c where p_section='closures' and c.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',b.name||' · '||s.name,'teacher',t.full_name,'room',rm.name),r.id from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where p_section='routines' and b.organization_id=org),paged as(select * from items order by item->>'label',id limit 25 offset(p_page-1)*25)
 select (select count(*) from items),coalesce((select jsonb_agg(item order by item->>'label',id) from paged),'[]') into total,rows;
 return jsonb_build_object('section',p_section,'page',p_page,'total',total,'choices',choices,'rows',rows);
end $$;
notify pgrst,'reload schema';
