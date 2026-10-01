begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('91000000-0000-0000-0000-000000000001','redesign-admin@example.test',now(),'{"full_name":"Redesign Admin"}');
select public.bootstrap_admin('redesign-admin@example.test','Redesign Admin');
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
do $test$
declare org uuid; branch uuid; year uuid; class_id uuid; another_class uuid; program uuid;
 offering uuid; batch uuid; replacement_batch uuid; direct_case uuid; converted_case uuid; prospect uuid; result jsonb; count_before integer;
 local_today date; detail jsonb; extra_id uuid:=gen_random_uuid(); inactive_id uuid:=gen_random_uuid(); extra_input jsonb; final_request uuid:=gen_random_uuid();
begin
 select id,timezone(timezone,now())::date into org,local_today from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org and code='MAIN';
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
 values(org,'Fixture academic year',date_trunc('year',local_today)::date,(date_trunc('year',local_today)+interval '1 year - 1 day')::date,true) returning id into year;
 insert into public.classes(organization_id,code,name,sort_order) values(org,'FIXTURE_10','Fixture Class 10',10) returning id into class_id;
 insert into public.classes(organization_id,code,name,sort_order) values(org,'FIXTURE_8','Fixture Class 8',8) returning id into another_class;
 insert into public.programs(organization_id,code,name) values(org,'FIXTURE_PROGRAM','Fixture programme') returning id into program;
 insert into public.subjects(organization_id,code,name) values(org,'FIXTURE_SUBJECT','Fixture subject');
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',year,'class_id',class_id,'program_id',program,'code','REDESIGN_TEST','reason','Create workflow test offering'));
 offering:=(result->>'offering_id')::uuid;
 if (select name from public.programme_offerings where id=offering) is distinct from (select name from public.programs where id=program) then raise exception 'Offering must use the programme name when no custom title is supplied.'; end if;
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',local_today,'reason','Initial standard charges',
 'components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',3000,'charge_type','TUITION','recurrence','PER_CYCLE'),jsonb_build_object('code','ADMISSION','name','Admission fee','amount',0,'charge_type','ADMISSION','recurrence','ONE_TIME'))));
 perform public.save_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',local_today,'reason','Correct current charges on the same day',
 'components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',3000,'charge_type','TUITION','recurrence','PER_CYCLE'),jsonb_build_object('code','ADMISSION','name','Admission fee','amount',0,'charge_type','ADMISSION','recurrence','ONE_TIME'))));
 perform public.save_offering_discount_policy(jsonb_build_object('offering_id',offering,'percentages',jsonb_build_array(5,10)));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'name','Redesign morning','code','REDESIGN_MORNING','capacity',12,'reason','Create workflow test batch'));
 batch:=(result->>'id')::uuid;
 if (public.academy_setup_status()->>'ready')::boolean then raise exception 'Setup must require explicit identity confirmation.'; end if;
 perform public.save_academy_identity(jsonb_build_object('name','Sohoj Academy','branch_name','Main Campus'));
 perform public.complete_academy_setup();
 select count(*) into count_before from public.schools;
 result:=public.submit_public_interest(jsonb_build_object('student_name','Wrong preference applicant','guardian_name','Applicant Guardian','mobile','01712345001','class_id',another_class,'offering_id',offering,'program_ids',jsonb_build_array(gen_random_uuid()),'subject_ids',jsonb_build_array(gen_random_uuid()),'school_name_snapshot','Unverified school claim','intent','admission','guardian_address','Jamalpur test address','consent_to_contact',true));
 prospect:=(result->>'prospect_id')::uuid;
 if exists(select 1 from public.prospects where id=prospect and (current_class_id is not null or interested_offering_id is not null or school_id is not null)) then raise exception 'Unverified intake must not assign master FK choices.'; end if;
 if (select count(*) from public.schools)<>count_before then raise exception 'Anonymous claims must not create schools.'; end if;
 result:=public.create_prospect_admission(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'prospect_id',prospect,'offering_id',offering,'batch_id',batch,'reason','Verified actual placement with guardian'));
 converted_case:=(result->>'id')::uuid;
 if converted_case is null then raise exception 'Unverified public intake must convert after staff placement verification.'; end if;
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'offering_id',offering,'name','Alternative placement','code','REDESIGN_ALT','capacity',12,'reason','Create corrected placement option'));
 replacement_batch:=(result->>'id')::uuid;
 perform public.save_admission_extra_charge(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',converted_case,'name','Draft materials','charge_type','MATERIAL','amount',100));
 perform public.correct_admission_placement(jsonb_build_object('admission_id',converted_case,'offering_id',offering,'batch_id',replacement_batch,'reason','Correct placement before admission submission'));
 if not exists(select 1 from public.admission_cases where id=converted_case and batch_id=replacement_batch and status='DRAFT' and identity_revision=2) then raise exception 'Draft placement correction failed.'; end if;
 if exists(select 1 from public.admission_cases a,jsonb_array_elements(a.additional_charges) c where a.id=converted_case and (c->>'is_active')::boolean) then raise exception 'Old placement charges must be reverified.'; end if;

 select count(*) into count_before from public.prospects;
 result:=public.create_staff_admission_intake(jsonb_build_object('request_id',gen_random_uuid(),'offering_id',offering,'batch_id',batch,'student_name','Direct admission student','guardian_name','Direct Guardian','guardian_relationship','Father','mobile','01712345002','guardian_address','Jamalpur direct address','reason','Staff assisted admission test','consent_to_contact',true));
 direct_case:=(result->>'admission_id')::uuid;
 if (select count(*) from public.prospects)<>count_before then raise exception 'Direct intake must not manufacture a Prospect.'; end if;
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'admission_id',direct_case,'reason','Verified student and guardian details'));
 begin
 perform public.admission_command(jsonb_build_object('action','FINALIZE','request_id',gen_random_uuid(),'admission_id',direct_case,'reason','Attempt final submission without consent'));
 raise exception 'Final submission without consent was accepted.';
 exception when others then if sqlerrm='Final submission without consent was accepted.' then raise; end if; end;
 perform public.referral_command(jsonb_build_object('action','CAPTURE','request_id',gen_random_uuid(),'admission_id',direct_case,'source','REFERRED','full_name','Referral fixture person','mobile','01711111119','reason','Verified referring person identity'));
 perform public.record_physical_admission_consent(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',direct_case,'guardian_signed_on',local_today,'student_signed',false,'physical_copy_reference','Test physical file','reason','Verified signed original and filed'));
 perform public.edit_admission_identity(jsonb_build_object('admission_id',direct_case,'reason','Corrected name after guardian review','identity',jsonb_build_object('student_name','Direct admission student corrected','guardian_name','Direct Guardian','mobile','01712345002','guardian_address','Jamalpur direct address','guardian_relationship','Father')));
 perform public.admission_command(jsonb_build_object('action','READY','request_id',gen_random_uuid(),'admission_id',direct_case,'reason','Verified corrected identity details'));
 if (public.admission_review_checks(direct_case)->>'hasConsent')::boolean then raise exception 'Old signed consent must not cover corrected identity.'; end if;
 perform public.record_physical_admission_consent(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',direct_case,'guardian_signed_on',local_today,'student_signed',false,'physical_copy_reference','Corrected physical file','reason','Received signed corrected admission form'));
 if (select count(*) from public.admission_physical_consent_receipts where admission_id=direct_case)<>2 then raise exception 'Original signed record must remain in history.'; end if;
 begin
 perform public.admission_command(jsonb_build_object('action','SAVE_DISCOUNT','request_id',gen_random_uuid(),'admission_id',direct_case,'discount_percent',30,'discount_reason','MERIT','reason','Attempt discount outside offering policy'));
 raise exception 'Unsupported discount was accepted.';
 exception when others then if sqlerrm='Unsupported discount was accepted.' then raise; end if; end;
 perform public.admission_command(jsonb_build_object('action','SAVE_DISCOUNT','request_id',gen_random_uuid(),'admission_id',direct_case,'discount_percent',10,'discount_reason','MERIT','reason','Merit discount eligibility checked'));
 extra_input:=jsonb_build_object('request_id',extra_id,'admission_id',direct_case,'name','Learning materials','charge_type','MATERIAL','amount',100);
 perform public.save_admission_extra_charge(extra_input);
 perform public.save_admission_extra_charge(extra_input);
 perform public.save_admission_extra_charge(jsonb_build_object('request_id',inactive_id,'admission_id',direct_case,'name','Extra test fee','charge_type','EXAM','amount',200));
 perform public.deactivate_admission_extra_charge(direct_case,inactive_id);
 perform public.admission_command(jsonb_build_object('action','FINALIZE','request_id',final_request,'admission_id',direct_case,'reason','Reviewed admission details fees and signed paper consent'));
 if (select count(*) from public.audit_events where correlation_id=final_request and action in('ACCEPT','BILL','FINALIZE'))<>3 then raise exception 'Final submission events must share a workflow trace.'; end if;
 if exists(select 1 from public.audit_events where correlation_id=final_request and (actor_profile_id is null or actor_role_code not like '%ADMIN%' or metadata->>'actor_name' is null)) then raise exception 'Staff audit attribution missing.'; end if;
 detail:=public.admission_case_detail(direct_case);
 if detail->>'studentNo' is null or detail->>'academyRoll' is null then raise exception 'Student ID and roll must be assigned by the system.'; end if;
 if (detail->'invoice'->>'due')::numeric<>2800 then raise exception 'Expected unpaid invoice of 2800 after tuition discount, got %',detail->'invoice'; end if;
 if (select count(*) from public.admission_payments where student_id=(detail->>'studentId')::uuid)<>0 then raise exception 'Final submission must not invent payment.'; end if;
 begin
 delete from public.admission_cases where id=direct_case;
 raise exception 'Permanent admission deletion was accepted.';
 exception when others then if sqlerrm='Permanent admission deletion was accepted.' then raise; end if; end;

 perform public.collect_student_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',direct_case,'invoice_id',detail->'invoice'->>'id','amount',1400,'adjustment_amount',0,'payment_method_id',(select id from public.payment_methods where code='CASH'),'reason','Received actual partial tuition payment'));
 if (select sum(amount) from public.referral_reward_entries where admission_id=direct_case)<>675 then raise exception 'Expected proportionate referral entitlement of 675.'; end if;
 if public.referrer_workspace((select referrer_id from public.admission_referrals where admission_id=direct_case))->>'name'<>'Referral fixture person' then raise exception 'Admin register detail missing.'; end if;
 perform public.collect_student_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',direct_case,'invoice_id',detail->'invoice'->>'id','amount',600,'adjustment_amount',100,'adjustment_category','DISCOUNT','adjustment_reason','Verified collection-time hardship','payment_method_id',(select id from public.payment_methods where code='CASH'),'reason','Collected partial money with discount'));
 if (select sum(amount) from public.referral_reward_entries where admission_id=direct_case)<>962.97 then raise exception 'Partial collection reward should use updated net tuition attribution.'; end if;
 perform public.settle_referrer_reward(jsonb_build_object('request_id',gen_random_uuid(),'referrer_id',(select referrer_id from public.admission_referrals where admission_id=direct_case),'amount',100,'account_id',(select id from public.finance_accounts where code='1100'),'reason','Paid actual referral reward'));
 perform public.collect_student_payment(jsonb_build_object('request_id',gen_random_uuid(),'admission_id',direct_case,'invoice_id',detail->'invoice'->>'id','amount',0,'adjustment_amount',100,'adjustment_category','SCHOLARSHIP','adjustment_reason','Awarded academic merit scholarship','reason','Granted scholarship with no payment'));
 if (select count(*) from public.admission_payments where student_id=(detail->>'studentId')::uuid)<>2 then raise exception 'Scholarship-only save invented a payment.'; end if;
 if (select sum(amount) from public.referral_reward_entries where admission_id=direct_case)<>961.54 then raise exception 'Late reduction must adjust reward entitlement.'; end if;
 if not exists(select 1 from public.invoice_credits where invoice_id=(detail->'invoice'->>'id')::uuid and category='SCHOLARSHIP') then raise exception 'Scholarship classification missing.'; end if;
 perform public.finance_command(jsonb_build_object('action','CANCEL_ADMISSION','request_id',gen_random_uuid(),'admission_id',direct_case,'settlement','CREDIT_ALL','reason','Cancellation authorized with full charge reversal'));
 if (select sum(amount) from public.referral_reward_entries where admission_id=direct_case)<>0 then raise exception 'Full charge reversal must reverse acquisition entitlement.'; end if;
 perform public.finance_command(jsonb_build_object('action','REFUND','request_id',gen_random_uuid(),'invoice_id',detail->'invoice'->>'id','payment_id',(select pa.payment_id from public.admission_payment_allocations pa where pa.invoice_id=(detail->'invoice'->>'id')::uuid order by pa.amount desc limit 1),'amount',500,'payment_method_id',(select id from public.payment_methods where code='CASH'),'reason','Returned actual money after cancellation'));
 if not exists(select 1 from public.refund_payouts rp join public.refund_authorizations ra on ra.id=rp.authorization_id where ra.invoice_id=(detail->'invoice'->>'id')::uuid and ra.amount=500) then raise exception 'Actual refund payout missing';end if;
 if (select sum(amount) from public.referral_reward_entries where admission_id=direct_case)<>0 then raise exception 'Refund after cancellation resurrected referral reward';end if;
 begin
 perform public.settle_referrer_reward(jsonb_build_object('request_id',gen_random_uuid(),'referrer_id',(select referrer_id from public.admission_referrals where admission_id=direct_case),'amount',1,'account_id',(select id from public.finance_accounts where code='1100'),'reason','Attempt overpayment after correction'));
 raise exception 'Overpayment was accepted';
 exception when others then if sqlerrm='Overpayment was accepted' then raise;end if;end;
 if exists(select 1 from public.general_ledger_lines group by journal_id having sum(debit)<>sum(credit)) then raise exception 'Reward ledger is unbalanced.';end if;
end $test$;
-- A referrer account has no staff/student/finance table permissions. Own-portal RPC is the only contract.
insert into auth.users(id,email) values('94000000-0000-0000-0000-000000000001','referral-owner@example.test'),('94000000-0000-0000-0000-000000000002','unrelated@example.test');
update public.referral_people set email='referral-owner@example.test' where mobile='01711111119';
select public.manage_referrer(jsonb_build_object('action','LINK_ACCOUNT','request_id',gen_random_uuid(),'id',(select id from public.referral_people where mobile='01711111119'),'reason','Verified referrer account ownership'));
select set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $scope$ declare w jsonb; begin
 w:=public.referrer_workspace();if w->>'manager'<>'false' or jsonb_array_length(w->'students')<>1 then raise exception 'Own portal scope is incorrect';end if;
 if public.has_permission('students.view') or public.has_permission('finance.view') then raise exception 'Referrer received ERP privilege';end if;
 begin perform public.referrer_workspace('94000000-0000-0000-0000-000000000099');raise exception 'Foreign referral allowed';exception when others then if sqlerrm='Foreign referral allowed' then raise;end if;end;
 begin perform public.sync_referral_reward((w->'students'->0->>'id')::uuid);raise exception 'Private helper callable';exception when insufficient_privilege then null;end;
end $scope$;
reset role;
select set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000002',true);
do $scope$ begin begin perform public.referrer_workspace();raise exception 'Unlinked account allowed';exception when others then if sqlerrm='Unlinked account allowed' then raise;end if;end;end $scope$;
rollback;
