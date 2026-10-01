begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('92000000-0000-0000-0000-000000000001','request-review-admin@example.test',now(),'{"full_name":"Access Review Admin"}'),
 ('92000000-0000-0000-0000-000000000002','requested-teacher@example.test',now(),'{"full_name":"Requested Teacher"}');
select public.bootstrap_admin('request-review-admin@example.test','Access Review Admin');
select set_config('request.jwt.claim.sub','',true);
select public.request_staff_access('{"full_name":"Requested Teacher","email":"requested-teacher@example.test","mobile":"01712345999","requested_role":"ADMIN","purpose":"Teach assigned academy classes"}');
do $test$
begin
 if exists(select 1 from public.user_role_assignments where profile_id='92000000-0000-0000-0000-000000000002') then raise exception 'Requested role must not grant access.'; end if;
 if has_function_privilege('authenticated','public.execute_admission_stage(jsonb)','EXECUTE') then raise exception 'Internal admission engine is callable by client.'; end if;
 if has_function_privilege('anon','public.review_staff_access(jsonb)','EXECUTE') then raise exception 'Anonymous user may review access.'; end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$
declare request_id uuid;
begin
 select id into request_id from public.staff_access_requests where email='requested-teacher@example.test';
 perform public.review_staff_access(jsonb_build_object('id',request_id,'action','VERIFY','assigned_role','TEACHER','reason','Verified identity and teaching responsibilities'));
 if exists(select 1 from public.user_role_assignments where profile_id='92000000-0000-0000-0000-000000000002') then raise exception 'Verification alone must not grant access.'; end if;
 perform public.review_staff_access(jsonb_build_object('id',request_id,'action','COMPLETE_INVITATION','reason','Supabase invitation created verified account'));
 if not exists(select 1 from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id='92000000-0000-0000-0000-000000000002' and r.code='TEACHER' and a.is_active) then raise exception 'Verified teaching role not assigned.'; end if;
 if exists(select 1 from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id='92000000-0000-0000-0000-000000000002' and r.code='ADMIN') then raise exception 'Unverified requested ADMIN role was granted.'; end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$
begin
 begin perform public.review_staff_access(jsonb_build_object('id',(select id from public.staff_access_requests where email='requested-teacher@example.test'),'action','VERIFY','assigned_role','ADMIN','reason','Attempt self privilege escalation'));
 raise exception 'Teacher self-escalation was accepted.';
 exception when others then if sqlerrm='Teacher self-escalation was accepted.' then raise; end if; end;
end $test$;
do $test$
declare w jsonb; rid uuid; rejected boolean:=false;
begin
 w:=public.referrer_workspace();
 if w->>'selected' is null or (w->>'manager')::boolean or not (w->>'teacher')::boolean then raise exception 'Teacher own referral identity not resolved.';end if;
 if jsonb_array_length(w->'people')<>0 or jsonb_array_length(w->'accounts')<>0 then raise exception 'Teacher directory or finance accounts leaked.';end if;
 if (w->'policy'->>'acquisitionPercent')::numeric<>50 or (w->'policy'->>'teachingPoolPercent')::numeric<>30 then raise exception 'Current compensation terms unavailable.';end if;
 select id into rid from public.referral_people where profile_id='92000000-0000-0000-0000-000000000001';
 begin perform public.referrer_workspace(rid);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher can inspect another referrer.';end if;
 if has_function_privilege('authenticated','public.create_staff_member(jsonb)','EXECUTE') then raise exception 'Manual staff creation remains exposed.';end if;
 perform public.my_erp_context();perform public.my_erp_context();
 if not exists(select 1 from public.staff_access_requests where profile_id=auth.uid() and status='ACTIVE') then raise exception 'Account use did not complete onboarding.';end if;
 if (select count(*) from public.audit_events where actor_profile_id=auth.uid() and action='ACCOUNT_ACTIVATED')<>1 then raise exception 'Account activation audit repeated.';end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$ begin
 if public.referrer_workspace()->>'selected' is null then raise exception 'Admin own statement is not the default.';end if;
end $test$;
rollback;
