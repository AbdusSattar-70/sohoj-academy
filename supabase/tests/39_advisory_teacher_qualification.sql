begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
('98000000-0000-0000-0000-000000000001','academic-admin@example.test',now(),'{"full_name":"Academic Admin"}'),
('98000000-0000-0000-0000-000000000002','academic-teacher@example.test',now(),'{"full_name":"Academic Teacher"}');
select public.bootstrap_admin('academic-admin@example.test','Academic Admin');
select set_config('request.jwt.claim.sub','',true);
select public.request_staff_access('{"full_name":"Academic Teacher","email":"academic-teacher@example.test","mobile":"01712345678","requested_role":"TEACHER","purpose":"Teach academic classes"}');
select set_config('request.jwt.claim.sub','98000000-0000-0000-0000-000000000001',true);
do $test$
declare paid_case uuid;preview jsonb;rid uuid;teacher uuid;branch uuid;y public.academic_years;class_id uuid;program uuid;subject uuid;offering uuid;batch uuid;room uuid;routine uuid;session uuid;replaced uuid;past_session uuid;log_id uuid;student uuid;enrollment uuid;attendance uuid;approval uuid;day date;past date;today date:=(now() at time zone 'Asia/Dhaka')::date;w jsonb;result jsonb;payload jsonb;rejected boolean;i int;teacher_profile uuid:='98000000-0000-0000-0000-000000000002';admin uuid:=auth.uid();begin
 select id into rid from public.staff_access_requests where email='academic-teacher@example.test';
 perform public.review_staff_access(jsonb_build_object('id',rid,'action','VERIFY','assigned_role','TEACHER','reason','Verified actual teacher identity'));
 perform public.review_staff_access(jsonb_build_object('id',rid,'action','COMPLETE_INVITATION','reason','Verified teacher account activated'));
 select id into teacher from public.staff where profile_id=teacher_profile;
 select * into y from public.academic_years where today between starts_on and ends_on limit 1;
 select id into branch from public.branches where is_active limit 1;select id into class_id from public.classes where is_active limit 1;select id into program from public.programs where is_active limit 1;select id into subject from public.subjects where is_active limit 1;
 update public.staff_role_assignments set effective_from=y.starts_on where staff_id=teacher;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',y.id,'class_id',class_id,'program_id',program,'code','ACADEMIC_FLOW_TEST','reason','Create academic workflow fixture'));offering:=(result->>'offering_id')::uuid;
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Prepare academic test fee','components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',1000,'charge_type','TUITION','recurrence','PER_CYCLE'))));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'code','ACADEMIC_BATCH','name','Academic batch','capacity',12,'reason','Prepare fixture teaching batch'));batch:=(result->>'id')::uuid;
 perform public.academic_planning_command(jsonb_build_object('action','OFFERING_PLAN','id',offering,'operation_kind','COACHING','starts_on',y.starts_on,'ends_on',y.ends_on,'days','[0,1,2,3,4,5,6]'::jsonb,'request_id',gen_random_uuid(),'reason','Confirmed programme days and dates'));
 result:=public.academic_planning_command(jsonb_build_object('action','ROOM','branch_id',branch,'name','Academic test room','capacity',12,'request_id',gen_random_uuid(),'reason','Confirmed actual classroom seats'));room:=(result->>'id')::uuid;

 select id into student from public.staff where profile_id=admin and status='ACTIVE';
 if student is null then raise exception 'Admin Staff identity missing';end if;
 w:=public.academic_planning_workspace('routines');
 if not exists(select 1 from jsonb_array_elements(w->'choices'->'teachers')x where(x->>'id')::uuid=teacher) or not exists(select 1 from jsonb_array_elements(w->'choices'->'teachers')x where(x->>'id')::uuid=student and(x->>'is_self')::boolean) then raise exception 'Active teacher/admin self missing from choices';end if;
 if exists(select 1 from public.staff_subject_assignments where staff_id in(teacher,student)) then raise exception 'Fixture must not have subject qualifications';end if;
 day:=today+1;
 perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','ROOM','resource_id',room,'weekday',extract(dow from day)::int,'start_time','08:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed room availability'));
 perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','TEACHER','resource_id',teacher,'weekday',extract(dow from day)::int,'start_time','08:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed unqualified teacher availability'));
 perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','TEACHER','resource_id',student,'weekday',extract(dow from day)::int,'start_time','08:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed administrator teaching availability'));
 payload:=jsonb_build_object('action','ROUTINE','batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'days',jsonb_build_array(extract(dow from day)::int),'start_time','08:00','end_time','09:00','starts_on',day,'ends_on',day,'request_id',gen_random_uuid(),'reason','Assign active teacher without qualification');
 result:=public.academic_schedule_command(payload);routine:=(result->>'id')::uuid;
 perform public.academic_schedule_command(jsonb_build_object('action','GENERATE','routine_id',routine,'starts_on',day,'ends_on',day,'planned_scope','Unqualified teacher teaching scope','request_id',gen_random_uuid(),'reason','Generate actual class without qualification'));
 result:=public.academic_schedule_command(payload||jsonb_build_object('teacher_id',student,'start_time','09:00','end_time','10:00','request_id',gen_random_uuid(),'reason','Assign administrator own Staff identity'));routine:=(result->>'id')::uuid;
 perform public.academic_schedule_command(jsonb_build_object('action','GENERATE','routine_id',routine,'starts_on',day,'ends_on',day,'planned_scope','Administrator teaches next class','request_id',gen_random_uuid(),'reason','Generate administrator class without teaching role'));
 if(select count(*) from public.class_sessions where batch_id=batch)<>2 then raise exception 'Teacher and admin generation failed';end if;
 perform public.check_academic_slot(batch,subject,teacher,room,day,'07:00','08:00'); -- Preferred hours are advisory; real conflicts and closures stay enforced.
 rejected:=false;begin perform public.check_academic_slot(batch,subject,gen_random_uuid(),room,day,'08:00','09:00');exception when others then rejected:=true;end;if not rejected then raise exception 'Invalid staff identity accepted';end if;
 rejected:=false;begin perform public.academic_schedule_command(payload||jsonb_build_object('request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected then raise exception 'Routine double booking accepted';end if;
 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 rejected:=false;begin perform public.academic_schedule_command(payload||jsonb_build_object('request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected then raise exception 'Teacher granted scheduling permissions';end if;
end $test$;
rollback;
