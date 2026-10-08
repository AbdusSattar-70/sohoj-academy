-- Generated from supabase/schema/access/27_scoped_academic_workspaces.sql; edit the source, then run pnpm db:baseline.
-- Request workspace is a preference, validated against account assignments on every DB request.
create function public.current_workspace_id() returns uuid language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected uuid;headers jsonb;
begin
 headers:=coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb;
 begin selected:=nullif(headers->>'x-sohoj-workspace','')::uuid;exception when invalid_text_representation then raise exception 'Select a valid workspace.' using errcode='42501';end;
 if selected is not null and not public.can_use_workspace(selected) then raise exception 'This workspace is not assigned to your account.' using errcode='42501';end if;
 return selected;
end $$;
create function public.require_workspace_run(p_run uuid) returns void language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from public.programme_runs where id=p_run and academy_id=public.current_academy_id() and division_id=public.current_workspace_id()) then raise exception 'Select a programme in your current workspace.' using errcode='42501';end if;
end $$;
-- Internal read projections. No client can query these views or bypass controlled RPCs.
create view public.workspace_runs with(security_barrier=true) as select * from public.programme_runs where academy_id=public.current_academy_id() and division_id=public.current_workspace_id();
create view public.workspace_batches with(security_barrier=true) as select * from public.teaching_batches where run_id in(select id from public.workspace_runs);
create view public.workspace_sessions with(security_barrier=true) as select * from public.academic_sessions where batch_id in(select id from public.workspace_batches);
create view public.workspace_routines with(security_barrier=true) as select * from public.academic_routines where batch_id in(select id from public.workspace_batches);
create view public.workspace_enrollments with(security_barrier=true) as select * from public.academic_batch_enrollments where batch_id in(select id from public.workspace_batches);
create view public.workspace_contacts with(security_barrier=true) as select * from public.academic_notification_contacts where batch_id in(select id from public.workspace_batches);
create view public.workspace_emails with(security_barrier=true) as select * from public.academic_email_queue where session_id in(select id from public.workspace_sessions);
revoke all on public.workspace_runs,public.workspace_batches,public.workspace_sessions,public.workspace_routines,public.workspace_enrollments,public.workspace_contacts,public.workspace_emails from public,anon,authenticated;
-- Writes are checked independently of UI filters, including direct RPC, stale links and retries.
create function public.guard_workspace_write() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare run_id uuid;
begin
 if auth.uid() is null then return new;end if;
 if tg_table_name='programme_runs' then
  if new.division_id is distinct from public.current_workspace_id() or new.academy_id is distinct from public.current_academy_id() then raise exception 'The programme belongs to another workspace.' using errcode='42501';end if;
  if tg_op='UPDATE' and old.division_id is distinct from new.division_id then raise exception 'A programme cannot be moved between workspaces.';end if;
 elsif tg_table_name in('teaching_batches','run_fee_settings','run_fee_components','run_subjects') then run_id:=new.run_id;perform public.require_workspace_run(run_id);
 else
  select b.run_id into run_id from public.teaching_batches b where b.id=new.batch_id;perform public.require_workspace_run(run_id);
 end if;
 return new;
end $$;
do $$ declare relation text;begin
 foreach relation in array array['programme_runs','teaching_batches','run_fee_settings','run_fee_components','run_subjects','academic_sessions','academic_routines','academic_batch_enrollments','academic_notification_contacts'] loop
 execute format('create trigger enforce_workspace before insert or update on public.%I for each row execute function public.guard_workspace_write()',relation);
 end loop;
end $$;
-- Existing read policies also stay scoped when a client uses table select directly.
create policy scoped_run_read on public.programme_runs as restrictive for select to authenticated using(division_id=public.current_workspace_id());

revoke all on function public.current_workspace_id(),public.require_workspace_run(uuid),public.guard_workspace_write() from public,anon,authenticated;
grant execute on function public.current_workspace_id() to authenticated;

create function public.teacher_in_workspace(p_person uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.person_accounts pa join public.account_profiles p on p.id=pa.profile_id where pa.person_id=p_person and p.academy_id=public.current_academy_id() and p.is_active and(exists(select 1 from public.account_roles where profile_id=p.id and role_code='ADMIN') or exists(select 1 from public.account_workspaces where profile_id=p.id and division_id=public.current_workspace_id())))
$$;
revoke all on function public.teacher_in_workspace(uuid) from public,anon,authenticated;

