begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('99000000-0000-0000-0000-000000000001','course-admin@example.test',now(),'{"full_name":"Course Admin"}');
select public.bootstrap_admin('course-admin@example.test','Course Admin');
select set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000001',true);
do $test$
declare org uuid;branch uuid;program uuid;subject uuid;offering uuid;batch uuid;admission uuid;student uuid;result jsonb;detail jsonb;today date;begin
 select id,timezone(timezone,now())::date into org,today from public.organizations where code='SOHOJ';select id into branch from public.branches where organization_id=org and code='MAIN';
 insert into public.programs(organization_id,code,name) values(org,'TRAINING_FIXTURE','Spoken English training') returning id into program;
 begin
 perform public.create_programme_offering(jsonb_build_object('branch_id',branch,'program_id',program,'operation_kind','TRAINING','code','INVALID_DURATION','teaching_starts_on',today,'reason','Missing end date must fail'));
 raise exception 'Missing course end date accepted';exception when others then if sqlerrm='Missing course end date accepted' then raise;end if;end;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'program_id',program,'operation_kind','TRAINING','code','SHORT_COURSE','teaching_starts_on',today,'teaching_ends_on',today+60,'reason','Prepare a real short course duration'));offering:=(result->>'offering_id')::uuid;
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','ONE_TIME','effective_from',today,'reason','Publish full course fee','components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Course fee','amount',1000,'charge_type','TUITION','recurrence','PER_CYCLE'))));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'name','Training group','code','SHORT_GROUP','capacity',12,'reason','Create short course group'));batch:=(result->>'id')::uuid;
 insert into public.subjects(organization_id,code,name) values(org,'TRAINING_SUBJECT','Spoken practice') returning id into subject;
 perform public.academic_command(jsonb_build_object('action','PUBLISH_CURRICULUM','request_id',gen_random_uuid(),'batch_id',batch,'subject_id',subject,'title','Course learning targets','units',jsonb_build_array(jsonb_build_object('title','Conversational practice','target_date',today+10)),'reason','Publish real course targets'));
 if (public.academic_curriculum_workspace()->>'total')::int<>1 then raise exception 'Course teaching plan missing';end if;
 perform public.save_academy_identity(jsonb_build_object('name','Sohoj Academy','branch_name','Main Campus'));perform public.complete_academy_setup();
 if not exists(select 1 from jsonb_array_elements(public.admission_workspace()->'offerings') o where o->>'id'=offering::text and o->>'classId' is null) then raise exception 'Short course missing from admission choices';end if;
 result:=public.create_staff_admission_intake(jsonb_build_object('request_id',gen_random_uuid(),'offering_id',offering,'batch_id',batch,'student_name','Training student','guardian_name','Training contact','mobile','01712345003','guardian_address','Jamalpur training address','reason','Create direct course admission','consent_to_contact',true));admission:=(result->>'admission_id')::uuid;
 detail:=public.admission_case_detail(admission);if detail->>'className' is distinct from 'Not applicable' then raise exception 'Course fabricated school class';end if;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'admission_id',admission,'reason','Verified course applicant details'));
 perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),'admission_id',admission,'source','ORGANIC','reason','Confirmed organic course admission'));
 perform public.record_physical_admission_consent(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',admission,'guardian_signed_on',today,'physical_copy_reference','Course file','reason','Received signed paper course form'));
 perform public.admission_command(jsonb_build_object('action','FINALIZE','request_id',gen_random_uuid(),'admission_id',admission,'reason','Reviewed and finalized course admission'));
 perform public.admission_command(jsonb_build_object('action','ACTIVATE','request_id',gen_random_uuid(),'admission_id',admission,'reason','Activate course enrollment under academy policy'));
 select student_id into student from public.admission_cases where id=admission;
 if not exists(select 1 from public.enrollments where student_id=student and batch_id=batch and class_id is null and academic_year_id is null and status='ACTIVE') then raise exception 'Expected real course enrollment without school fields';end if;
 if (public.admission_case_detail(admission)->'invoice'->>'due')::numeric<>1000 then raise exception 'Course unpaid invoice missing';end if;
 if jsonb_array_length(public.student_profile_workspace(student)->'enrollments')<>1 then raise exception 'Short course enrollment missing from permanent student profile';end if;
end $test$;
rollback;
