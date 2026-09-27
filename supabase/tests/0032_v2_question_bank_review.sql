-- Rollback-only question authoring and independent review acceptance.
begin;
do $$
declare
 author uuid := gen_random_uuid(); reviewer uuid := gen_random_uuid();
 org uuid; branch uuid; yr uuid; cl uuid; subj uuid; batch uuid; item uuid; rejected uuid; revised uuid;
 payload jsonb; answer jsonb; raised boolean;
begin
 insert into auth.users(id,email,raw_user_meta_data)
 values(author,'question-author-'||author||'@example.invalid','{"full_name":"Question Author"}'),
       (reviewer,'question-reviewer-'||reviewer||'@example.invalid','{"full_name":"Question Reviewer"}');
 perform public.bootstrap_admin('question-author-'||author||'@example.invalid','Question Author');
 insert into public.profiles(id,display_name) values(reviewer,'Question Reviewer') on conflict(id) do nothing;
 insert into public.user_role_assignments(profile_id,role_id)
 select reviewer,id from public.system_roles where code='ADMIN';
 perform set_config('request.jwt.claim.sub',author::text,true);
 select id into org from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org limit 1;
 select id into subj from public.subjects where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
 values(org,'QUESTION-'||left(author::text,8),current_date,current_date+365,false) returning id into yr;
 insert into public.batches(organization_id,branch_id,academic_year_id,class_id,code,name,capacity)
 values(org,branch,yr,cl,'QUESTION-'||left(author::text,8),'Question Test Batch',12) returning id into batch;
 payload := jsonb_build_object('action','CREATE_DRAFT','request_id',gen_random_uuid(),
   'batch_id',batch,'subject_id',subj,'topic','Unit 1','difficulty','STANDARD','question_type','MCQ',
   'prompt','Which answer best explains this concept?','choices',jsonb_build_array('First','Second','Third'),
   'answer_key','B','explanation','The second option matches the lesson.');
 answer := public.question_bank_command(payload);
 item := (answer->>'id')::uuid;
 if public.question_bank_command(payload)<>answer or (select count(*) from public.question_bank_items where id=item)<>1 then raise exception 'Create retry duplicated a question.'; end if;
 if jsonb_array_length(public.question_bank_workspace()->'items')<>1 then raise exception 'Author cannot see own draft.'; end if;
 perform public.question_bank_command(jsonb_build_object('action','SUBMIT','request_id',gen_random_uuid(),'item_id',item));
 begin
   perform public.question_bank_command(jsonb_build_object('action','APPROVE','request_id',gen_random_uuid(),'item_id',item,'review_note','Looks ready for use.'));
   raise exception 'Author approved own question.';
 exception when others then if sqlerrm not like '%cannot review their own%' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 if jsonb_array_length(public.question_bank_workspace()->'items')<>1 then raise exception 'Reviewer cannot see submitted question.'; end if;
 perform public.question_bank_command(jsonb_build_object('action','REJECT','request_id',gen_random_uuid(),'item_id',item,'review_note','Clarify the wording.'));
 perform set_config('request.jwt.claim.sub',author::text,true);
 revised := (public.question_bank_command(jsonb_build_object('action','REVISE_REJECTED','request_id',gen_random_uuid(),'item_id',item))->>'id')::uuid;
 if revised=item or (select status from public.question_bank_items where id=item)<>'REJECTED' then raise exception 'Revision overwrote rejected evidence.'; end if;
 perform public.question_bank_command(jsonb_build_object('action','SUBMIT','request_id',gen_random_uuid(),'item_id',revised));
 perform set_config('request.jwt.claim.sub',reviewer::text,true);
 perform public.question_bank_command(jsonb_build_object('action','APPROVE','request_id',gen_random_uuid(),'item_id',revised,'review_note','Verified and ready.'));
 if (select status from public.question_bank_items where id=revised)<>'APPROVED'
 or (select count(*) from public.audit_events where entity_type='QUESTION_BANK_ITEM' and entity_id=revised::text)<3 then raise exception 'Approval or audit was not recorded.'; end if;
 if has_table_privilege('authenticated','public.question_bank_items','UPDATE') then raise exception 'Direct question updates bypass workflow.'; end if;
end $$;
select 'PASS' as question_bank_review_status;
rollback;
