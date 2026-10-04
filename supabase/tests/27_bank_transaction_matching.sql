begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('93000000-0000-0000-0000-000000000001','bank-admin@example.test',now(),'{"full_name":"Admin"}');
select public.bootstrap_admin('bank-admin@example.test','Admin');select set_config('request.jwt.claim.sub','93000000-0000-0000-0000-000000000001',true);
do $test$
declare org uuid;bank uuid;equity uuid;jid uuid;lid uuid;txid uuid;input jsonb;rejected boolean:=false;
begin
 select id into org from public.organizations where code='SOHOJ';select id into bank from public.finance_accounts where account_subtype='BANK' and is_active limit 1;select id into equity from public.finance_accounts where account_type='EQUITY' limit 1;
 jid:=public.finance_post_journal(org,current_date,'MANUAL','BANK_TEST',gen_random_uuid()::text,'Actual verified deposit',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',bank,'debit',1000,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',1000)));select id into lid from public.general_ledger_lines where journal_id=jid and account_id=bank;
 input:=jsonb_build_object('action','IMPORT','request_id',gen_random_uuid(),'account_id',bank,'statement_reference','BANK-OCT-001','verified_statement',true,'reason','Verified actual bank statement','rows',jsonb_build_array(jsonb_build_object('date',current_date,'reference','BANK-TX-001','amount',1000,'description','Deposit')));perform public.bank_reconciliation_command(input);perform public.bank_reconciliation_command(input);
 if (public.bank_reconciliation_workspace()->>'total')::integer<>1 then raise exception 'Bank import duplicated.';end if;
 select id into txid from public.finance_bank_transactions where account_id=bank;
 input:=jsonb_build_object('action','MATCH','request_id',gen_random_uuid(),'id',txid,'line_ids',jsonb_build_array(lid),'reason','Matched exact deposit with posted bank journal');perform public.bank_reconciliation_command(input);perform public.bank_reconciliation_command(input);
 if (public.bank_reconciliation_workspace()->>'total')::integer<>0 then raise exception 'Matched transaction remains unmatched.';end if;
 if public.finance_account_balance(bank)<>1000 then raise exception 'Statement matching changed ledger.';end if;
 perform public.bank_reconciliation_command(jsonb_build_object('action','UNMATCH','request_id',gen_random_uuid(),'id',txid,'reason','Released mistaken reference association'));
 if (public.bank_match_candidates(txid)->>'total')::integer<>1 then raise exception 'Released ledger line unavailable.';end if;
 begin perform public.bank_reconciliation_command(jsonb_build_object('action','IMPORT','request_id',gen_random_uuid(),'account_id',bank,'statement_reference','DUPLICATE-FILE','verified_statement',true,'reason','Attempt duplicate transaction import','rows',jsonb_build_array(jsonb_build_object('date',current_date,'reference','bank-tx-001','amount',1000))));exception when others then rejected:=true;end;if not rejected then raise exception 'Duplicate bank transaction imported.';end if;
 if (select count(*) from public.finance_bank_imports)<>1 or (select count(*) from public.finance_bank_links)<>1 then raise exception 'Failed import or release lost evidence.';end if;
 if has_function_privilege('anon','public.bank_reconciliation_workspace(uuid,integer,text,boolean)','EXECUTE') then raise exception 'Public bank statements exposed.';end if;
end $test$;
rollback;
