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
 perform public.academic_planning_command(jsonb_build_object('action','QUALIFICATION','teacher_id',teacher,'subject_id',subject,'starts_on',y.starts_on,'request_id',gen_random_uuid(),'reason','Verified teacher subject qualification'));
 if (public.academic_planning_workspace('qualifications')->>'total')::integer<>1 then raise exception 'Teaching qualification not visible in setup';end if;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',y.id,'class_id',class_id,'program_id',program,'code','ACADEMIC_FLOW_TEST','reason','Create academic workflow fixture'));offering:=(result->>'offering_id')::uuid;
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Prepare academic test fee','components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',1000,'charge_type','TUITION','recurrence','PER_CYCLE'))));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'code','ACADEMIC_BATCH','name','Academic batch','capacity',12,'reason','Prepare fixture teaching batch'));batch:=(result->>'id')::uuid;
 perform public.academic_planning_command(jsonb_build_object('action','OFFERING_PLAN','id',offering,'operation_kind','COACHING','starts_on',y.starts_on,'ends_on',y.ends_on,'days','[0,1,2,3,4,5,6]'::jsonb,'request_id',gen_random_uuid(),'reason','Confirmed programme days and dates'));
 result:=public.academic_planning_command(jsonb_build_object('action','ROOM','branch_id',branch,'name','Academic test room','capacity',12,'request_id',gen_random_uuid(),'reason','Confirmed actual classroom seats'));room:=(result->>'id')::uuid;

 for i in 0..6 loop
  perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','TEACHER','resource_id',teacher,'weekday',i,'start_time','00:00','end_time','23:59','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed fixture teacher availability'));
  perform public.academic_planning_command(jsonb_build_object('action','AVAILABILITY','resource_kind','ROOM','resource_id',room,'weekday',i,'start_time','00:00','end_time','23:59','starts_on',y.starts_on,'ends_on',y.ends_on,'request_id',gen_random_uuid(),'reason','Confirmed fixture classroom availability'));
 end loop;
 insert into public.class_sessions(batch_id,subject_id,teacher_id,room_id,planned_scope,session_date,starts_at,ends_at,created_by) values(batch,subject,teacher,room,'Guided class scope',today,(today+'00:00'::time) at time zone 'Asia/Dhaka',(today+'23:59'::time) at time zone 'Asia/Dhaka',admin) returning id into session;
 insert into public.class_sessions(batch_id,subject_id,teacher_id,room_id,planned_scope,session_date,starts_at,ends_at,created_by) values(batch,subject,teacher,room,'Tomorrow test practice',today+1,((today+1)+'08:00'::time) at time zone 'Asia/Dhaka',((today+1)+'09:00'::time) at time zone 'Asia/Dhaka',admin) returning id into past_session;
 insert into public.students(organization_id,student_no,full_name,status,created_by) values((select organization_id from public.batches where id=batch),'SA-GUIDED-TEST','Guided roster student','ACTIVE',admin) returning id into student;
 insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,admission_date,status,created_by) values(student,(select organization_id from public.batches where id=batch),branch,y.id,class_id,program,batch,today,'ACTIVE',admin) returning id into enrollment;
 insert into public.academic_assessments(batch_id,subject_id,title,assessment_date,max_marks,status,author_id,published_at) values(batch,subject,'Tomorrow planned exam',today+1,100,'PUBLISHED',admin,now()) returning id into approval;
 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 payload:=jsonb_build_object('action','START','session_id',session,'request_id',gen_random_uuid(),'reason','Starting my assigned class');
 result:=public.teacher_class_command(payload);perform public.teacher_class_command(payload);
 if(select count(*) from public.class_teaching_clocks where session_id=session)<>1 then raise exception 'Clock retry duplicated';end if;
 if(public.teacher_class_workspace(session)->'clock'->>'session_id')::uuid<>session then raise exception 'Reload lost clock';end if;
 if not exists(select 1 from jsonb_array_elements(public.teacher_class_workspace(session)->'reminders')r where r->>'kind'='EXAM') then raise exception 'Published exam reminder missing';end if;
 perform public.class_question_document_command(jsonb_build_object('action','SAVE','session_id',past_session,'topic','Ordinary class practice','draft_url','https://docs.google.com/document/d/ordinaryClass123/edit','request_id',gen_random_uuid()));
 if exists(select 1 from jsonb_array_elements(public.teacher_class_workspace(session)->'reminders')r where r->>'kind'='EXAM' and r->'document'<>'null'::jsonb) then raise exception 'Ordinary questions incorrectly satisfied exam';end if;
 payload:=jsonb_build_object('action','SAVE','session_id',past_session,'assessment_id',approval,'topic','Tomorrow exam answers and questions','draft_url','https://docs.google.com/document/d/examDraft123/edit','request_id',gen_random_uuid());
 result:=public.teacher_class_question_command(payload);rid:=(result->>'id')::uuid;perform public.teacher_class_question_command(payload);
 if(select count(*) from public.class_question_documents where assessment_id=approval)<>1 then raise exception 'Exam retry duplicated';end if;
 perform public.teacher_class_question_command(jsonb_build_object('action','SUBMIT','id',rid,'request_id',gen_random_uuid()));
 if not exists(select 1 from jsonb_array_elements(public.teacher_class_workspace(session)->'reminders')r where r->>'kind'='EXAM' and r->'document'->>'status'='SUBMITTED') then raise exception 'Exam review status not shown';end if;

 rejected:=false;begin perform public.teacher_class_command(jsonb_build_object('action','START','reason','Try future class start','session_id',past_session,'request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected then raise exception 'Future class started';end if;
 -- Simulate time elapsed between separate HTTP Start and Finish transactions.
 update public.class_teaching_clocks set started_at=now()-interval '1 minute' where session_id=session;
 perform public.teacher_class_command(jsonb_build_object('action','END','session_id',session,'request_id',gen_random_uuid(),'reason','Finished actual teaching now'));
 if not exists(select 1 from public.class_teaching_clocks where session_id=session and ended_at is not null) then raise exception 'Finish not persisted';end if;
 perform public.teacher_class_command(jsonb_build_object('action','CORRECT_CLOCK','session_id',session,'request_id',gen_random_uuid(),'reason','Corrected actual forty minute teaching','started_at',now()-interval '45 minutes','ended_at',now()-interval '5 minutes'));
 if not exists(select 1 from public.class_teaching_clocks where session_id=session and ended_at-started_at=interval '40 minutes') then raise exception 'Corrected clock duration wrong';end if;

 rejected:=false;begin perform public.teacher_class_command(jsonb_build_object('action','SUBMIT_REPORT','session_id',session,'request_id',gen_random_uuid(),'reason','Submit without student attendance','class_summary','Completed class topic'));exception when others then rejected:=true;end;
 if not rejected or exists(select 1 from public.class_logs where session_id=session) then raise exception 'Missing attendance bypassed or partial report saved';end if;
 result:=public.academic_command(jsonb_build_object('action','SAVE_ATTENDANCE','session_id',session,'request_id',gen_random_uuid(),'reason','Recorded student attendance','entries',jsonb_build_array(jsonb_build_object('enrollment_id',enrollment,'status','PRESENT','note',''))));attendance:=(result->>'id')::uuid;
 payload:=jsonb_build_object('action','SUBMIT_REPORT','session_id',session,'request_id',gen_random_uuid(),'reason','Reviewed student attendance and teaching','class_summary','Completed class topic','unit_progress','[]'::jsonb);
 perform public.teacher_class_command(payload);perform public.teacher_class_command(payload);
 if not exists(select 1 from public.attendance_submissions where id=attendance and status='SUBMITTED') or not exists(select 1 from public.class_logs where session_id=session and status='SUBMITTED') then raise exception 'Combined submission incomplete';end if;
 if public.verified_teaching_hours(session)<>0 then raise exception 'Unreviewed clock paid';end if;
 rejected:=false;begin perform public.teacher_class_command(jsonb_build_object('action','CORRECT_CLOCK','session_id',session,'request_id',gen_random_uuid(),'reason','Try rewriting submitted timing','started_at',now()-interval '2 minutes','ended_at',now()-interval '1 minute'));exception when others then rejected:=true;end;if not rejected then raise exception 'Submitted timing rewritten';end if;
 perform set_config('request.jwt.claim.sub','',true);
 rejected:=false;begin perform public.teacher_class_workspace(session);exception when others then rejected:=true;end;if not rejected then raise exception 'Anonymous clock access';end if;
 if has_table_privilege('authenticated','public.class_teaching_clocks','INSERT') then raise exception 'Direct timer insert allowed';end if;
end $test$;
rollback;