-- Scoped list_current_programmes; ownership checks remain in place.
create or replace function public.list_current_programmes(p_division_id uuid default null,p_query text default '',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); academy uuid:=public.require_operation('academics.view'); result jsonb;
begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 100000 then raise exception 'Choose a valid search/page.'; end if;
 with matched as(select r.*,d.code division_code,d.name division_name,p.name programme_name,c.name campus_name,
  (select count(*) from public.workspace_batches b where b.run_id=r.id and b.is_active) active_batches
  from public.workspace_runs r join public.operating_divisions d on d.id=r.division_id join public.programmes p on p.id=r.programme_id join public.campuses c on c.id=r.campus_id
  where r.academy_id=academy and (p_division_id is null or r.division_id=p_division_id) and (btrim(p_query)='' or position(lower(btrim(p_query)) in lower(r.title||' '||r.code))>0)),
 paged as(select * from matched order by starts_on desc,title,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,
 'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by starts_on desc,title,id) from paged),'[]')) into result;
 return result;
end $$;

-- Scoped programme_run_setup; ownership checks remain in place.
create or replace function public.programme_run_setup(p_run_id uuid,p_batch_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); academy uuid:=public.require_operation('academics.view'); run public.programme_runs; result jsonb;
begin
 if p_batch_page is null or p_batch_page not between 1 and 100000 then raise exception 'Choose a valid batch page.'; end if;
 select * into run from public.workspace_runs where id=p_run_id and academy_id=academy;
 if not found then raise exception 'Current programme not found.'; end if;
 select jsonb_build_object('run',to_jsonb(run),'programmeName',(select name from public.programmes where id=run.programme_id),'contextLocked',exists(select 1 from public.batch_seats s join public.workspace_batches b on b.id=s.batch_id where b.run_id=run.id),'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'name_bn',d.name_bn,'is_active',d.is_active) order by d.sort_order,d.name) from public.run_subjects rs join public.directory_entries d on d.id=rs.subject_id where rs.run_id=run.id and rs.is_active),'[]'),'feeSettings',(select to_jsonb(f) from public.run_fee_settings f where run_id=run.id),
 'components',coalesce((select jsonb_agg(to_jsonb(c) order by c.code) from public.run_fee_components c where run_id=run.id and is_active),'[]'),
 'subjectIds',coalesce((select jsonb_agg(subject_id order by subject_id) from public.run_subjects where run_id=run.id and is_active),'[]'),
 'batchPage',p_batch_page,'batchPageSize',25,'batchTotal',(select count(*) from public.workspace_batches where run_id=run.id),
 'batches',coalesce((select jsonb_agg(to_jsonb(b) order by b.name,b.id) from (
  select tb.*,(select count(*) from public.batch_seats s where s.batch_id=tb.id and s.is_active) occupied
  from public.workspace_batches tb where tb.run_id=run.id order by name,id limit 25 offset(p_batch_page-1)*25)b),'[]')) into result;
 return result;
end $$;

-- Scoped academic_operation_choices; ownership checks remain in place.
create or replace function public.academic_operation_choices(p_section text default 'SESSION') returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.manage');
begin
 if p_section not in('SESSION','QUALIFICATIONS','AVAILABILITY','CONTACTS') then raise exception 'Choose an academic work area.'; end if;
 return jsonb_build_object(
 'rooms',case when p_section in('SESSION','AVAILABILITY','QUALIFICATIONS') then coalesce((select jsonb_agg(to_jsonb(r) order by name) from public.academic_rooms r where academy_id=aid and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'teachers',case when p_section in('SESSION','QUALIFICATIONS','AVAILABILITY') then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',public.teacher_resource_name(p.id)) order by p.full_name)
   from public.people p where p.academy_id=aid and p.is_active and public.teacher_in_workspace(p.id) and exists(select 1 from public.person_responsibilities x where x.person_id=p.id and x.responsibility='TEACHER' and x.is_active)),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',case when p_section in('SESSION','QUALIFICATIONS') then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name) order by sort_order,name) from public.directory_entries d where academy_id=aid and kind='SUBJECT' and is_active),'[]'::jsonb) else '[]'::jsonb end,
 'qualifications',case when p_section='SESSION' then coalesce((select jsonb_agg(jsonb_build_object('teacherId',q.teacher_id,'subjectId',q.subject_id)) from public.teacher_subject_qualifications q where q.academy_id=aid and public.teacher_in_workspace(q.teacher_id) and q.is_active),'[]'::jsonb) else '[]'::jsonb end,
 'batches',case when p_section in('SESSION','CONTACTS') then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||r.title,'startsOn',r.starts_on,'endsOn',r.ends_on,'defaultDays',r.default_weekdays,'slots',b.planned_slots,'subjectIds',coalesce((select jsonb_agg(rs.subject_id) from public.run_subjects rs where rs.run_id=r.id and rs.is_active),'[]'::jsonb)) order by b.name)
   from public.workspace_batches b join public.workspace_runs r on r.id=b.run_id where b.academy_id=aid and b.is_active and r.is_active),'[]'::jsonb) else '[]'::jsonb end);
end $$;

