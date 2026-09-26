-- Development-only fixtures, entirely rolled back. Run as database owner.
begin;
do $$
declare
 u uuid:=gen_random_uuid(); org uuid; cl uuid; program uuid; branch uuid; yr uuid;
 offering uuid; batch uuid; prospect uuid; a uuid; a2 uuid; fee uuid; method uuid;
 result jsonb; input jsonb; today date; baseline jsonb;
 reviewer uuid:=gen_random_uuid();student uuid;destination uuid;old_enrollment uuid;approval_id uuid;stale_id uuid;original_fee uuid;original_invoice uuid;duplicate uuid;duplicate_case uuid;duplicate_invoice uuid;profile jsonb;viewer uuid:=gen_random_uuid();viewer_role uuid;
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

 insert into auth.users(id,email,raw_user_meta_data) values(reviewer,'lifecycle-reviewer-'||reviewer||'@example.invalid','{"full_name":"Lifecycle Reviewer"}');
 perform public.bootstrap_admin('lifecycle-reviewer-'||reviewer||'@example.invalid','Lifecycle Reviewer');
 select student_id,enrollment_id,fee_plan_version_id into student,old_enrollment,original_fee from public.admission_cases where id=a;
 select id into original_invoice from public.admission_invoices where admission_id=a;
 result:=public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'name','Transfer Destination','code','DEST-'||left(u::text,8),'capacity',1,'reason','Create compatible transfer batch'));
 destination:=(result->>'id')::uuid;
 input:=jsonb_build_object('action','REQUEST_TRANSFER','request_id',gen_random_uuid(),'student_id',student,'admission_id',a,'batch_id',destination,'reason','Family requested alternative batch');
 result:=public.student_command(input);approval_id:=(result->>'id')::uuid;
 if public.student_command(input)<>result then raise exception 'Transfer request retry duplicated';end if;
 result:=public.student_command(input||jsonb_build_object('request_id',gen_random_uuid()));stale_id:=(result->>'id')::uuid;
 begin
  perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Attempt self approval'));
  raise exception 'Self-approved transfer';
 exception when others then if sqlerrm not like '%Maker-checker%' then raise;end if;end;
 -- Capacity can change after request; decision must recheck it.
 insert into public.students(organization_id,full_name) values(org,'Seat Occupant '||u) returning id into duplicate;
 insert into public.enrollments(student_id,organization_id,branch_id,academic_year_id,class_id,program_id,batch_id,status,created_by)
 values(duplicate,org,branch,yr,cl,program,destination,'ACTIVE',u);
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 begin
  perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Review now full destination'));
  raise exception 'Full destination transfer accepted';
 exception when others then if sqlerrm not like '%full%' then raise;end if;end;
 update public.enrollments set status='WITHDRAWN',ended_on=today where student_id=duplicate;
 input:=jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Approve verified batch transfer');
 result:=public.student_command(input);
 if public.student_command(input)<>result then raise exception 'Transfer approval retry duplicated';end if;
 if (select batch_id from public.admission_cases where id=a)<>destination or (select status from public.enrollments where id=old_enrollment)<>'WITHDRAWN' then raise exception 'Transfer failed to preserve/replace enrollment';end if;
 if (select count(*) from public.enrollments where student_id=student and status='ACTIVE')<>1 then raise exception 'Transfer active enrollment count wrong';end if;
 if (select fee_plan_version_id from public.admission_cases where id=a)<>original_fee or (select count(*) from public.admission_invoices where admission_id=a)<>1 then raise exception 'Transfer changed fee or billed again';end if;
 begin
  perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',stale_id,'decision','APPROVED','reason','Attempt stale transfer approval'));
  raise exception 'Stale transfer accepted';
 exception when others then if sqlerrm not like '%Enrollment changed%' then raise;end if;end;
 perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',stale_id,'decision','REJECTED','reason','Reject superseded transfer'));
 begin
  perform public.student_command(jsonb_build_object('action','CREATE_EXISTING','request_id',gen_random_uuid(),'student_id',student,'batch_id',batch,'reason','Attempt duplicate year enrollment'));
  raise exception 'Duplicate academic year enrollment accepted';
 exception when others then if sqlerrm not like '%already exists%' then raise;end if;end;
 -- Readmission after controlled cancellation reuses the same Student identity.
 perform set_config('request.jwt.claim.sub',u::text,true);
 result:=public.finance_command(jsonb_build_object('action','REQUEST_CANCEL','request_id',gen_random_uuid(),'admission_id',a,'settlement','KEEP_CHARGES','reason','Close earlier enrollment before readmission'));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.finance_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',result->>'id','decision','APPROVED','reason','Approve earlier enrollment cancellation'));
 input:=jsonb_build_object('action','CREATE_EXISTING','request_id',gen_random_uuid(),'student_id',student,'batch_id',batch,'reason','Create existing student readmission');
 result:=public.student_command(input);a2:=(result->>'id')::uuid;
 if public.student_command(input)<>result then raise exception 'Readmission draft retry duplicated';end if;
 if (select student_id from public.admission_cases where id=a2)<>student then raise exception 'Readmission changed identity';end if;
 begin
  perform public.admission_command(jsonb_build_object('action','EDIT_DRAFT','request_id',gen_random_uuid(),'admission_id',a2,'student_name','Different Name','guardian_name','Other Guardian','mobile','01700000999','reason','Attempt identity overwrite'));
  raise exception 'Existing identity draft changed';
 exception when others then if sqlerrm not like '%read-only%' then raise;end if;end;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'admission_id',a2,'reason','Review inherited enrollment'));
 perform public.admission_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),'admission_id',a2,'reason','Accept existing student enrollment'));
 perform public.admission_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),'admission_id',a2,'reason','Bill new enrollment separately'));
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'admission_id',a2,'reason','Activate existing student enrollment'));
 if (select status from public.admission_cases where id=a2)<>'ACTIVE_ENROLLMENT' or (select total from public.admission_invoices where id=original_invoice)<>2600 then raise exception 'Readmission damaged history';end if;
 -- Legacy duplicate fixture with a cancelled case and a real posted payment.
 insert into public.students(organization_id,full_name,status) select org,full_name,'INACTIVE' from public.students where id=student returning id into duplicate;
 insert into public.student_guardians(student_id,guardian_id,relationship_snapshot,is_primary) select duplicate,guardian_id,relationship_snapshot,is_primary from public.student_guardians where student_id=student;
 insert into public.admission_cases(batch_id,fee_plan_version_id,student_id,existing_student,status,identity_snapshot,created_by)
 select batch,original_fee,duplicate,true,'CANCELLED',identity_snapshot,u from public.admission_cases where id=a returning id into duplicate_case;
 insert into public.admission_invoices(admission_id,student_id,fee_plan_version_id,currency_code,total,issued_on,due_on,billing_period,posted_by)
 values(duplicate_case,duplicate,original_fee,'BDT',600,today,today,date_trunc('month',today)::date,u) returning id into duplicate_invoice;
 perform public.post_admission_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',duplicate_case,'payment_method_id',method,'amount',100,'reason','Historical duplicate payment fixture'));
 perform set_config('request.jwt.claim.sub',u::text,true);
 input:=jsonb_build_object('action','REQUEST_MERGE','request_id',gen_random_uuid(),'student_id',duplicate,'target_id',student,'confirmed_same_person',true,'reason','Verified identity documents and guardian evidence');
 result:=public.student_command(input);approval_id:=(result->>'id')::uuid;
 begin
  perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Attempt merge self approval'));
  raise exception 'Self-approved merge';
 exception when others then if sqlerrm not like '%Maker-checker%' then raise;end if;end;
 update public.students set school_name_snapshot='Changed school' where id=duplicate;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 begin
  perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Attempt stale identity approval'));
  raise exception 'Stale merge accepted';
 exception when others then if sqlerrm not like '%records changed%' then raise;end if;end;
 perform public.student_command(jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','REJECTED','reason','Reject stale duplicate review'));
 perform set_config('request.jwt.claim.sub',u::text,true);
 result:=public.student_command(input||jsonb_build_object('request_id',gen_random_uuid()));approval_id:=(result->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 input:=jsonb_build_object('action','DECIDE','request_id',gen_random_uuid(),'approval_id',approval_id,'decision','APPROVED','reason','Approve verified canonical identity');
 result:=public.student_command(input);if public.student_command(input)<>result then raise exception 'Merge retry not idempotent';end if;
 if (select merged_into_id from public.students where id=duplicate)<>student or (select status from public.students where id=duplicate)<>'ARCHIVED' then raise exception 'Merge link missing';end if;
 if (select student_id from public.admission_invoices where id=duplicate_invoice)<>duplicate or not exists(select 1 from public.admission_payments where student_id=duplicate) then raise exception 'Merge rewrote financial identity';end if;
 profile:=public.student_profile_workspace(student);
 if jsonb_array_length(profile->'identities')<>2 or jsonb_array_length(profile->'invoices')<>3 or jsonb_array_length(profile->'transfers')<>1 then raise exception 'Canonical history incomplete: %',profile;end if;
 if public.student_profile_workspace(duplicate)->'student'->>'canonicalId'<>student::text then raise exception 'Archived identity does not resolve';end if;
 begin
  perform public.student_command(jsonb_build_object('action','CREATE_EXISTING','request_id',gen_random_uuid(),'student_id',duplicate,'batch_id',destination,'reason','Attempt merged identity reuse'));
  raise exception 'Archived duplicate reused';
 exception when others then if sqlerrm not like '%canonical%' then raise;end if;end;
 if has_table_privilege('authenticated','public.students','UPDATE') or has_table_privilege('authenticated','public.student_merges','INSERT') then raise exception 'Lifecycle controls bypassable';end if;
 -- A student-view-only profile must not receive financial amounts or mutation access.
 insert into auth.users(id,email,raw_user_meta_data) values(viewer,'lifecycle-viewer-'||viewer||'@example.invalid','{"full_name":"Student Viewer"}');
 insert into public.profiles(id,display_name) values(viewer,'Student Viewer') on conflict(id) do nothing;
 insert into public.system_roles(code,name) values('TEST_VIEW_'||left(viewer::text,8),'Test student viewer') returning id into viewer_role;
 insert into public.role_permissions(role_id,permission_id) select viewer_role,id from public.permissions where code='students.view';
 insert into public.user_role_assignments(profile_id,role_id) values(viewer,viewer_role);
 perform set_config('request.jwt.claim.sub',viewer::text,true);
 profile:=public.student_profile_workspace(student);
 if (profile->>'financeVisible')::boolean or jsonb_array_length(profile->'invoices')<>0 then raise exception 'Financial amounts leaked to student-only viewer';end if;
 begin
  perform public.student_command(jsonb_build_object('action','CREATE_EXISTING','request_id',gen_random_uuid(),'student_id',student,'batch_id',destination,'reason','Attempt unauthorized enrollment'));
  raise exception 'Unauthorized enrollment accepted';
 exception when others then if sqlerrm not like '%permission required%' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','',true);
 begin
  perform public.student_profile_workspace(student);raise exception 'Anonymous student read accepted';
 exception when others then if sqlerrm not like '%access required%' then raise;end if;end;
end; $$;
rollback;
