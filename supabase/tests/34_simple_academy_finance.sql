-- Disposable database only. The transaction leaves no fixture records.
begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values('96000000-0000-0000-0000-000000000001','simple-finance-admin@example.test',now(),'{"full_name":"Simple Finance Admin"}');
select public.bootstrap_admin('simple-finance-admin@example.test','Simple Finance Admin');
select set_config('request.jwt.claim.sub','96000000-0000-0000-0000-000000000001',true);
do $test$
declare initial jsonb;w jsonb;p jsonb;cash uuid;cat uuid;cost uuid;day date:=(now() at time zone 'Asia/Dhaka')::date;rejected boolean;
begin
 initial:=public.simple_finance_workspace();
 cash:=(initial->'accounts'->0->>'id')::uuid;cat:=(initial->'categories'->0->>'id')::uuid;
 if cash is null or cat is null then raise exception 'Missing initial money sources/categories.';end if;
 p:=jsonb_build_object('request_id',gen_random_uuid(),'action','OWNER_FUNDS','reason','Verified initial owner cash','date',day,'amount','10000','account_id',cash,'description','Actual owner opening money');
 perform public.simple_finance_command(p);perform public.simple_finance_command(p);
 w:=public.simple_finance_workspace();
 if w->>'profit' is distinct from initial->>'profit' or w->>'collected' is distinct from initial->>'collected' then raise exception 'Owner money incorrectly counted as profit or operating receipts.';end if;
 if (select count(*) from public.academy_money_entries where created_by=auth.uid())<>1 then raise exception 'Owner funding retry duplicated.';end if;
 rejected:=false;begin perform public.simple_finance_command(p||'{"amount":"9000"}');exception when others then rejected:=true;end;
 if not rejected then raise exception 'Changed retry payload accepted.';end if;
 p:=jsonb_build_object('request_id',gen_random_uuid(),'action','OTHER_INCOME','reason','Verified workshop venue income','date',day,'amount','2000','account_id',cash,'description','Workshop venue income');
 perform public.simple_finance_command(p);perform public.simple_finance_command(p);
 p:=jsonb_build_object('request_id',gen_random_uuid(),'action','EXPENSE','reason','Verified incurred running cost','date',day,'amount','1000','category_id',cat,'description','Unpaid test running cost','payment_mode','ON_ACCOUNT');
 perform public.simple_finance_command(p);perform public.simple_finance_command(p);
 w:=public.simple_finance_workspace();
 if (w->>'profit')::numeric<>(initial->>'profit')::numeric+1000 or (w->>'costDue')::numeric<>(initial->>'costDue')::numeric+1000 then raise exception 'Income/unpaid expenses reported incorrectly.';end if;
 select payable_id into cost from public.finance_expenses where posted_by=auth.uid() and description='Unpaid test running cost';
 p:=jsonb_build_object('request_id',gen_random_uuid(),'action','PAY_COST','reason','Verified actual partial cost payment','amount','400','account_id',cash,'payable_id',cost);
 perform public.simple_finance_command(p);perform public.simple_finance_command(p);
 w:=public.simple_finance_workspace();
 if (w->>'profit')::numeric<>(initial->>'profit')::numeric+1000 or (w->>'expenses')::numeric<>(initial->>'expenses')::numeric+1000 or (w->>'costDue')::numeric<>(initial->>'costDue')::numeric+600 then raise exception 'Settlement doubled cost or duplicated payment.';end if;
 rejected:=false;begin perform public.simple_finance_command(p||jsonb_build_object('request_id',gen_random_uuid(),'amount','700'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Cost overpayment accepted.';end if;
 rejected:=false;begin perform public.simple_finance_command(jsonb_build_object('request_id',gen_random_uuid(),'action','OTHER_INCOME','reason','Reject invalid amount','date',day,'amount','NaN','account_id',cash,'description','Invalid income'));exception when others then rejected:=true;end;
 if not rejected then raise exception 'Nonfinite income accepted.';end if;
 if (public.simple_finance_workspace(null,2)->>'profit') is distinct from w->>'profit' then raise exception 'Totals depend on page.';end if;
 if jsonb_array_length(public.simple_finance_workspace(null,1,'Unpaid test running cost')->'rows')<>1 then raise exception 'Expense search failed.';end if;
 if has_table_privilege('authenticated','public.academy_money_entries','INSERT') or has_table_privilege('authenticated','public.academy_operating_lines','SELECT') or has_function_privilege('anon','public.simple_finance_command(jsonb)','EXECUTE') then raise exception 'Private financial boundary exposed.';end if;
end $test$;
select set_config('request.jwt.claim.sub','',true);
do $test$
declare rejected boolean:=false;
begin
 begin perform public.simple_finance_workspace();exception when others then rejected:=true;end;
 if not rejected then raise exception 'Anonymous finance read accepted.';end if;
end $test$;
rollback;