-- Scoped academic_session_register; ownership checks remain in place.
create or replace function public.academic_session_register(p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'canReview',manager and public.can_operate('academics.review'),'sessions',coalesce((select jsonb_agg(to_jsonb(x)) from(
  select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name
  from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id
  join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id
  join public.directory_entries d on d.id=s.subject_id
  where s.academy_id=aid and(manager or s.teacher_id=own_id)
  order by case when (manager and s.status='SUBMITTED') or (not manager and s.status='RETURNED') then 0 when (s.starts_at at time zone 'Asia/Dhaka')::date=(now() at time zone 'Asia/Dhaka')::date then 1 when s.starts_at>now() and s.status='SCHEDULED' then 2 else 3 end,case when s.starts_at>now() then s.starts_at end,s.starts_at desc,s.id limit 25 offset(p_page-1)*25)x),'[]'::jsonb),
  'total',(select count(*) from public.workspace_sessions where academy_id=aid and(manager or teacher_id=own_id)));
end $$;

-- Scoped academic_calendar; ownership checks remain in place.
create or replace function public.academic_calendar(p_from text,p_through text,p_page integer default 1,p_status text default '') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage'); start_day date:=p_from::date; end_day date:=p_through::date;
begin
 if start_day is null or end_day is null or end_day-start_day not between 0 and 31 or p_page is null or p_page not between 1 and 10000 or p_status not in('','SCHEDULED','SUBMITTED','RETURNED','APPROVED','CANCELLED') then raise exception 'Choose a date range of 1 to 32 days, a valid status and page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'canReview',manager and public.can_operate('academics.review'),'page',p_page,'pageSize',25,'from',start_day,'through',end_day,
 'total',(select count(*) from public.workspace_sessions s where s.academy_id=aid and(manager or s.teacher_id=own_id) and (s.starts_at at time zone 'Asia/Dhaka')::date between start_day and end_day and(p_status='' or s.status=p_status)),
 'sessions',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.academy_id=aid and(manager or s.teacher_id=own_id) and(s.starts_at at time zone 'Asia/Dhaka')::date between start_day and end_day and(p_status='' or s.status=p_status) order by s.starts_at,s.id limit 25 offset(p_page-1)*25)x),'[]'),
 'closures',coalesce((select jsonb_agg(jsonb_build_object('date',closed_on,'name',name) order by closed_on) from public.academic_closures where academy_id=aid and is_active and closed_on between start_day and end_day),'[]'));
end $$;

-- Scoped academic_session_detail; ownership checks remain in place.
create or replace function public.academic_session_detail(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage'); item jsonb;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 select to_jsonb(x) into item from(select s.*,b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.id=p_id and s.academy_id=aid and(manager or s.teacher_id=own_id))x;
 if item is null then raise exception 'Class not found or not assigned to you.'; end if;
 return jsonb_build_object('manage',manager,'canReview',manager and public.can_operate('academics.review'),'sessions',jsonb_build_array(item),'total',1);
end $$;

-- Scoped academic_routine_register; ownership checks remain in place.
create or replace function public.academic_routine_register(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'canReview',manager and public.can_operate('academics.review'),'page',p_page,'pageSize',25,'total',(select count(*) from public.workspace_routines where academy_id=aid and(manager or teacher_id=own_id)),
 'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select rt.*,b.name batch_name,d.name subject_name,p.full_name teacher_name,r.name room_name,(select count(*) from public.workspace_sessions s where s.routine_id=rt.id) session_count from public.workspace_routines rt join public.workspace_batches b on b.id=rt.batch_id join public.directory_entries d on d.id=rt.subject_id join public.people p on p.id=rt.teacher_id join public.academic_rooms r on r.id=rt.room_id where rt.academy_id=aid and(manager or rt.teacher_id=own_id) order by rt.is_active desc,rt.ends_on desc,rt.id limit 25 offset(p_page-1)*25)x),'[]'));
end $$;

-- Scoped academic_session_work; ownership checks remain in place.
create or replace function public.academic_session_work(p_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); detail jsonb:=public.academic_session_detail(p_id); item jsonb:=detail->'sessions'->0; own_id uuid; roster jsonb; attendance jsonb; edit_allowed boolean;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 roster:=public.academic_batch_roster((item->>'batch_id')::uuid,((item->>'starts_at')::timestamptz at time zone 'Asia/Dhaka')::date::text);
 select coalesce(jsonb_agg(jsonb_build_object('personId',a.person_id,'status',a.status,'note',a.note)),'[]') into attendance from public.academic_session_attendance a where a.session_id=p_id;
 edit_allowed:=(item->>'teacher_id')::uuid=own_id and item->>'status' in('SCHEDULED','RETURNED');
 return jsonb_build_object('session',item,'roster',roster,'attendance',attendance,'canEdit',public.can_operate('academics.teach') and edit_allowed,'manage',detail->'manage');
end $$;

-- Scoped academic_batch_roster; ownership checks remain in place.
create or replace function public.academic_batch_roster(p_batch uuid,p_on text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view');own_id uuid; day_value date:=p_on::date;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 if not public.can_operate('academics.manage') and not exists(select 1 from public.workspace_sessions s where s.academy_id=aid and s.batch_id=p_batch and s.teacher_id=own_id and(s.starts_at at time zone 'Asia/Dhaka')::date=day_value) then raise exception 'This class is not assigned to you.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'personNo',p.person_no) order by p.full_name,p.id) from public.people p where p.academy_id=aid and exists(select 1 from public.workspace_enrollments e where e.academy_id=aid and e.batch_id=p_batch and e.person_id=p.id and e.starts_on<=day_value and(e.ends_before is null or day_value<e.ends_before))),'[]');
end $$;

