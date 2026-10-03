begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('93000000-0000-0000-0000-000000000001','flow-admin@example.test',now(),'{"full_name":"Admin"}');
select public.bootstrap_admin('flow-admin@example.test','Admin');select set_config('request.jwt.claim.sub','93000000-0000-0000-0000-000000000001',true);
do $test$
declare org uuid;cash uuid;bank uuid;equity uuid;expense uuid;jid uuid;report jsonb;input jsonb;rejected boolean:=false;
begin
 select id into org from public.organizations where code='SOHOJ';select id into cash from public.finance_accounts where account_subtype='CASH' limit 1;select id into bank from public.finance_accounts where account_subtype='BANK' limit 1;select id into equity from public.finance_accounts where account_type='EQUITY' limit 1;select id into expense from public.finance_accounts where account_type='EXPENSE' limit 1;
 perform public.finance_post_journal(org,current_date,'MANUAL','OWNER_CAPITAL',gen_random_uuid()::text,'Actual capital flow',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',2000,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',2000)));
 perform public.finance_post_journal(org,current_date,'MANUAL','INTERNAL_FLOW_TEST',gen_random_uuid()::text,'Cash to bank transfer',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',bank,'debit',500,'credit',0),jsonb_build_object('account_id',cash,'debit',0,'credit',500)));
 jid:=public.finance_post_journal(org,current_date,'MANUAL','UNKNOWN_FLOW_TEST',gen_random_uuid()::text,'Actual operating expense flow',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',expense,'debit',100,'credit',0),jsonb_build_object('account_id',cash,'debit',0,'credit',100)));
 report:=public.classified_cash_flow();if (report->>'total')::integer<>2 or (report->>'closing')::numeric<>1900 or (report->>'difference')::numeric<>0 then raise exception 'Cash flow arithmetic/internal transfer incorrect.';end if;
 if (select (v->>'outflow')::numeric from jsonb_array_elements(report->'summary')v where v->>'category'='UNCLASSIFIED')<>100 then raise exception 'Unknown source silently classified.';end if;
 input:=jsonb_build_object('request_id',gen_random_uuid(),'id',jid,'expected_order',0,'category','OPERATING','reason','Verified operating cost evidence');perform public.cash_classification_command(input);perform public.cash_classification_command(input);
 report:=public.classified_cash_flow();if (select (v->>'net')::numeric from jsonb_array_elements(report->'summary')v where v->>'category'='OPERATING')<>-100 then raise exception 'Manual classification failed.';end if;
 begin perform public.cash_classification_command(input||jsonb_build_object('request_id',gen_random_uuid(),'category','FINANCING'));exception when others then rejected:=true;end;if not rejected then raise exception 'Stale classification accepted.';end if;
 if public.finance_account_balance(cash)<>1400 then raise exception 'Classification modified ledger.';end if;
 if has_function_privilege('anon','public.classified_cash_flow(date,integer)','EXECUTE') then raise exception 'Public cash flow exposed.';end if;
end $test$;
rollback;
