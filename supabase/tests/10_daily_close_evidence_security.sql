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
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$
declare account uuid;equity uuid;org uuid;preview jsonb;payload jsonb;count_rows jsonb;bad_count jsonb;rid uuid;rejected boolean:=false;d date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 select id,organization_id into account,org from public.finance_accounts where account_subtype='CASH';select id into equity from public.finance_accounts where account_subtype='RETAINED_EARNINGS';
 perform public.finance_post_journal(org,d,'MANUAL','TEST_CLOSE_FUNDING','opening','Test cash funding',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',account,'debit',1000,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',1000)));
 select jsonb_agg(jsonb_build_object('value',n,'count',case when n=1000 then 1 else 0 end)) into count_rows from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
 select jsonb_agg(jsonb_build_object('value',n,'count',case when n in(1000,200) then 1 else 0 end)) into bad_count from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
 preview:=public.daily_close_preview(account,d);
 payload:=jsonb_build_object('action','COUNT','request_id','a0000000-0000-0000-0000-000000000001','account_id',account,'date',d,'actual',1200,'denominations',bad_count,'preview_token',preview->>'token','statement_reference','Cash count 1','reason','Initial counted physical cash','variance_note','Extra cash needs investigation');
 rid:=(public.daily_close_command(payload)->>'id')::uuid;perform public.daily_close_command(payload);
 if (select count(*) from public.finance_daily_closes)<>1 then raise exception 'Count retry duplicated evidence.';end if;
 begin perform public.daily_close_command(jsonb_build_object('action','RESOLVE','request_id','a0000000-0000-0000-0000-000000000002','id',rid,'reason','Attempted to hide cash difference'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Variance resolved without matching recount.';end if;
 perform public.daily_close_command(payload||jsonb_build_object('request_id','a0000000-0000-0000-0000-000000000003','actual',1000,'denominations',count_rows,'variance_note','','reason','Corrected physical count after investigation'));
 perform public.daily_close_command(jsonb_build_object('action','RESOLVE','request_id','a0000000-0000-0000-0000-000000000004','id',rid,'reason','Recount confirmed a prior counting mistake'));
 perform public.daily_close_command(jsonb_build_object('action','NOTE','request_id','a0000000-0000-0000-0000-000000000005','id',rid,'reason','Attached investigation explanation'));
 if not exists(select 1 from jsonb_array_elements(public.daily_close_workspace()->'records') r where r->>'id'=rid::text and r->>'resolution'='RESOLVE') then raise exception 'Adding a note lost the resolved state.';end if;
 perform public.finance_post_journal(org,d,'MANUAL','TEST_CLOSE_FUNDING','late','Late cash posting',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',account,'debit',100,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',100)));
 if not exists(select 1 from jsonb_array_elements(public.daily_close_workspace()->'records') r where r->>'id'=rid::text and (r->>'stale')::boolean and (r->>'resolution_stale')::boolean) then raise exception 'Late posting did not invalidate closed evidence.';end if;
 rejected:=false;begin perform public.daily_close_command(payload||jsonb_build_object('request_id','a0000000-0000-0000-0000-000000000006'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Stale balance accepted.';end if;
 if (public.daily_close_preview(account,d)->>'expected')::numeric<>1100 then raise exception 'Cash closing overwrote ledger balance.';end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$ declare rejected boolean:=false;begin
 begin perform public.daily_close_workspace();exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher accessed academy closing accounts.';end if;
end $test$;
rollback;