-- Scoped academic_teaching_summary; ownership checks remain in place.
create or replace function public.academic_teaching_summary(p_from text,p_through text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; manager boolean:=public.can_operate('academics.manage');
begin
 if p_from::date is null or p_through::date is null or p_through::date-p_from::date not between 0 and 366 then raise exception 'Choose a valid date range up to 367 days.'; end if;
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return coalesce((select jsonb_agg(to_jsonb(x)) from(select p.id,p.full_name name,count(*) classes,round(sum(extract(epoch from(s.actual_end-s.actual_start)))/3600,2) approved_hours from public.workspace_sessions s join public.people p on p.id=s.teacher_id where s.academy_id=aid and s.status='APPROVED' and(manager or s.teacher_id=own_id) and(s.starts_at at time zone 'Asia/Dhaka')::date between p_from::date and p_through::date group by p.id,p.full_name order by p.full_name)x),'[]');
end $$;

-- Scoped academic_placement_register; ownership checks remain in place.
create or replace function public.academic_placement_register(p_batch uuid,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.manage'); run uuid;
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 select run_id into run from public.workspace_batches where id=p_batch and academy_id=aid;
 if run is null then raise exception 'Batch not found.'; end if;
 return jsonb_build_object('page',p_page,'total',(select count(*) from public.workspace_enrollments where academy_id=aid and batch_id=p_batch),
 'rows',coalesce((select jsonb_agg(to_jsonb(x)) from(select e.*,p.full_name name from public.workspace_enrollments e join public.people p on p.id=e.person_id where e.academy_id=aid and e.batch_id=p_batch order by e.ends_before nulls first,p.full_name,e.id limit 25 offset(p_page-1)*25)x),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name)) from public.workspace_batches b where b.run_id=run and b.is_active),'[]'));
end $$;

-- Scoped academic_teacher_agenda; ownership checks remain in place.
create or replace function public.academic_teacher_agenda() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.view'); own_id uuid; today date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('todayTotal',(select count(*) from public.workspace_sessions where academy_id=aid and teacher_id=own_id and(starts_at at time zone 'Asia/Dhaka')::date=today),
 'returnedTotal',(select count(*) from public.workspace_sessions where academy_id=aid and teacher_id=own_id and status='RETURNED'),
 'today',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,d.name subject_name,r.name room_name from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id join public.directory_entries d on d.id=s.subject_id join public.academic_rooms r on r.id=s.room_id where s.academy_id=aid and s.teacher_id=own_id and(s.starts_at at time zone 'Asia/Dhaka')::date=today order by s.starts_at,s.id limit 25)x),'[]'),
 'returned',coalesce((select jsonb_agg(to_jsonb(x) order by starts_at,id) from(select s.*,b.name batch_name,d.name subject_name,r.name room_name from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id join public.directory_entries d on d.id=s.subject_id join public.academic_rooms r on r.id=s.room_id where s.academy_id=aid and s.teacher_id=own_id and s.status='RETURNED' order by s.starts_at,s.id limit 25)x),'[]'));
end $$;

-- Scoped academic_settings_register; ownership checks remain in place.
create or replace function public.academic_settings_register(p_section text,p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid:=public.require_operation('academics.manage'); rows_value jsonb; total_value bigint;
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 if p_section='ROOMS' then
  select count(*) into total_value from public.academic_rooms where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select * from public.academic_rooms where academy_id=aid order by name,id limit 25 offset(p_page-1)*25)x;
 elsif p_section='WINDOWS' then
  select count(*) into total_value from public.academic_resource_windows where academy_id=aid and(resource_kind='ROOM' or public.teacher_in_workspace(resource_id));
  select jsonb_agg(to_jsonb(x)) into rows_value from(select w.*,coalesce(public.teacher_resource_name(p.id),r.name) resource_name
   from public.academic_resource_windows w left join public.people p on w.resource_kind='TEACHER' and p.id=w.resource_id
   left join public.academic_rooms r on w.resource_kind='ROOM' and r.id=w.resource_id
   where w.academy_id=aid and(w.resource_kind='ROOM' or public.teacher_in_workspace(w.resource_id)) order by w.weekday,w.starts,w.id limit 25 offset(p_page-1)*25)x;
 elsif p_section='CLOSURES' then
  select count(*) into total_value from public.academic_closures where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select * from public.academic_closures where academy_id=aid order by closed_on desc,id limit 25 offset(p_page-1)*25)x;
 elsif p_section='CONTACTS' then
  select count(*) into total_value from public.workspace_contacts where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select c.*,b.name batch_name from public.workspace_contacts c join public.workspace_batches b on b.id=c.batch_id where c.academy_id=aid order by c.name,c.id limit 25 offset(p_page-1)*25)x;
 elsif p_section='EMAILS' then
  select count(*) into total_value from public.workspace_emails where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select id,session_id,recipient,status,attempts,last_error,created_at from public.workspace_emails where academy_id=aid order by created_at desc,id limit 25 offset(p_page-1)*25)x;
 else raise exception 'Choose a settings section.'; end if;
 return jsonb_build_object('rows',coalesce(rows_value,'[]'::jsonb),'total',total_value,'page',p_page,'pageSize',25);
