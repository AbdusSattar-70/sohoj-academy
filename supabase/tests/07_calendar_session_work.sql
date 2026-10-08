-- Isolated end-to-end academic lifecycle; no live email or persisted test records.
begin;
insert into auth.users(id,email,email_confirmed_at) values('10000000-0000-4000-8000-000000000071','academic-admin@example.test',now()),('10000000-0000-4000-8000-000000000072','academic-teacher@example.test',now());
select public.initialize_academy('academic-admin@example.test','Academic Test Admin');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000071',true);
select set_config('request.headers',jsonb_build_object('x-sohoj-workspace',(select id from public.operating_divisions where code='TRAINING'))::text,true);
do $$ declare aid uuid; programme uuid; subject uuid; run uuid; batch uuid; batch2 uuid; room uuid; teacher uuid; student uuid; session uuid; routine uuid; placement uuid; teacher_profile uuid:='10000000-0000-4000-8000-000000000072'; revision_value int; result jsonb; input jsonb; request uuid; today date:=(now() at time zone 'Asia/Dhaka')::date; teaching_day date:=today-1; from_day date:=today+7; through_day date:=today+14;
begin
 select id into aid from public.academies;
 select id into programme from public.programmes where academy_id=aid limit 1;
 select id into subject from public.directory_entries where academy_id=aid and kind='SUBJECT' and is_active limit 1;
 insert into public.programme_runs(academy_id,division_id,campus_id,programme_id,code,title,starts_on,ends_on,guardian_rule) select aid,(select id from public.operating_divisions where academy_id=aid and code='TRAINING'),(select id from public.campuses where academy_id=aid limit 1),programme,'ACADEMIC_TEST','Academic lifecycle fixture',today-60,today+120,'OPTIONAL' returning id into run;
 insert into public.run_subjects values(run,subject,aid,true);
 insert into public.teaching_batches(academy_id,run_id,code,name,capacity) values(aid,run,'TEST_A','Fixture A',12) returning id into batch;
 insert into public.teaching_batches(academy_id,run_id,code,name,capacity) values(aid,run,'TEST_B','Fixture B',12) returning id into batch2;
 insert into public.academic_rooms(academy_id,name,capacity) values(aid,'Fixture classroom',12) returning id into room;
 insert into public.people(academy_id,full_name) values(aid,'Fixture teacher') returning id into teacher;
 insert into public.person_responsibilities values(teacher,aid,'TEACHER',true);
 insert into public.account_profiles(id,academy_id,display_name) values(teacher_profile,aid,'Fixture teacher');
 insert into public.account_roles values(teacher_profile,'TEACHER');
 insert into public.account_workspaces select teacher_profile,id from public.operating_divisions where academy_id=aid and code='TRAINING';
 insert into public.person_accounts values(teacher_profile,teacher,aid);
 insert into public.teacher_subject_qualifications values(aid,teacher,subject,true,1);
 result:=public.academic_operation_choices('SESSION');
 if not exists(select 1 from jsonb_array_elements(result->'teachers') item where item->>'id'=teacher::text and item->>'name' like '%SA-STF-%') then raise exception 'Teacher selector lacks permanent ID'; end if;
 if has_function_privilege('authenticated','public.teacher_resource_name(uuid)','EXECUTE') then raise exception 'Internal name helper exposed'; end if;

 insert into public.people(academy_id,full_name) values(aid,'Fixture student') returning id into student;
 insert into public.person_responsibilities values(student,aid,'STUDENT',true);
 result:=public.change_student_batch(gen_random_uuid(),jsonb_build_object('action','ENROLL','personId',student,'batchId',batch,'fromDate',teaching_day,'reason','Verified fixture enrollment'));
 placement:=(result->>'id')::uuid;
 result:=public.academic_command(gen_random_uuid(),jsonb_build_object('action','CREATE','batchId',batch,'subjectId',subject,'teacherId',teacher,'roomId',room,'start',(teaching_day+time '07:00') at time zone 'Asia/Dhaka','end',(teaching_day+time '09:00') at time zone 'Asia/Dhaka','confirmAvailability',true,'reason','Fixture teaching session scheduled'));
 session:=(result->>'id')::uuid;revision_value:=(result->>'revision')::int;
 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 result:=public.academic_session_work(session);
 if not(result->>'canEdit')::boolean or jsonb_array_length(result->'roster')<>1 then raise exception 'Teacher dated roster missing'; end if;
 begin
  perform public.save_academic_session_work(gen_random_uuid(),jsonb_build_object('action','SUBMIT','id',session,'revision',revision_value,'attendance','[]'::jsonb,'report','Physics fixture taught','actualStart',(teaching_day+time '07:00') at time zone 'Asia/Dhaka','actualEnd',(teaching_day+time '08:30') at time zone 'Asia/Dhaka','reason','Completed teaching fixture'));
  raise exception 'Incomplete attendance unexpectedly submitted';
 exception when others then if sqlerrm<>'Record attendance for every enrolled student before submitting.' then raise; end if; end;
 input:=jsonb_build_object('action','SUBMIT','id',session,'revision',revision_value,'attendance',jsonb_build_array(jsonb_build_object('personId',student,'status','PRESENT')),'report','Physics fixture taught','homework','Practice exercise 1','assessmentKind','QUIZ','assessmentNote','Oral quiz completed','actualStart',(teaching_day+time '07:00') at time zone 'Asia/Dhaka','actualEnd',(teaching_day+time '08:30') at time zone 'Asia/Dhaka','reason','Completed teaching fixture');
 request:=gen_random_uuid();result:=public.save_academic_session_work(request,input);perform public.save_academic_session_work(request,input);
 revision_value:=(result->>'revision')::int;
 if public.academic_teaching_summary(teaching_day::text,today::text)<>'[]'::jsonb then raise exception 'Unapproved hours counted'; end if;
 begin
  perform public.academic_command(gen_random_uuid(),jsonb_build_object('action','APPROVE','id',session,'revision',revision_value,'reason','Teacher self approval fixture'));
  raise exception 'Teacher self approval allowed';
 exception when others then if sqlerrm='Teacher self approval allowed' then raise; end if; end;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000071',true);
 perform public.academic_command(gen_random_uuid(),jsonb_build_object('action','APPROVE','id',session,'revision',revision_value,'reason','Independently checked attendance and teaching'));
 result:=public.academic_teaching_summary(teaching_day::text,today::text);
 if (result->0->>'approved_hours')::numeric<>1.5 then raise exception 'Approved actual hours incorrect'; end if;
 perform public.change_student_batch(gen_random_uuid(),jsonb_build_object('action','TRANSFER','personId',student,'batchId',batch2,'fromDate',today,'revision',1,'reason','Verified fixture batch transfer'));
 if jsonb_array_length(public.academic_batch_roster(batch,teaching_day::text))<>1 or public.academic_batch_roster(batch,today::text)<>'[]'::jsonb or jsonb_array_length(public.academic_batch_roster(batch2,today::text))<>1 then raise exception 'Transfer rewrote historical roster'; end if;
 result:=public.academic_command(gen_random_uuid(),jsonb_build_object('action','ROUTINE','batchId',batch2,'subjectId',subject,'teacherId',teacher,'roomId',room,'startsOn',from_day,'endsOn',through_day,'weekdays',jsonb_build_array(extract(dow from from_day)::int),'startTime','07:00','endTime','09:00','confirmAvailability',true,'reason','Confirmed fixture recurring classes'));
 routine:=(result->>'id')::uuid;
 result:=public.academic_calendar(from_day::text,through_day::text,1,'');
 if (result->>'total')::int<>2 then raise exception 'Calendar missing recurring sessions'; end if;
 result:=public.manage_academic_routine(gen_random_uuid(),jsonb_build_object('action','CONTINUE','id',routine,'revision',1,'startsOn',through_day+1,'endsOn',through_day+8,'reason','Confirmed next routine period'));
 if (select is_active from public.academic_routines where id=routine) then raise exception 'Continuation can be generated twice'; end if;
 routine:=(result->>'id')::uuid;
 begin
  perform public.manage_academic_routine(gen_random_uuid(),jsonb_build_object('action','REPLACE','id',routine,'revision',1,'startsOn',through_day+1,'endsOn',through_day+8,'teacherId',gen_random_uuid(),'roomId',room,'weekdays',jsonb_build_array(extract(dow from from_day)::int),'startTime','09:00','endTime','10:00','confirmAvailability',true,'confirmReplacement',true,'reason','Failed replacement fixture'));
  raise exception 'Invalid replacement accepted';
 exception when others then if sqlerrm='Invalid replacement accepted' then raise; end if; end;
 if not(select is_active from public.academic_routines where id=routine) or not exists(select 1 from public.academic_sessions where routine_id=routine and status='SCHEDULED') then raise exception 'Failed replacement lost old schedule'; end if;
 result:=public.manage_academic_routine(gen_random_uuid(),jsonb_build_object('action','REPLACE','id',routine,'revision',1,'startsOn',through_day+1,'endsOn',through_day+8,'teacherId',teacher,'roomId',room,'weekdays',jsonb_build_array(extract(dow from from_day)::int),'startTime','09:00','endTime','10:00','confirmAvailability',true,'confirmReplacement',true,'reason','Confirmed replacement fixture'));
 if (result->>'replaced')::int<>1 or (select status from public.academic_sessions where id=session)<>'APPROVED' then raise exception 'Replacement changed past teaching history'; end if;

 result:=public.save_academic_plan(gen_random_uuid(),jsonb_build_object('target','RUN','id',run,'revision',1,'weekdays',jsonb_build_array(0,2,4),'reason','Confirmed offering default days'));
 if result->'default_weekdays'<>jsonb_build_array(0,2,4) then raise exception 'Default teaching days lost'; end if;
 result:=public.save_academic_plan(gen_random_uuid(),jsonb_build_object('target','BATCH','id',batch2,'revision',1,'slots',jsonb_build_array(jsonb_build_object('weekday',0,'start','07:00','end','09:00'),jsonb_build_object('weekday',2,'start','08:00','end','10:00')),'reason','Confirmed weekday batch times'));
 if jsonb_array_length(result->'planned_slots')<>2 then raise exception 'Day specific batch times lost'; end if;
 perform public.save_academic_windows(gen_random_uuid(),jsonb_build_object('kind','ROOM','resourceId',room,'weekdays',jsonb_build_array(0,1,2,3,4,5,6),'startTime','06:00','endTime','12:00','active',true,'reason','Confirmed full week room availability'));
 if (select count(distinct weekday) from public.academic_resource_windows where resource_id=room and is_active)<>7 then raise exception 'Multiple weekdays not saved'; end if;

 perform set_config('request.jwt.claim.sub',teacher_profile::text,true);
 begin
  perform public.save_academic_session_work(gen_random_uuid(),input||jsonb_build_object('revision',revision_value+1));
  raise exception 'Approved work edited';
 exception when others then if sqlerrm<>'Only the assigned teacher can edit this open class.' then raise; end if; end;
 if has_table_privilege('authenticated','public.academic_session_attendance','INSERT') then raise exception 'Client attendance write exposed'; end if;
end $$;
rollback;
