begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('93000000-0000-0000-0000-000000000001','capital-admin@example.test',now(),'{"full_name":"Admin"}');
select public.bootstrap_admin('capital-admin@example.test','Admin');select set_config('request.jwt.claim.sub','93000000-0000-0000-0000-000000000001',true);
do $test$
declare owner_uuid uuid;cash uuid;input jsonb;rejected boolean:=false;
begin
 owner_uuid:=(public.owner_capital_command(jsonb_build_object('action','SAVE_OWNER','request_id',gen_random_uuid(),'name','Verified owner','contact','01712345678','reason','Recorded owner identity'))->>'id')::uuid;
 select id into cash from public.finance_accounts where account_subtype='CASH' and is_active limit 1;
 input:=jsonb_build_object('action','POST','request_id',gen_random_uuid(),'owner_id',owner_uuid,'kind','CONTRIBUTION','account_id',cash,'amount',5000,'reference','OWNER-001','actual_confirmed',true,'reason','Received actual owner contributed cash');perform public.owner_capital_command(input);perform public.owner_capital_command(input);
 if public.finance_account_balance(cash)<>5000 then raise exception 'Capital funding/retry wrong.';end if;
 input:=input||jsonb_build_object('request_id',gen_random_uuid(),'kind','CAPITAL_RETURN','amount',1000,'reference','OWNER-002');perform public.owner_capital_command(input);
 if public.finance_account_balance(cash)<>4000 or (public.owner_capital_workspace()->'owners'->0->>'capital_balance')::numeric<>4000 then raise exception 'Capital return mismatch.';end if;
 begin perform public.owner_capital_command(input||jsonb_build_object('request_id',gen_random_uuid(),'amount',5000,'reference','OWNER-003'));exception when others then rejected:=true;end;if not rejected then raise exception 'Excess capital return accepted.';end if;
 if (public.finance_operating_summary()->>'revenue')::numeric<>0 then raise exception 'Owner contribution recorded as income.';end if;
 if exists(select 1 from public.general_ledger_lines l join public.general_ledger_journals j on j.id=l.journal_id where j.source_type='OWNER_CAPITAL' group by j.id having sum(l.debit)<>sum(l.credit)) then raise exception 'Capital journal unbalanced.';end if;
 if has_function_privilege('anon','public.owner_capital_workspace(integer,uuid)','EXECUTE') then raise exception 'Public capital read exposed.';end if;
end $test$;
rollback;
