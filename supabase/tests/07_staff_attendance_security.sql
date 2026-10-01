begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('92000000-0000-0000-0000-000000000001','request-review-admin@example.test',now(),'{"full_name":"Access Review Admin"}'),
 ('92000000-0000-0000-0000-000000000002','requested-teacher@example.test',now(),'{"full_name":"Requested Teacher"}');
select public.bootstrap_admin('request-review-admin@example.test','Access Review Admin');
select set_config('request.jwt.claim.sub','',true);
select public.request_staff_access('{"full_name":"Requested Teacher","email":"requested-teacher@example.test","mobile":"01712345999","requested_role":"ADMIN","purpose":"Teach assigned academy classes"}');
do $test$
begin
 if exists(select 1 from public.user_role_assignments where profile_id='92000000-0000-0000-0000-000000000002') then raise exception 'Requested role must not grant access.'; end if;
 if has_function_privilege('authenticated','public.execute_admission_stage(jsonb)','EXECUTE') then raise exception 'Internal admission engine is callable by client.'; end if;
 if has_function_privilege('anon','public.review_staff_access(jsonb)','EXECUTE') then raise exception 'Anonymous user may review access.'; end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$
declare request_id uuid;
begin
 select id into request_id from public.staff_access_requests where email='requested-teacher@example.test';
 perform public.review_staff_access(jsonb_build_object('id',request_id,'action','VERIFY','assigned_role','TEACHER','reason','Verified identity and teaching responsibilities'));
 if exists(select 1 from public.user_role_assignments where profile_id='92000000-0000-0000-0000-000000000002') then raise exception 'Verification alone must not grant access.'; end if;
 perform public.review_staff_access(jsonb_build_object('id',request_id,'action','COMPLETE_INVITATION','reason','Supabase invitation created verified account'));
 if not exists(select 1 from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id='92000000-0000-0000-0000-000000000002' and r.code='TEACHER' and a.is_active) then raise exception 'Verified teaching role not assigned.'; end if;
 if exists(select 1 from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id='92000000-0000-0000-0000-000000000002' and r.code='ADMIN') then raise exception 'Unverified requested ADMIN role was granted.'; end if;
end $test$;
do $test$
declare sid uuid;payload jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date-1;
begin
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 payload:=jsonb_build_object('action','RECORD_ATTENDANCE','staff_id',sid,'request_id','97000000-0000-0000-0000-000000000001','work_date',day,'status','PRESENT','started_at',day::text||'T07:00:00+06:00','ended_at',day::text||'T11:00:00+06:00','break_minutes',30,'reason','Verified actual staff attendance');
 perform public.workforce_command(payload);perform public.workforce_command(payload);
 if (select count(*) from public.staff_attendance_records where staff_id=sid)<>1 then raise exception 'Attendance retry duplicated records.';end if;
 perform public.workforce_command(jsonb_build_object('action','SAVE_TERMS','staff_id',sid,'request_id','97000000-0000-0000-0000-000000000002','model','HOURLY','monthly_base',0,'hourly_rate',100,'pay_day',10,'effective_from',day,'reason','Agreed hourly compensation terms'));
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$
begin
 begin perform public.review_staff_access(jsonb_build_object('id',(select id from public.staff_access_requests where email='requested-teacher@example.test'),'action','VERIFY','assigned_role','ADMIN','reason','Attempt self privilege escalation'));
 raise exception 'Teacher self-escalation was accepted.';
 exception when others then if sqlerrm='Teacher self-escalation was accepted.' then raise; end if; end;
end $test$;
do $test$
declare w jsonb;sid uuid;rejected boolean:=false;day date:=(now() at time zone 'Asia/Dhaka')::date-1;
begin
 w:=public.staff_work_workspace(day);
 if (w->>'hours')::numeric<>3.5 or (w->>'hourlyEstimate')::numeric<>350 or (w->>'presentDays')::integer<>1 then raise exception 'Own attendance calculation incorrect.';end if;
 if jsonb_array_length(w->'people')<>0 then raise exception 'Staff directory leaked.';end if;
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000001';
 begin perform public.staff_work_workspace(day,sid);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Foreign staff records accessible.';end if;
 rejected:=false;
 begin perform public.workforce_command(jsonb_build_object('staff_id',sid,'request_id',gen_random_uuid(),'action','SAVE_TERMS','reason','Attempted own pay change'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher can change compensation terms.';end if;
end $test$;
rollback;