end $$;

-- Scoped academic_workspace; ownership checks remain in place.
create or replace function public.academic_workspace(p_page integer default 1) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare selected_workspace uuid:=public.current_workspace_id(); aid uuid; own_id uuid; manager boolean;
begin
 aid:=public.require_operation('academics.view'); manager:=public.can_operate('academics.manage');
 select person_id into own_id from public.person_accounts where profile_id=auth.uid();
 return jsonb_build_object('manage',manager,'canReview',manager and public.can_operate('academics.review'),'rooms',coalesce((select jsonb_agg(to_jsonb(r) order by name) from public.academic_rooms r where academy_id=aid),'[]'::jsonb),
 'batches',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||pr.title)) from public.workspace_batches b join public.workspace_runs pr on pr.id=b.run_id where b.academy_id=aid and b.is_active),'[]'::jsonb) else '[]'::jsonb end,
 'teachers',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name)) from public.people p where p.academy_id=aid and p.is_active and public.teacher_in_workspace(p.id) and exists(select 1 from public.person_responsibilities x where x.person_id=p.id and x.responsibility='TEACHER' and x.is_active)),'[]'::jsonb) else '[]'::jsonb end,
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name)) from public.directory_entries d where d.academy_id=aid and d.kind='SUBJECT' and d.is_active),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(to_jsonb(x)) from (select s.*, b.name batch_name,p.full_name teacher_name,r.name room_name,d.name subject_name from public.workspace_sessions s join public.workspace_batches b on b.id=s.batch_id join public.people p on p.id=s.teacher_id join public.academic_rooms r on r.id=s.room_id join public.directory_entries d on d.id=s.subject_id where s.academy_id=aid and (manager or s.teacher_id=own_id) order by s.starts_at desc,s.id limit 25 offset (greatest(1,least(p_page,10000))-1)*25) x),'[]'::jsonb),
 'total',(select count(*) from public.workspace_sessions s where s.academy_id=aid and(manager or s.teacher_id=own_id)),
 'queue',case when manager then coalesce((select jsonb_agg(to_jsonb(x)) from(select id,session_id,recipient,status,attempts,last_error,created_at from public.workspace_emails where academy_id=aid order by created_at desc limit 25)x),'[]'::jsonb) else '[]'::jsonb end);
end $$;

create function public.check_workspace_payload(p_payload jsonb,p_kind text) returns void language plpgsql stable security definer set search_path=public,pg_temp as $$
declare target uuid:=nullif(p_payload->>'id','')::uuid;run uuid;
begin
 if public.current_workspace_id() is null then raise exception 'Select a workspace before working with academic records.' using errcode='42501';end if;
 if p_kind='SESSION' and target is not null and coalesce(p_payload->>'action','') not in('ROOM','CLOSURE','WINDOW','CONTACT') then select b.run_id into run from public.academic_sessions s join public.teaching_batches b on b.id=s.batch_id where s.id=target;perform public.require_workspace_run(run);
 elsif p_kind='ROUTINE' and target is not null then select b.run_id into run from public.academic_routines r join public.teaching_batches b on b.id=r.batch_id where r.id=target;perform public.require_workspace_run(run);
 elsif p_kind='PLAN' and target is not null then
  if p_payload->>'target'='RUN' then run:=target;else select run_id into run from public.teaching_batches where id=target;end if;perform public.require_workspace_run(run);
 end if;
 if nullif(p_payload->>'batchId','') is not null then select run_id into run from public.teaching_batches where id=(p_payload->>'batchId')::uuid;perform public.require_workspace_run(run);end if;
end $$;
-- Public entry points validate scope BEFORE operation replay; old implementations are internal only.
alter function public.academic_command(uuid,jsonb) rename to academy_unscoped_command;
revoke all on function public.academy_unscoped_command(uuid,jsonb) from public,anon,authenticated;
create function public.academic_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform public.check_workspace_payload(p_payload,'SESSION');
 if p_payload->>'action' in('CREATE','CHANGE','MAKEUP','ROUTINE') and not public.teacher_in_workspace((p_payload->>'teacherId')::uuid) then raise exception 'Assign this teacher to the current workspace before scheduling.';end if;
 if p_payload->>'action'='SUBMIT' then perform public.require_operation('academics.teach');end if;
 if p_payload->>'action' in('APPROVE','RETURN') then perform public.require_operation('academics.review');end if;
 return public.academy_unscoped_command(p_request_id,p_payload);
