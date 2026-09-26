-- Development-only fixtures, entirely rolled back. Run as database owner.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); org uuid; cl uuid; program uuid; branch uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; a uuid; a2 uuid; fee uuid; method uuid;
 result jsonb; input jsonb; today date; baseline jsonb;
 reviewer uuid:=gen_random_uuid();teacher_user uuid:=gen_random_uuid();other_user uuid:=gen_random_uuid();teacher uuid;other_teacher uuid;subject uuid;room uuid;routine uuid;session uuid;curriculum uuid;draft uuid;approval uuid;roster jsonb;enrollment uuid;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,'admission-test-'||u||'@example.invalid','{"full_name":"Admission Test"}');
 perform public.bootstrap_admin('admission-test-'||u||'@example.invalid','Admission Test');
 perform set_config('request.jwt.claim.sub',u::text,true);
 select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org and code='CLASS_10';
 select id into program from public.programs where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active) values(org,'TEST-'||u::text,today,today+365,false) returning id into yr;
 baseline:='{"requires_admission_acceptance":true,"requires_initial_billing_posted":true,"payment_requirement":"NONE","minimum_payment_percent":0,"allow_credit_enrollment":true,"count_student_active_only_when_enrollment_active":true}'::jsonb;
 if (select payload from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE')<>baseline then
   perform public.publish_business_rule_version('admissions','activation_policy',baseline,'Establish isolated test baseline');
 end if;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',yr,'class_id',cl,'program_id',program,'code','TEST-'||left(u::text,8),'name','Test Offering','reason','Admission verification'));
 offering:=(result->>'offering_id')::uuid;
 result:=public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Verification standard fees','components',
 '[{"code":"TUITION","name":"Tuition","amount":2500,"charge_type":"TUITION","recurrence":"PER_CYCLE"},{"code":"ADMISSION","name":"Admission","amount":100,"charge_type":"ADMISSION","recurrence":"ONE_TIME"}]'::jsonb));
 fee:=(result->>'fee_plan_version_id')::uuid;
 input:=jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'reason','Create verification batch','offering_id',offering,'code','TEST-'||left(u::text,8),'name','Verification Batch','capacity',1);
 result:=public.admission_command(input); batch:=(result->>'id')::uuid;
 if public.admission_command(input)<>result then raise exception 'Batch retry was not idempotent.'; end if;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id) values(org,'Mock Admission Student '||u::text,'Mock Guardian','01700000991',cl) returning id into prospect;
 input:=jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'reason','Create verification admission','prospect_id',prospect,'batch_id',batch);
 result:=public.admission_command(input); a:=(result->>'id')::uuid;
 if public.admission_command(input)<>result then raise exception 'Admission retry was not idempotent.'; end if;
 begin
  perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'reason','Attempt invalid state','admission_id',a));
  raise exception 'Invalid state was accepted';
 exception when others then if sqlerrm not like '%not allowed%' then raise; end if; end;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'reason','Verify identity and fees','admission_id',a));
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),'reason','Accept reviewed admission','admission_id',a));
 if exists(select 1 from public.enrollments e join public.admission_cases ac on ac.student_id=e.student_id where ac.id=a) then raise exception 'Acceptance activated enrollment early.'; end if;
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'reason','Post standard initial billing','admission_id',a));
 if (select total from public.admission_invoices where admission_id=a)<>2600 then raise exception 'Inherited billing total is wrong.'; end if;
 if exists(select 1 from public.admission_payments where student_id=(select student_id from public.admission_cases where id=a)) then raise exception 'Billing fabricated a payment.'; end if;
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'reason','Evaluate admission policy','admission_id',a));
 if (select status from public.admission_cases where id=a)<>'ACTIVE_ENROLLMENT' then raise exception 'Default credit policy did not activate.'; end if;
 select id into method from public.payment_methods where is_active limit 1;

 insert into auth.users(id,email,raw_user_meta_data) values(reviewer,'academic-reviewer-'||reviewer||'@example.invalid','{"full_name":"Academic Reviewer"}'),(teacher_user,'academic-teacher-'||teacher_user||'@example.invalid','{"full_name":"Assigned Teacher"}'),(other_user,'academic-other-'||other_user||'@example.invalid','{"full_name":"Other Teacher"}');
 perform public.bootstrap_admin('academic-reviewer-'||reviewer||'@example.invalid','Academic Reviewer');
 insert into public.profiles(id,display_name) values(teacher_user,'Assigned Teacher'),(other_user,'Other Teacher') on conflict(id) do nothing;
 insert into public.staff(profile_id,branch_id,full_name,status) values(teacher_user,branch,'Assigned Teacher','ACTIVE') returning id into teacher;
 insert into public.staff(profile_id,branch_id,full_name,status) values(other_user,branch,'Other Teacher','ACTIVE') returning id into other_teacher;
 insert into public.staff_role_assignments(staff_id,staff_role_id,effective_from,is_primary) select teacher,id,least(today,current_date),true from public.staff_roles where is_teaching_role limit 1;
 insert into public.staff_role_assignments(staff_id,staff_role_id,effective_from,is_primary) select other_teacher,id,least(today,current_date),true from public.staff_roles where is_teaching_role limit 1;
 select id into subject from public.subjects where organization_id=org and is_active limit 1;
 insert into public.staff_subject_assignments(staff_id,subject_id,effective_from) values(teacher,subject,today),(other_teacher,subject,today);
 insert into public.user_role_assignments(profile_id,role_id) select teacher_user,id from public.system_roles where code='TEACHER';
 insert into public.user_role_assignments(profile_id,role_id) select other_user,id from public.system_roles where code='TEACHER';
 result:=public.academic_command(jsonb_build_object('action','CREATE_ROOM','request_id',gen_random_uuid(),'branch_id',branch,'name','TEST-'||u,'capacity',12,'reason','Configure verification classroom'));
 room:=(result->>'id')::uuid;
 input:=jsonb_build_object('action','PUBLISH_CURRICULUM','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'title','Verification curriculum','units',jsonb_build_array(jsonb_build_object('title','Chapter 1 pages 1–10','target_date',today+30)),'reason','Publish reviewed curriculum plan');
 result:=public.academic_command(input);curriculum:=(result->>'id')::uuid;
 if public.academic_command(input)<>result then raise exception 'Curriculum retry created duplicate';end if;
 input:=jsonb_build_object('action','CREATE_ROUTINE','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'weekday',extract(dow from today),'start_time','00:00','end_time','00:01','starts_on',today,'ends_on',today+30,'reason','Create qualified weekly routine');
 result:=public.academic_command(input);routine:=(result->>'id')::uuid;
 begin
  perform public.academic_command(input||jsonb_build_object('request_id',gen_random_uuid()));raise exception 'Overlapping routine accepted';
 exception when others then if sqlerrm not like '%conflicts%' then raise;end if;end;
 input:=jsonb_build_object('action','GENERATE_SESSIONS','request_id',gen_random_uuid(),'routine_id',routine,'starts_on',today,'ends_on',today+7,'curriculum_id',curriculum,'planned_scope','Chapter 1 introduction','reason','Generate actual dated occurrences');
 result:=public.academic_command(input);
 if public.academic_command(input)<>result then raise exception 'Generation retry duplicated';end if;
 perform public.academic_command(input||jsonb_build_object('request_id',gen_random_uuid()));
 if (select count(*) from public.class_sessions where routine_id=routine)<>2 then raise exception 'Routine dates duplicated';end if;
 select id into session from public.class_sessions where routine_id=routine and session_date=today;
 if (select curriculum_version_id from public.class_sessions where id=session)<>curriculum then raise exception 'Curriculum not pinned';end if;
 -- Revisions do not rewrite sessions already linked to the earlier curriculum.
 perform public.academic_command(jsonb_build_object('action','PUBLISH_CURRICULUM','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'title','Revised curriculum','units',jsonb_build_array(jsonb_build_object('title','Chapter 2','target_date',today+40)),'reason','Publish revised learning targets'));
 if (select curriculum_version_id from public.class_sessions where id=session)<>curriculum then raise exception 'Curriculum history rewritten';end if;
 begin
  perform public.academic_command(jsonb_build_object('action','CREATE_SESSION','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'teacher_id',teacher,'room_id',room,'starts_on',today,'start_time','00:00','end_time','00:02','planned_scope','Conflicting class','reason','Attempt occupied time slot'));
  raise exception 'Conflicting occurrence accepted';
 exception when others then if sqlerrm not like '%conflict%' then raise;end if;end;
 -- Assigned teacher only; the roster must be complete and statuses explicit.
 perform set_config('request.jwt.claim.sub',other_user::text,true);
 if jsonb_array_length(public.academic_workspace(today,today+7)->'sessions')<>0 then raise exception 'Other teacher sees unassigned classes';end if;
 begin
  perform public.class_session_workspace(session);raise exception 'Other teacher accessed roster';
 exception when others then if sqlerrm not like '%assigned scope%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',teacher_user::text,true);
 roster:=public.class_session_workspace(session)->'roster';
 if jsonb_array_length(roster)<>1 then raise exception 'Session roster wrong';end if;
 enrollment:=(roster->0->>'enrollment_id')::uuid;
 begin
  perform public.academic_command(jsonb_build_object('action','SAVE_ATTENDANCE','request_id',gen_random_uuid(),'session_id',session,'entries','[]'::jsonb,'reason','Attempt incomplete attendance'));raise exception 'Incomplete roster accepted';
 exception when others then if sqlerrm not like '%exactly one%' then raise;end if;end;
 input:=jsonb_build_object('action','SAVE_ATTENDANCE','request_id',gen_random_uuid(),'session_id',session,'entries',jsonb_build_array(jsonb_build_object('enrollment_id',enrollment,'status','PRESENT','note','Verified in class')),'reason','Record actual observed attendance');
 result:=public.academic_command(input);draft:=(result->>'id')::uuid;
 if public.academic_command(input)<>result then raise exception 'Attendance retry duplicated';end if;
 begin
  perform public.academic_command(input||jsonb_build_object('request_id',gen_random_uuid()));raise exception 'Stale attendance accepted';
 exception when others then if sqlerrm not like '%Attendance changed%' then raise;end if;end;
 result:=public.academic_command(jsonb_build_object('action','SUBMIT_ATTENDANCE','request_id',gen_random_uuid(),'session_id',session,'attendance_id',draft,'reason','Submit roster for independent review'));approval:=(result->>'id')::uuid;
 if exists(select 1 from public.attendance_submissions where session_id=session and status='APPROVED') then raise exception 'Submission finalized early';end if;
 -- Grant reviewer capability to author to test maker-checker separately from permission denial.
 insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.system_roles r cross join public.permissions p where r.code='TEACHER' and p.code='academics.attendance.approve' on conflict do nothing;
 begin
  perform public.academic_command(jsonb_build_object('action','DECIDE_ATTENDANCE','request_id',gen_random_uuid(),'approval_id',approval,'decision','APPROVED','reason','Attempt self approval'));raise exception 'Self approval accepted';
 exception when others then if sqlerrm not like '%Maker-checker%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 input:=jsonb_build_object('action','DECIDE_ATTENDANCE','request_id',gen_random_uuid(),'approval_id',approval,'decision','APPROVED','reason','Approve independently verified attendance');
 result:=public.academic_command(input);if public.academic_command(input)<>result then raise exception 'Approval retry not idempotent';end if;
 begin
  perform public.academic_command(jsonb_build_object('action','CANCEL_SESSION','request_id',gen_random_uuid(),'session_id',session,'reason','Attempt cancellation after finalization'));raise exception 'Approved attendance session cancelled';
 exception when others then if sqlerrm not like '%cannot be cancelled%' then raise;end if;end;
 -- Correction is a fresh revision; rejection keeps the previous approved evidence.
 perform set_config('request.jwt.claim.sub',teacher_user::text,true);
 result:=public.academic_command(jsonb_build_object('action','SAVE_ATTENDANCE','request_id',gen_random_uuid(),'session_id',session,'base_id',draft,'entries',jsonb_build_array(jsonb_build_object('enrollment_id',enrollment,'status','LATE','note','Correction evidence')),'reason','Correct arrival time classification'));draft:=(result->>'id')::uuid;
 result:=public.academic_command(jsonb_build_object('action','SUBMIT_ATTENDANCE','request_id',gen_random_uuid(),'session_id',session,'attendance_id',draft,'reason','Submit proposed attendance correction'));approval:=(result->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.academic_command(jsonb_build_object('action','DECIDE_ATTENDANCE','request_id',gen_random_uuid(),'approval_id',approval,'decision','REJECTED','reason','Evidence does not support correction'));
 if (select max(revision) from public.attendance_submissions where session_id=session and status='APPROVED')<>1 then raise exception 'Rejected correction replaced official attendance';end if;
 begin
  update public.attendance_submissions set entries='[]' where session_id=session and status='APPROVED';raise exception 'Approved evidence edited';
 exception when others then if sqlerrm not like '%immutable%' then raise;end if;end;
 perform public.academic_command(jsonb_build_object('action','CANCEL_SESSION','request_id',gen_random_uuid(),'session_id',(select id from public.class_sessions where routine_id=routine and session_date=today+7),'reason','Holiday class cancellation'));
 perform public.academic_command(jsonb_build_object('action','GENERATE_SESSIONS','request_id',gen_random_uuid(),'routine_id',routine,'starts_on',today,'ends_on',today+7,'planned_scope','Preserve cancelled occurrence','reason','Repeat routine generation safely'));
 if (select count(*) from public.class_sessions where routine_id=routine)<>2 then raise exception 'Cancelled occurrence recreated';end if;
 perform public.academic_command(jsonb_build_object('action','RETIRE_ROUTINE','request_id',gen_random_uuid(),'routine_id',routine,'reason','End weekly schedule template'));
 if (select count(*) from public.class_sessions where routine_id=routine)<>2 then raise exception 'Retirement removed occurrences';end if;
 if has_table_privilege('authenticated','public.class_sessions','INSERT') or has_table_privilege('authenticated','public.attendance_submissions','UPDATE') then raise exception 'Academic controls bypassable';end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.academic_workspace(today,today+7);raise exception 'Anonymous academic read';exception when others then if sqlerrm not like '%access required%' then raise;end if;end;
end; $$;
rollback;
