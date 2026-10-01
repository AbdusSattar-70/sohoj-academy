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
do $test$
declare sid uuid;payload jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date-1;
begin
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 payload:=jsonb_build_object('action','RECORD_ATTENDANCE','staff_id',sid,'request_id','97000000-0000-0000-0000-000000000001','work_date',day,'status','PRESENT','started_at',day::text||'T07:00:00+06:00','ended_at',day::text||'T11:00:00+06:00','break_minutes',30,'reason','Verified actual staff attendance');
 perform public.workforce_command(payload);perform public.workforce_command(payload);
 if (select count(*) from public.staff_attendance_records where staff_id=sid)<>1 then raise exception 'Attendance retry duplicated records.';end if;
 perform public.workforce_command(jsonb_build_object('action','SAVE_TERMS','staff_id',sid,'request_id','97000000-0000-0000-0000-000000000002','model','HOURLY','monthly_base',0,'hourly_rate',100,'pay_day',10,'effective_from',day,'reason','Agreed hourly compensation terms'));
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$
begin
 begin perform public.review_staff_access(jsonb_build_object('id',(select id from public.staff_access_requests where email='requested-teacher@example.test'),'action','VERIFY','assigned_role','ADMIN','reason','Attempt self privilege escalation'));
 raise exception 'Teacher self-escalation was accepted.';
 exception when others then if sqlerrm='Teacher self-escalation was accepted.' then raise; end if; end;
end $test$;
do $test$
declare w jsonb;sid uuid;rejected boolean:=false;day date:=(now() at time zone 'Asia/Dhaka')::date-1;
begin
 w:=public.staff_work_workspace(day);
 if (w->>'hours')::numeric<>3.5 or (w->>'hourlyEstimate')::numeric<>350 or (w->>'presentDays')::integer<>1 then raise exception 'Own attendance calculation incorrect.';end if;
 if jsonb_array_length(w->'people')<>0 then raise exception 'Staff directory leaked.';end if;
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000001';
 begin perform public.staff_work_workspace(day,sid);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Foreign staff records accessible.';end if;
 rejected:=false;
 begin perform public.workforce_command(jsonb_build_object('staff_id',sid,'request_id',gen_random_uuid(),'action','SAVE_TERMS','reason','Attempted own pay change'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher can change compensation terms.';end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$
declare sid uuid;month_value date:=(date_trunc('month',now() at time zone 'Asia/Dhaka')-interval '1 month')::date;day date;preview jsonb;payload jsonb;rid uuid;advance_id uuid;cash_account uuid;advance_result jsonb;rejected boolean:=false;
begin
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 update public.staff set joined_on=month_value where id=sid;
 perform public.workforce_command(jsonb_build_object('action','SAVE_TERMS','staff_id',sid,'request_id','99000000-0000-0000-0000-000000000001','model','HOURLY','monthly_base',0,'hourly_rate',100,'pay_day',10,'effective_from',month_value,'reason','Agreed effective payroll terms'));
 day:=month_value;
 perform public.workforce_command(jsonb_build_object('action','RECORD_ATTENDANCE','staff_id',sid,'request_id','99000000-0000-0000-0000-000000000002','work_date',day,'status','PRESENT','started_at',day::text||'T07:00:00+06:00','ended_at',day::text||'T11:00:00+06:00','break_minutes',30,'reason','Verified payroll work evidence'));
 payload:=jsonb_build_object('staff_id',sid,'month',month_value,'allowances','[]'::jsonb,'corrections','[]'::jsonb);
 preview:=public.staff_payroll_preview(payload);
 if (preview->>'net')::numeric<350 then raise exception 'Hourly payroll omitted verified hours.';end if;
 perform public.workforce_command(jsonb_build_object('action','RECORD_ATTENDANCE','staff_id',sid,'request_id','99000000-0000-0000-0000-000000000003','work_date',day,'status','PRESENT','started_at',day::text||'T07:00:00+06:00','ended_at',day::text||'T12:00:00+06:00','break_minutes',30,'reason','Corrected actual work evidence'));
 begin perform public.staff_payroll_command(payload||jsonb_build_object('action','POST','request_id','99000000-0000-0000-0000-000000000004','preview_token',preview->>'token','reason','Reviewed payroll posting'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Stale payroll preview was posted.';end if;
 preview:=public.staff_payroll_preview(payload);
 payload:=payload||jsonb_build_object('action','POST','request_id','99000000-0000-0000-0000-000000000005','preview_token',preview->>'token','reason','Reviewed corrected salary preview');
 rid:=(public.staff_payroll_command(payload)->>'id')::uuid;perform public.staff_payroll_command(payload);
 if (select count(*) from public.staff_payroll_records where staff_id=sid)<>1 then raise exception 'Payroll retry duplicated salary.';end if;
 select id into cash_account from public.finance_accounts where account_subtype='CASH';
 advance_result:=public.finance_accounting_command(jsonb_build_object('action','CREATE_ADVANCE','request_id','99000000-0000-0000-0000-000000000006','beneficiary_type','STAFF','staff_id',sid,'requested_amount',100,'purpose','Actual staff salary advance','reason','Agreed payroll advance'));
 advance_id:=(advance_result->>'id')::uuid;
 perform public.finance_accounting_command(jsonb_build_object('action','PAY_ADVANCE','request_id','99000000-0000-0000-0000-000000000007','advance_id',advance_id,'amount',100,'payment_account_id',cash_account,'reason','Paid actual salary advance'));
 payload:=jsonb_build_object('action','SETTLE','request_id','99000000-0000-0000-0000-000000000008','id',rid,'cash',100,'advance_offset',100,'advance_id',advance_id,'account_id',cash_account,'reference','PAY-TEST-1','reason','Paid salary and offset verified advance');
 perform public.staff_payroll_command(payload);perform public.staff_payroll_command(payload);
 if public.advance_balance(advance_id)<>0 then raise exception 'Payroll offset did not clear the paid advance.';end if;
 if (select sum(s.amount) from public.finance_payable_settlements s join public.staff_payroll_records r on r.payable_id=s.payable_id where r.id=rid)<>200 then raise exception 'Payroll settlement retry duplicated payments.';end if;
 if exists(select 1 from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where j.source_type in('STAFF_PAYROLL','STAFF_PAYROLL_SETTLEMENT') group by l.journal_id having sum(l.debit)<>sum(l.credit)) then raise exception 'Payroll journal unbalanced.';end if;
end $test$;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
do $test$
declare w jsonb;rejected boolean:=false;
begin
 w:=public.staff_payroll_workspace();
 if jsonb_array_length(w->'records')<>1 or jsonb_array_length(w->'people')<>0 or jsonb_array_length(w->'accounts')<>0 then raise exception 'Own payslip scope incorrect.';end if;
 begin perform public.staff_payroll_command(jsonb_build_object('action','POST','request_id',gen_random_uuid(),'reason','Attempted self payroll posting'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Teacher can post payroll.';end if;
end $test$;
rollback;