end $$;
alter function public.academic_session_command(uuid,jsonb) rename to academy_unscoped_session_command;
revoke all on function public.academy_unscoped_session_command(uuid,jsonb) from public,anon,authenticated;
create function public.academic_session_command(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform public.check_workspace_payload(p_payload,'SESSION');
 if p_payload->>'action'='SUBMIT' then perform public.require_operation('academics.teach');end if;
 if p_payload->>'action' in('APPROVE','RETURN') then perform public.require_operation('academics.review');end if;
 return public.academy_unscoped_session_command(p_request_id,p_payload);
end $$;
alter function public.save_academic_session_work(uuid,jsonb) rename to academy_unscoped_class_work;
revoke all on function public.academy_unscoped_class_work(uuid,jsonb) from public,anon,authenticated;
create function public.save_academic_session_work(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.require_operation('academics.teach');perform public.check_workspace_payload(p_payload,'SESSION');return public.academy_unscoped_class_work(p_request_id,p_payload);end $$;
alter function public.manage_academic_routine(uuid,jsonb) rename to academy_unscoped_routine;
revoke all on function public.academy_unscoped_routine(uuid,jsonb) from public,anon,authenticated;
create function public.manage_academic_routine(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.check_workspace_payload(p_payload,'ROUTINE');return public.academy_unscoped_routine(p_request_id,p_payload);end $$;
alter function public.save_academic_plan(uuid,jsonb) rename to academy_unscoped_plan;
revoke all on function public.academy_unscoped_plan(uuid,jsonb) from public,anon,authenticated;
create function public.save_academic_plan(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.check_workspace_payload(p_payload,'PLAN');return public.academy_unscoped_plan(p_request_id,p_payload);end $$;
alter function public.change_student_batch(uuid,jsonb) rename to academy_unscoped_placement;
revoke all on function public.academy_unscoped_placement(uuid,jsonb) from public,anon,authenticated;
create function public.change_student_batch(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.check_workspace_payload(p_payload,'PLACEMENT');return public.academy_unscoped_placement(p_request_id,p_payload);end $$;
revoke all on function public.check_workspace_payload(jsonb,text),public.academic_command(uuid,jsonb),public.academic_session_command(uuid,jsonb),public.save_academic_session_work(uuid,jsonb),public.manage_academic_routine(uuid,jsonb),public.save_academic_plan(uuid,jsonb),public.change_student_batch(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.academic_command(uuid,jsonb),public.academic_session_command(uuid,jsonb),public.save_academic_session_work(uuid,jsonb),public.manage_academic_routine(uuid,jsonb),public.save_academic_plan(uuid,jsonb),public.change_student_batch(uuid,jsonb) to authenticated;

create or replace function public.academic_resource_register(p_page integer default 1) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage');
begin
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Choose a valid page.'; end if;
 return jsonb_build_object(
 'qualifications',coalesce((select jsonb_agg(to_jsonb(q)) from public.teacher_subject_qualifications q where academy_id=aid and public.teacher_in_workspace(q.teacher_id)),'[]'::jsonb),
 'blocks',coalesce((select jsonb_agg(to_jsonb(x)) from(select * from public.academic_resource_blocks where academy_id=aid and(resource_kind='ROOM' or public.teacher_in_workspace(resource_id)) order by starts_at desc,id limit 25 offset (p_page-1)*25)x),'[]'::jsonb),
 'blockTotal',(select count(*) from public.academic_resource_blocks where academy_id=aid and(resource_kind='ROOM' or public.teacher_in_workspace(resource_id))));
end $$;

alter function public.save_programme_run(jsonb) rename to internal_workspace_save_programme_run;
revoke all on function public.internal_workspace_save_programme_run(jsonb) from public,anon,authenticated;
create function public.save_programme_run(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin if nullif(p_input->>'id','') is not null then perform public.require_workspace_run((p_input->>'id')::uuid);end if; if (p_input->>'division_id')::uuid is distinct from public.current_workspace_id() then raise exception 'Choose the current workspace.' using errcode='42501';end if; return public.internal_workspace_save_programme_run(p_input);end $$;
revoke all on function public.save_programme_run(jsonb) from public,anon;
grant execute on function public.save_programme_run(jsonb) to authenticated;

alter function public.save_run_fees(jsonb) rename to internal_workspace_save_run_fees;
revoke all on function public.internal_workspace_save_run_fees(jsonb) from public,anon,authenticated;
create function public.save_run_fees(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.require_workspace_run((p_input->>'run_id')::uuid); return public.internal_workspace_save_run_fees(p_input);end $$;
revoke all on function public.save_run_fees(jsonb) from public,anon;
grant execute on function public.save_run_fees(jsonb) to authenticated;

alter function public.save_teaching_batch(jsonb) rename to internal_workspace_save_teaching_batch;
revoke all on function public.internal_workspace_save_teaching_batch(jsonb) from public,anon,authenticated;
create function public.save_teaching_batch(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.require_workspace_run((p_input->>'run_id')::uuid);if nullif(p_input->>'id','') is not null then perform public.require_workspace_run((select run_id from public.teaching_batches where id=(p_input->>'id')::uuid));end if; return public.internal_workspace_save_teaching_batch(p_input);end $$;
revoke all on function public.save_teaching_batch(jsonb) from public,anon;
grant execute on function public.save_teaching_batch(jsonb) to authenticated;

alter function public.set_programme_run_active(jsonb) rename to internal_workspace_set_programme_run_active;
revoke all on function public.internal_workspace_set_programme_run_active(jsonb) from public,anon,authenticated;
create function public.set_programme_run_active(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin perform public.require_workspace_run((p_input->>'id')::uuid); return public.internal_workspace_set_programme_run_active(p_input);end $$;
revoke all on function public.set_programme_run_active(jsonb) from public,anon;
grant execute on function public.set_programme_run_active(jsonb) to authenticated;

-- Public claims remain untouched; offering preference is used only to route the review queue.
create or replace function public.search_enquiries(p_query text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); workspace uuid:=public.current_workspace_id();result jsonb;
begin
 if p_page is null or p_page not between 1 and 100000 or p_query is null or length(p_query)>160 then raise exception 'Invalid search.';end if;
 with matched as(select e.id,e.enquiry_no,e.payload,e.status,e.created_at,
 r.division_id is null needs_routing
 from public.enquiries e left join public.programme_runs r on r.id::text=e.payload->>'offeringId' and r.academy_id=e.academy_id
 where e.academy_id=academy and workspace is not null and (r.division_id=workspace or (r.division_id is null and exists(select 1 from public.account_roles where profile_id=auth.uid() and role_code='ADMIN')))
 and(p_query='' or e.payload->>'studentName' ilike '%'||p_query||'%' or e.payload->>'mobile' ilike '%'||p_query||'%')),
 paged as(select * from matched order by created_at desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by created_at desc,id) from paged),'[]')) into result;return result;
end $$;

-- Resource booking conflict checks remain academy-wide: shared rooms/teachers cannot double-book.
-- Staff identities, schools, subjects, years and physical rooms are shared master data, not duplicate workspace records.

-- Keep one person identity while each operational directory shows only relevant people.
create function public.person_in_workspace(p_person uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.academic_batch_enrollments e join public.programme_runs r on r.id=e.run_id where e.person_id=p_person and r.academy_id=public.current_academy_id() and r.division_id=public.current_workspace_id())
 or exists(select 1 from public.person_accounts pa join public.account_workspaces w on w.profile_id=pa.profile_id where pa.person_id=p_person and w.division_id=public.current_workspace_id())
 or exists(select 1 from public.person_accounts pa join public.account_roles ar on ar.profile_id=pa.profile_id where pa.person_id=p_person and ar.role_code='ADMIN' and pa.academy_id=public.current_academy_id() and public.current_workspace_id() is not null)
 or exists(select 1 from public.person_relationships rel join public.academic_batch_enrollments e on e.person_id=rel.person_id join public.programme_runs r on r.id=e.run_id where rel.related_person_id=p_person and r.academy_id=public.current_academy_id() and r.division_id=public.current_workspace_id())
$$;
revoke all on function public.person_in_workspace(uuid) from public,anon,authenticated;

create or replace function public.search_people_by_role(p_query text default '',p_page integer default 1,p_responsibility text default '') returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb; needle text:=lower(btrim(p_query));
begin
 if p_page is null or p_page not between 1 and 100000 or needle is null or length(needle)>160 or p_responsibility is null or p_responsibility not in('','STUDENT','GUARDIAN','STAFF','TEACHER','REFERRER') then raise exception 'Invalid person search.';end if;
 with matched as(select id,person_no,staff_no,referrer_no,full_name,mobile,email,is_active,revision from public.people p where academy_id=academy and public.person_in_workspace(id) and
 (needle='' or position(needle in lower(full_name))>0 or position(needle in coalesce(mobile,''))>0 or position(needle in lower(coalesce(email,'')))>0 or person_no::text=needle or lower('SA-STF-'||lpad(staff_no::text,greatest(5,length(staff_no::text)),'0'))=needle or lower('SA-RFR-'||lpad(referrer_no::text,greatest(5,length(referrer_no::text)),'0'))=needle) and
 (p_responsibility='' or exists(select 1 from public.person_responsibilities r where r.person_id=p.id and r.responsibility=p_responsibility and r.is_active))),
 paged as(select * from matched order by full_name,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by full_name,id) from paged),'[]')) into result;return result;
end $$;

create or replace function public.search_people(p_query text default '',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); result jsonb; needle text:=btrim(p_query);
begin
 if p_page is null or p_page<1 or p_page>100000 then raise exception 'Choose a valid page.'; end if;
 if needle is null or length(needle)>160 then raise exception 'Enter a valid search.'; end if;
 with matched as (
  select id,person_no,full_name,mobile,email,is_active,revision from public.people
  where academy_id=academy and public.person_in_workspace(id) and (needle='' or position(lower(needle) in lower(full_name))>0 or position(needle in coalesce(mobile,''))>0 or person_no::text=needle)
 ), paged as(select * from matched order by full_name,id limit 25 offset (p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,
 'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by full_name,id) from paged),'[]')) into result;
 return result;
end $$;

create or replace function public.person_profile(p_person_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.view'); person public.people; begin
 select * into person from public.people where id=p_person_id and academy_id=academy and public.person_in_workspace(id);
 if not found then raise exception 'Person not found.'; end if;
 return to_jsonb(person)||jsonb_build_object('responsibilities',coalesce((select jsonb_agg(responsibility order by responsibility) from public.person_responsibilities where person_id=person.id and is_active),'[]'));
end $$;

create or replace function public.find_person_matches(p_input jsonb) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('people.manage');
 name_value text:=lower(btrim(coalesce(p_input->>'full_name','')));
 mobile_value text:=btrim(coalesce(p_input->>'mobile',''));
 email_value text:=lower(btrim(coalesce(p_input->>'email','')));
 excluded uuid:=nullif(p_input->>'exclude_id','')::uuid;
begin
 if length(name_value)>160 or length(mobile_value)>11 or length(email_value)>200 then raise exception 'Invalid matching input.'; end if;
 return coalesce((select jsonb_agg(to_jsonb(m)) from (
  select id,person_no,staff_no,referrer_no,full_name,mobile,email,is_active,revision from public.people
  where academy_id=academy and (excluded is null or id<>excluded) and (
   (length(name_value)>=2 and lower(full_name)=name_value) or
   (mobile_value<>'' and mobile=mobile_value) or
   (email_value<>'' and lower(email)=email_value))
  order by is_active desc,full_name,id limit 10
 )m),'[]'::jsonb);
end $$;

alter function public.preview_academic_schedule(jsonb) rename to internal_workspace_schedule_preview;
revoke all on function public.internal_workspace_schedule_preview(jsonb) from public,anon,authenticated;
create function public.preview_academic_schedule(p_payload jsonb) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 perform public.check_workspace_payload(p_payload,'SESSION');
 if not public.teacher_in_workspace((p_payload->>'teacherId')::uuid) then raise exception 'Assign this teacher to the current workspace before scheduling.';end if;
 return public.internal_workspace_schedule_preview(p_payload);
end $$;
revoke all on function public.preview_academic_schedule(jsonb) from public,anon;
grant execute on function public.preview_academic_schedule(jsonb) to authenticated;

-- Availability is shared physically, but a workspace operator may only modify assigned teachers.
alter function public.save_academic_windows(uuid,jsonb) rename to internal_workspace_windows;
revoke all on function public.internal_workspace_windows(uuid,jsonb) from public,anon,authenticated;
create function public.save_academic_windows(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_payload->>'kind'='TEACHER' and not public.teacher_in_workspace((p_payload->>'resourceId')::uuid) then raise exception 'Choose a teacher assigned to the current workspace.' using errcode='42501';end if;
 return public.internal_workspace_windows(p_request_id,p_payload);
end $$;
alter function public.save_academic_resource(uuid,jsonb) rename to internal_workspace_resource;
revoke all on function public.internal_workspace_resource(uuid,jsonb) from public,anon,authenticated;
create function public.save_academic_resource(p_request_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_payload->>'action'='QUALIFICATION' and not public.teacher_in_workspace((p_payload->>'teacherId')::uuid) then raise exception 'Choose a teacher assigned to the current workspace.' using errcode='42501';end if;
 if p_payload->>'action'='BLOCK' and p_payload->>'kind'='TEACHER' and not public.teacher_in_workspace((p_payload->>'resourceId')::uuid) then raise exception 'Choose a teacher assigned to the current workspace.' using errcode='42501';end if;
 return public.internal_workspace_resource(p_request_id,p_payload);
end $$;
revoke all on function public.save_academic_windows(uuid,jsonb),public.save_academic_resource(uuid,jsonb) from public,anon;
grant execute on function public.save_academic_windows(uuid,jsonb),public.save_academic_resource(uuid,jsonb) to authenticated;

alter function public.set_person_active(jsonb) rename to internal_workspace_person_active;
revoke all on function public.internal_workspace_person_active(jsonb) from public,anon,authenticated;
create function public.set_person_active(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.person_in_workspace((p_input->>'id')::uuid) then raise exception 'Choose a person in the current workspace.' using errcode='42501';end if;
 return public.internal_workspace_person_active(p_input);
end $$;
alter function public.save_person_profile(jsonb) rename to internal_workspace_person_profile;
revoke all on function public.internal_workspace_person_profile(jsonb) from public,anon,authenticated;
create function public.save_person_profile(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.person_in_workspace((p_input->>'id')::uuid) then raise exception 'Choose a person in the current workspace.' using errcode='42501';end if;
 return public.internal_workspace_person_profile(p_input);
end $$;
revoke all on function public.set_person_active(jsonb),public.save_person_profile(jsonb) from public,anon;
grant execute on function public.set_person_active(jsonb),public.save_person_profile(jsonb) to authenticated;
notify pgrst,'reload schema';
