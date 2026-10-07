-- Generated from supabase/schema/academics/16_focused_academic_reads.sql; edit the source, then run pnpm db:baseline.
-- Task-focused reads: opening academic navigation does not load teaching settings.
create function public.academic_session_register(p_page integer default 1) returns jsonb
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
  order by case when manager and s.status='SUBMITTED' then 0 when (s.starts_at at time zone 'Asia/Dhaka')::date=(now() at time zone 'Asia/Dhaka')::date then 1 when s.starts_at>now() and s.status='SCHEDULED' then 2 else 3 end,case when s.starts_at>now() then s.starts_at end,s.starts_at desc,s.id limit 25 offset(p_page-1)*25)x),'[]'::jsonb),
  'total',(select count(*) from public.academic_sessions where academy_id=aid and(manager or teacher_id=own_id)));
end $$;

create function public.academic_operation_choices(p_section text default 'SESSION') returns jsonb
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
 'batches',case when p_section in('SESSION','CONTACTS') then coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||r.title,'subjectIds',coalesce((select jsonb_agg(rs.subject_id) from public.run_subjects rs where rs.run_id=r.id and rs.is_active),'[]'::jsonb)) order by b.name)
   from public.teaching_batches b join public.programme_runs r on r.id=b.run_id where b.academy_id=aid and b.is_active and r.is_active),'[]'::jsonb) else '[]'::jsonb end);
end $$;

create function public.academic_settings_register(p_section text,p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); rows_value jsonb; total_value bigint;
begin
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.'; end if;
 if p_section='ROOMS' then
  select count(*) into total_value from public.academic_rooms where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select * from public.academic_rooms where academy_id=aid order by name,id limit 25 offset(p_page-1)*25)x;
 elsif p_section='WINDOWS' then
  select count(*) into total_value from public.academic_resource_windows where academy_id=aid;
  select jsonb_agg(to_jsonb(x)) into rows_value from(select w.*,coalesce(p.full_name,r.name) resource_name
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
revoke all on function public.academic_session_register(integer),public.academic_operation_choices(text),public.academic_settings_register(text,integer) from public,anon;
grant execute on function public.academic_session_register(integer),public.academic_operation_choices(text),public.academic_settings_register(text,integer) to authenticated;
