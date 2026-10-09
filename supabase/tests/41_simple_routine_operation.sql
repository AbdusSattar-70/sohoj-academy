begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
('98000000-0000-0000-0000-000000000001','academic-admin@example.test',now(),'{"full_name":"Academic Admin"}'),
('98000000-0000-0000-0000-000000000002','academic-teacher@example.test',now(),'{"full_name":"Academic Teacher"}');
select public.bootstrap_admin('academic-admin@example.test','Academic Admin');
select set_config('request.jwt.claim.sub','',true);
select public.request_staff_access('{"full_name":"Academic Teacher","email":"academic-teacher@example.test","mobile":"01712345678","requested_role":"TEACHER","purpose":"Teach academic classes"}');
select set_config('request.jwt.claim.sub','98000000-0000-0000-0000-000000000001',true);
create function public.test_reject_timetable_class() returns trigger language plpgsql as $$begin if(new.starts_at at time zone 'Asia/Dhaka')::time='14:00' then raise exception 'Injected second row save failure';end if;return new;end $$;
do $test$
declare paid_case uuid;preview jsonb;rid uuid;teacher uuid;branch uuid;y public.academic_years;class_id uuid;program uuid;subject uuid;offering uuid;batch uuid;room uuid;routine uuid;session uuid;replaced uuid;past_session uuid;log_id uuid;student uuid;enrollment uuid;attendance uuid;plan_id uuid;replacement_id uuid;approval uuid;day date;past date;today date:=(now() at time zone 'Asia/Dhaka')::date;w jsonb;result jsonb;test_input jsonb;rejected boolean;i int;teacher_profile uuid:='98000000-0000-0000-0000-000000000002';admin uuid:=auth.uid();begin
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


 insert into public.programme_offering_subjects(offering_id,subject_id,sort_order) values(offering,subject,0);
 day:=today+1;
 result:=public.academic_command(jsonb_build_object('action','PUBLISH_CURRICULUM','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'title','English topic plan','units',jsonb_build_array(jsonb_build_object('title','Tense practice','target_date',day)),'reason','Prepare dated topics for routine'));plan_id:=(result->>'id')::uuid;

 test_input:=jsonb_build_object('batch_id',batch,'starts_on',day,'ends_on',day+35,'request_id',gen_random_uuid(),'reason','Agreed weekly timetable','slots',jsonb_build_array(jsonb_build_object('weekday',extract(dow from day)::int,'subject_id',subject,'teacher_id',teacher,'room_id',room,'curriculum_id',plan_id,'start_time','08:00','end_time','09:00'),jsonb_build_object('weekday',extract(dow from day+1)::int,'subject_id',subject,'teacher_id',teacher,'room_id',room,'curriculum_id',plan_id,'start_time','09:00','end_time','10:00')));
 preview:=public.weekly_timetable_preview(test_input);
 if not(preview->>'ready')::boolean or(preview->>'count')::int<>8 then raise exception 'Optional availability preview failed: %',preview;end if;
 if exists(select 1 from public.academic_routines where batch_id=batch) or exists(select 1 from public.class_sessions where batch_id=batch) then raise exception 'Preview wrote classes';end if;
 perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','TEACHER','resource_id',teacher,'weekday',extract(dow from day)::int,'start_time','10:00','end_time','11:00','starts_on',day,'ends_on',day+35,'request_id',gen_random_uuid(),'reason','Confirmed teacher restricted hours'));
 preview:=public.weekly_timetable_preview(test_input);if not(preview->>'ready')::boolean or jsonb_array_length(preview->'warnings')=0 then raise exception 'Preferred hours should warn without blocking';end if;
 update public.academic_availability set is_active=false where resource_id=teacher;
 perform public.academic_planning_command(jsonb_build_object('action','CLOSURE','resource_kind','ACADEMY','name','Timetable holiday','starts_on',day+7,'ends_on',day+7,'request_id',gen_random_uuid(),'reason','Academy holiday for timetable test'));
 preview:=public.weekly_timetable_preview(test_input);if not(preview->>'ready')::boolean or(preview->>'count')::int<>7 then raise exception 'Holiday not skipped: %',preview;end if;
 result:=public.weekly_timetable_save(test_input);
 if(result->>'class_count')::int<>7 or(select count(*) from public.class_sessions where batch_id=batch)<>7 or(select count(*) from public.academic_routines where batch_id=batch)<>2 then raise exception 'Atomic routine/session save failed';end if;
 if public.weekly_timetable_save(test_input)<>result or(select count(*) from public.class_sessions where batch_id=batch)<>7 then raise exception 'Retry duplicated classes';end if;
 if exists(select 1 from public.class_sessions where batch_id=batch and curriculum_version_id is distinct from plan_id) or exists(select 1 from public.academic_routines where batch_id=batch and curriculum_version_id is distinct from plan_id) then raise exception 'Teaching plan not linked to routines and classes';end if;
 preview:=public.weekly_timetable_preview(test_input);if(preview->>'ready')::boolean then raise exception 'Double booking preview permitted';end if;
 rejected:=false;begin perform public.weekly_timetable_save(test_input||jsonb_build_object('request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected or(select count(*) from public.academic_routines where batch_id=batch)<>2 then raise exception 'Double booking save or atomicity failed';end if;
 test_input:=test_input||jsonb_build_object('request_id',gen_random_uuid(),'slots',jsonb_build_array((test_input->'slots'->0)||jsonb_build_object('start_time','12:00','end_time','13:00'),(test_input->'slots'->1)||jsonb_build_object('teacher_id',gen_random_uuid())));
 rejected:=false;begin perform public.weekly_timetable_save(test_input);exception when others then rejected:=true;end;if not rejected or(select count(*) from public.academic_routines where batch_id=batch)<>2 then raise exception 'Invalid second row left partial save';end if;

 test_input:=test_input||jsonb_build_object('request_id',gen_random_uuid(),'slots',jsonb_build_array((test_input->'slots'->0)||jsonb_build_object('teacher_id',teacher,'start_time','12:00','end_time','13:00'),(test_input->'slots'->1)||jsonb_build_object('teacher_id',teacher,'start_time','14:00','end_time','15:00')));
 create trigger test_second_row_failure before insert on public.class_sessions for each row execute function public.test_reject_timetable_class();
 rejected:=false;begin perform public.weekly_timetable_save(test_input);exception when others then rejected:=true;end;
 if not rejected or(select count(*) from public.academic_routines where batch_id=batch)<>2 or(select count(*) from public.class_sessions where batch_id=batch)<>7 or exists(select 1 from public.admission_command_keys where request_id=(test_input->>'request_id')::uuid) then raise exception 'Second row runtime failure left partial routines/classes/request result';end if;
 drop trigger test_second_row_failure on public.class_sessions;


 replacement_id:=(result->>'id')::uuid;
 test_input:=jsonb_build_object('batch_id',batch,'starts_on',day+7,'ends_on',day+35,'replace_routine_id',replacement_id,'request_id',gen_random_uuid(),'reason','Future routine changed with guardian notice','slots',jsonb_build_array(jsonb_build_object('weekday',extract(dow from day)::int,'subject_id',subject,'teacher_id',teacher,'room_id',room,'curriculum_id',plan_id,'start_time','08:00','end_time','09:00')));
 preview:=public.weekly_timetable_preview(test_input);if not(preview->>'ready')::boolean then raise exception 'Replacement preview counted its own old bookings: %',preview;end if;
 create trigger test_replacement_failure before insert on public.class_sessions for each row execute function public.test_reject_timetable_class();
 rejected:=false;begin perform public.weekly_timetable_save(test_input||jsonb_build_object('request_id',gen_random_uuid(),'slots',jsonb_build_array((test_input->'slots'->0)||jsonb_build_object('start_time','14:00','end_time','15:00'))));exception when others then rejected:=true;end;
 if not rejected or exists(select 1 from public.academic_routines where id=replacement_id and retired_at is not null) or not exists(select 1 from public.class_sessions where routine_id=replacement_id and session_date>=day+7 and status='SCHEDULED') then raise exception 'Failed replacement changed the old routine/classes';end if;
 drop trigger test_replacement_failure on public.class_sessions;

 perform public.weekly_timetable_save(test_input);
 if not exists(select 1 from public.academic_routines where id=replacement_id and retired_at is not null) or exists(select 1 from public.class_sessions where routine_id=replacement_id and session_date>=day+7 and status='SCHEDULED') or not exists(select 1 from public.class_sessions where routine_id=replacement_id and session_date=day and status='SCHEDULED') then raise exception 'Future replacement failed to preserve history/cancel old future classes';end if;
 if exists(select 1 from public.class_sessions where batch_id=batch and curriculum_version_id is distinct from plan_id) then raise exception 'Replacement lost topic plan';end if;
 select id into student from public.subjects where id<>subject and is_active limit 1;
 rejected:=false;begin perform public.academic_schedule_command(jsonb_build_object('action','ROUTINE','batch_id',batch,'subject_id',student,'teacher_id',teacher,'room_id',room,'days',jsonb_build_array(extract(dow from day)::int),'start_time','16:00','end_time','17:00','starts_on',day,'ends_on',day+35,'request_id',gen_random_uuid(),'reason','Reject legacy routine subject outside programme'));exception when others then rejected:=true;end;if not rejected then raise exception 'Legacy routine bypassed programme subjects';end if;
 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 rejected:=false;begin perform public.weekly_timetable_preview(test_input);exception when others then rejected:=true;end;if not rejected then raise exception 'Teacher permitted to preview admin planning';end if;
 rejected:=false;begin perform public.weekly_timetable_save(test_input);exception when others then rejected:=true;end;if not rejected then raise exception 'Teacher permitted to save admin planning';end if;
end $test$;
rollback;
