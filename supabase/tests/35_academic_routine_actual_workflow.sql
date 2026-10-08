begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
('98000000-0000-0000-0000-000000000001','academic-admin@example.test',now(),'{"full_name":"Academic Admin"}'),
('98000000-0000-0000-0000-000000000002','academic-teacher@example.test',now(),'{"full_name":"Academic Teacher"}');
select public.bootstrap_admin('academic-admin@example.test','Academic Admin');
select set_config('request.jwt.claim.sub','',true);
select public.request_staff_access('{"full_name":"Academic Teacher","email":"academic-teacher@example.test","mobile":"01712345678","requested_role":"TEACHER","purpose":"Teach academic classes"}');
select set_config('request.jwt.claim.sub','98000000-0000-0000-0000-000000000001',true);
do $test$
declare rid uuid;teacher uuid;branch uuid;y public.academic_years;class_id uuid;program uuid;subject uuid;offering uuid;batch uuid;room uuid;routine uuid;session uuid;replaced uuid;past_session uuid;log_id uuid;student uuid;enrollment uuid;attendance uuid;approval uuid;day date;past date;today date:=(now() at time zone 'Asia/Dhaka')::date;w jsonb;result jsonb;payload jsonb;rejected boolean;i int;teacher_profile uuid:='98000000-0000-0000-0000-000000000002';admin uuid:=auth.uid();begin
 select id into rid from public.staff_access_requests where email='academic-teacher@example.test';
 perform public.review_staff_access(jsonb_build_object('id',rid,'action','VERIFY','assigned_role','TEACHER','reason','Verified actual teacher identity'));
 perform public.review_staff_access(jsonb_build_object('id',rid,'action','COMPLETE_INVITATION','reason','Verified teacher account activated'));
 select id into teacher from public.staff where profile_id=teacher_profile;
 select * into y from public.academic_years where today between starts_on and ends_on limit 1;
 select id into branch from public.branches where is_active limit 1;select id into class_id from public.classes where is_active limit 1;select id into program from public.programs where is_active limit 1;select id into subject from public.subjects where is_active limit 1;
 update public.staff_role_assignments set effective_from=y.starts_on where staff_id=teacher;
 insert into public.staff_subject_assignments(staff_id,subject_id,effective_from,assigned_by) values(teacher,subject,y.starts_on,admin);
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',y.id,'class_id',class_id,'program_id',program,'code','ACADEMIC_FLOW_TEST','reason','Create academic workflow fixture'));offering:=(result->>'offering_id')::uuid;
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Prepare academic test fee','components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',1000,'charge_type','TUITION','recurrence','PER_CYCLE'))));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'code','ACADEMIC_BATCH','name','Academic batch','capacity',12,'reason','Prepare fixture teaching batch'));batch:=(result->>'id')::uuid;
 perform public.academic_planning_command(jsonb_build_object('action','OFFERING_PLAN','id',offering,'operation_kind','COACHING','starts_on',y.starts_on,'ends_on',y.ends_on,'days','[0,1,2,3,4,5,6]'::jsonb,'request_id',gen_random_uuid(),'reason','Confirmed programme days and dates'));
 result:=public.academic_planning_command(jsonb_build_object('action','ROOM','branch_id',branch,'name','Academic test room','capacity',12,'request_id',gen_random_uuid(),'reason','Confirmed actual classroom seats'));room:=(result->>'id')::uuid;
 day:=today+1;past:=today-1;
 for i in 0..6 loop
  perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','TEACHER','resource_id',teacher,'weekday',i,'start_time','08:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed teacher weekly availability'));
  if i=extract(dow from day) then
   perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','ROOM','resource_id',room,'weekday',i,'start_time','08:00','end_time','09:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed first adjacent room window'));
   perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','ROOM','resource_id',room,'weekday',i,'start_time','09:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed second adjacent room window'));
  else perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','ROOM','resource_id',room,'weekday',i,'start_time','08:00','end_time','10:00','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed room weekly availability'));end if;
 end loop;
 perform public.check_academic_slot(batch,subject,teacher,room,day,'08:00','10:00');
 rejected:=false;begin perform public.check_academic_slot(batch,subject,teacher,room,day,'07:00','09:00');exception when others then rejected:=true;end;if not rejected then raise exception 'Uncovered availability accepted.';end if;
 perform public.academic_planning_command(jsonb_build_object('action','CLOSURE','resource_kind','ACADEMY','starts_on',day+7,'ends_on',day+7,'name','Academy holiday','request_id',gen_random_uuid(),'reason','Confirmed academy holiday'));
 payload:=jsonb_build_object('action','ROUTINE','batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'days',jsonb_build_array(extract(dow from day)::int),'start_time','08:00','end_time','10:00','starts_on',day,'ends_on',day+7,'request_id',gen_random_uuid(),'reason','Confirmed two-hour weekly teaching slot');
 result:=public.academic_schedule_command(payload);routine:=(result->>'id')::uuid;perform public.academic_schedule_command(payload);
 if(select count(*) from public.academic_routines where batch_id=batch)<>1 then raise exception 'Routine retry duplicated.';end if;
 payload:=jsonb_build_object('action','GENERATE','routine_id',routine,'starts_on',day,'ends_on',day+7,'planned_scope','Academic weekly practice','request_id',gen_random_uuid(),'reason','Generate agreed dated classes');result:=public.academic_schedule_command(payload);perform public.academic_schedule_command(payload);
 if(select count(*) from public.class_sessions where batch_id=batch)<>1 then raise exception 'Holiday generation/duplicate prevention failed.';end if;
 session:=(result->>'id')::uuid;
 rejected:=false;begin perform public.academic_schedule_command(jsonb_build_object('action','CREATE_SESSION','batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'starts_on',day,'start_time','09:00','end_time','10:00','planned_scope','Conflicting class','request_id',gen_random_uuid(),'reason','Reject duplicate resource booking'));exception when others then rejected:=true;end;if not rejected then raise exception 'Resource double booking accepted.';end if;
 rejected:=false;begin perform public.academic_planning_command(jsonb_build_object('action','ROOM','id',room,'branch_id',branch,'name','Academic test room','capacity',10,'is_active',true,'request_id',gen_random_uuid(),'reason','Reject insufficient scheduled classroom'));exception when others then rejected:=true;end;if not rejected then raise exception 'Scheduled classroom capacity reduction accepted.';end if;
 result:=public.academic_schedule_command(jsonb_build_object('action','ROOM_CHANGE','session_id',session,'starts_on',day,'start_time','08:00','end_time','10:00','room_id',room,'request_id',gen_random_uuid(),'reason','Replace occurrence while preserving routine'));replaced:=(result->>'id')::uuid;
 if not exists(select 1 from public.class_sessions where id=replaced and replacement_for_id=session) or not exists(select 1 from public.class_sessions where id=session and status='CANCELLED') then raise exception 'Linked replacement did not preserve original.';end if;
 perform public.academic_schedule_command(jsonb_build_object('action','CREATE_SESSION','batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'starts_on',past,'start_time','08:00','end_time','10:00','planned_scope','Actual teaching practice','request_id',gen_random_uuid(),'reason','Record already held fixture class'));
 select id into past_session from public.class_sessions where batch_id=batch and session_date=past;
 insert into public.students(organization_id,branch_id,full_name,created_by) values((select organization_id from public.batches where id=batch),branch,'Academic roster student',admin) returning id into student;
 insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,admission_date,status,created_by) values(student,(select organization_id from public.batches where id=batch),branch,y.id,class_id,program,batch,past,'ACTIVE',admin) returning id into enrollment;
 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 result:=public.academic_command(jsonb_build_object('action','SAVE_ATTENDANCE','session_id',past_session,'request_id',gen_random_uuid(),'reason','Recorded student attendance','entries',jsonb_build_array(jsonb_build_object('enrollment_id',enrollment,'status','PRESENT','note',''))));attendance:=(result->>'id')::uuid;
 perform public.academic_command(jsonb_build_object('action','SUBMIT_ATTENDANCE','session_id',past_session,'attendance_id',attendance,'request_id',gen_random_uuid(),'reason','Submitted student attendance'));

 payload:=jsonb_build_object('action','SAVE_DRAFT','session_id',past_session,'request_id',gen_random_uuid(),'reason','Recorded real teacher work','actual_starts_at',(past+'08:15'::time) at time zone 'Asia/Dhaka','actual_ends_at',(past+'09:45'::time) at time zone 'Asia/Dhaka','class_summary','Taught and practiced topic','unit_progress','[]'::jsonb);
 result:=public.class_log_command(payload);log_id:=(result->>'id')::uuid;perform public.class_log_command(payload);
 perform public.class_log_command(jsonb_build_object('action','SUBMIT','session_id',past_session,'request_id',gen_random_uuid(),'reason','Submit saved teaching evidence'));
 rejected:=false;begin perform public.class_log_command(jsonb_build_object('action','DECIDE','session_id',past_session,'class_log_id',log_id,'decision','APPROVED','review_note','Try approving own class','request_id',gen_random_uuid(),'reason','Reject self review'));exception when others then rejected:=true;end;if not rejected then raise exception 'Teacher self review accepted.';end if;
 rejected:=false;begin perform public.academic_planning_workspace('rooms');exception when others then rejected:=true;end;if not rejected then raise exception 'Teacher accessed planning management.';end if;
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform public.class_log_command(jsonb_build_object('action','DECIDE','session_id',past_session,'class_log_id',log_id,'decision','APPROVED','review_note','Verified real actual teaching duration','request_id',gen_random_uuid(),'reason','Reviewed submitted actual teaching'));
 if not exists(select 1 from public.class_logs where id=log_id and status='APPROVED' and extract(epoch from(actual_ends_at-actual_starts_at))/3600=1.5) then raise exception 'Actual teaching duration/review failed.';end if;
 if public.verified_teaching_hours(past_session)<>0 then raise exception 'Unapproved student attendance counted as verified workload.';end if;
 select approval_id into approval from public.attendance_submissions where id=attendance;
 perform public.academic_command(jsonb_build_object('action','DECIDE_ATTENDANCE','approval_id',approval,'decision','APPROVED','request_id',gen_random_uuid(),'reason','Reviewed saved student attendance'));
 if public.verified_teaching_hours(past_session)<>1.5 then raise exception 'Approved actual hours not used as workload.';end if;

 rejected:=false;begin perform public.academic_schedule_command(jsonb_build_object('action','CANCEL','session_id',past_session,'request_id',gen_random_uuid(),'reason','Reject cancellation of approved teaching'));exception when others then rejected:=true;end;if not rejected then raise exception 'Approved evidence silently cancelled.';end if;
 if (public.academic_calendar(today,today+7)->>'total')::int<>2 then raise exception 'Calendar did not retain original/replacement.';end if;
 if has_table_privilege('authenticated','public.academic_availability','INSERT') or has_function_privilege('anon','public.academic_schedule_command(jsonb)','EXECUTE') then raise exception 'Academic write boundary exposed.';end if;
end $test$;
rollback;
