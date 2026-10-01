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
declare org uuid;cash uuid;equity uuid;expense uuid;income uuid;receivable uuid;month_value date:=(date_trunc('month',now() at time zone 'Asia/Dhaka')-interval '1 month')::date;last_day date;report jsonb;preview jsonb;a record;counts jsonb;payload jsonb;rejected boolean:=false;
begin
 last_day:=(month_value+interval '1 month - 1 day')::date;
 select id,organization_id into cash,org from public.finance_accounts where account_subtype='CASH';select id into equity from public.finance_accounts where account_subtype='RETAINED_EARNINGS';select id into expense from public.finance_accounts where account_subtype='OPERATING_EXPENSE';select id into income from public.finance_accounts where account_subtype='TUITION_REVENUE';select id into receivable from public.finance_accounts where account_subtype='STUDENT_RECEIVABLE';
 perform public.finance_post_journal(org,last_day,'MANUAL','PERIOD_TEST','funding','Period test funding',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',1000,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',1000)));
 perform public.finance_post_journal(org,last_day,'EXPENSE','PERIOD_TEST','expense','Period test expense',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',expense,'debit',100,'credit',0),jsonb_build_object('account_id',cash,'debit',0,'credit',100)));
 perform public.finance_post_journal(org,last_day,'INVOICE','PERIOD_TEST','revenue','Period test revenue',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',receivable,'debit',500,'credit',0),jsonb_build_object('account_id',income,'debit',0,'credit',500)));
 report:=public.monthly_financial_report(month_value);
 if (report->>'profit')::numeric<>400 or (report->>'balanceDifference')::numeric<>0 or (report->>'cashClosing')::numeric<>900 then raise exception 'Monthly financial report totals incorrect.';end if;
 begin perform public.finance_period_command(jsonb_build_object('action','CLOSE','month',month_value,'request_id','a1000000-0000-0000-0000-000000000001','preview_token',report->>'token','reason','Reviewed monthly accounting evidence'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Period closed without month-end account verification.';end if;
 for a in select * from public.finance_accounts where is_active and account_subtype in('CASH','BANK','MOBILE_BANK') loop
  preview:=public.daily_close_preview(a.id,last_day);
  select jsonb_agg(jsonb_build_object('value',n,'count',case when a.id=cash and n=500 then 1 when a.id=cash and n=200 then 2 else 0 end)) into counts from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
  perform public.daily_close_command(jsonb_build_object('action','COUNT','request_id',gen_random_uuid(),'account_id',a.id,'date',last_day,'actual',preview->'expected','denominations',counts,'preview_token',preview->>'token','statement_reference','Month-end verification','reason','Verified actual month-end cash and statements','variance_note',''));
 end loop;
 report:=public.monthly_financial_report(month_value);
 payload:=jsonb_build_object('action','CLOSE','month',month_value,'request_id','a1000000-0000-0000-0000-000000000002','preview_token',report->>'token','reason','Verified all month-end reconciliations');
 perform public.finance_period_command(payload);perform public.finance_period_command(payload);
 if (select count(*) from public.finance_period_events where month=month_value)<>1 then raise exception 'Period retry duplicated close evidence.';end if;
 rejected:=false;begin perform public.finance_post_journal(org,last_day,'MANUAL','PERIOD_TEST','blocked','Attempted closed-period posting',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',10,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',10)));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Closed-period posting accepted.';end if;
 perform public.finance_period_command(jsonb_build_object('action','REOPEN','month',month_value,'request_id','a1000000-0000-0000-0000-000000000003','reason','Reopened for documented late accounting correction'));
 perform public.finance_post_journal(org,last_day,'MANUAL','PERIOD_TEST','late','Permitted reopened-month posting',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',10,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',10)));
 if (public.monthly_financial_report(month_value)->>'cashClosing')::numeric<>910 then raise exception 'Reopened month did not accept corrected posting.';end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$ declare rejected boolean:=false;begin
 begin perform public.monthly_financial_report();exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher accessed academy accounts.';end if;
end $test$;
rollback;
