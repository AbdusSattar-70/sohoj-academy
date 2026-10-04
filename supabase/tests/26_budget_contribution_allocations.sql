begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('93000000-0000-0000-0000-000000000001','planning-admin@example.test',now(),'{"full_name":"Admin"}');
select public.bootstrap_admin('planning-admin@example.test','Admin');select set_config('request.jwt.claim.sub','93000000-0000-0000-0000-000000000001',true);
do $test$
declare cid uuid;other uuid;org uuid;rev uuid;exp uuid;cash uuid;jid uuid;lid uuid;input jsonb;workspace jsonb;rejected boolean:=false;mon date:=date_trunc('month',now() at time zone 'Asia/Dhaka')::date;
begin
 cid:=(public.finance_planning_command(jsonb_build_object('action','SAVE_CENTRE','request_id',gen_random_uuid(),'name','SSC science contribution','reason','Created programme financial centre'))->>'id')::uuid;
 other:=(public.finance_planning_command(jsonb_build_object('action','SAVE_CENTRE','request_id',gen_random_uuid(),'name','Shared academy costs','reason','Created general cost centre'))->>'id')::uuid;
 input:=jsonb_build_object('action','SAVE_BUDGET','request_id',gen_random_uuid(),'centre_id',cid,'month',mon,'revenue_target',5000,'expense_limit',2000,'cash_in',4000,'cash_out',3000,'reason','Reviewed monthly operating budget');perform public.finance_planning_command(input);perform public.finance_planning_command(input);
 select id into org from public.organizations where code='SOHOJ';select id into rev from public.finance_accounts where account_type='REVENUE' limit 1;select id into exp from public.finance_accounts where account_type='EXPENSE' limit 1;select id into cash from public.finance_accounts where account_subtype='CASH' limit 1;
 jid:=public.finance_post_journal(org,current_date,'MANUAL','PLANNING_TEST',gen_random_uuid()::text,'Actual income for allocation fixture',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',1000,'credit',0),jsonb_build_object('account_id',rev,'debit',0,'credit',1000)));
 select id into lid from public.general_ledger_lines where journal_id=jid and account_id=rev;
 input:=jsonb_build_object('action','ALLOCATE','request_id',gen_random_uuid(),'line_id',lid,'expected_order',0,'allocations',jsonb_build_array(jsonb_build_object('centre_id',cid,'amount',600),jsonb_build_object('centre_id',other,'amount',200)),'reason','Verified programme income distribution');perform public.finance_planning_command(input);perform public.finance_planning_command(input);
 workspace:=public.finance_planning_workspace(mon);
 if (workspace->>'unallocated')::numeric<>200 or (select (v->>'revenue')::numeric from jsonb_array_elements(workspace->'centres')v where v->>'id'=cid::text)<>600 then raise exception 'Allocated contribution or unallocated total wrong.';end if;
 begin perform public.finance_planning_command(input||jsonb_build_object('request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected then raise exception 'Stale allocation overwrote current evidence.';end if;
 rejected:=false;begin perform public.finance_planning_command(input||jsonb_build_object('request_id',gen_random_uuid(),'expected_order',(select event_order from public.finance_line_allocations where line_id=lid order by event_order desc limit 1),'allocations',jsonb_build_array(jsonb_build_object('centre_id',cid,'amount',1200))));exception when others then rejected:=true;end;if not rejected then raise exception 'Over-allocation accepted.';end if;
 if public.finance_account_balance(cash)<>1000 then raise exception 'Budget or allocation altered cash.';end if;
 if has_function_privilege('anon','public.finance_planning_workspace(date,integer)','EXECUTE') then raise exception 'Public planning exposed.';end if;
end $test$;
rollback;
