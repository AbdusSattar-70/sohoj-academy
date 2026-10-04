begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('94000000-0000-0000-0000-000000000001','year-admin@example.test',now(),'{"full_name":"Year Admin"}');
select public.bootstrap_admin('year-admin@example.test','Year Admin');select set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
do $test$
declare org uuid;cash uuid;income uuid;start_date date:=(date_trunc('year',current_date)-interval '1 year')::date;last_month date;last_day date;mon date;a record;preview jsonb;counts jsonb;payload jsonb;rejected boolean:=false;
begin
 last_month:=(start_date+interval '11 months')::date;last_day:=(last_month+interval '1 month - 1 day')::date;
 select id into org from public.organizations where code='SOHOJ';select id into cash from public.finance_accounts where account_subtype='CASH' limit 1;select id into income from public.finance_accounts where account_subtype='TUITION_REVENUE' limit 1;
 perform public.finance_post_journal(org,last_day,'MANUAL','YEAR_TEST',gen_random_uuid()::text,'Prior year income',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',cash,'debit',500,'credit',0),jsonb_build_object('account_id',income,'debit',0,'credit',500)));
 for mon in select m::date from generate_series(start_date::timestamp,(last_month-interval '1 month')::timestamp,interval '1 month')m loop insert into public.finance_period_events(month,action,snapshot,actor_id,reason) values(mon,'CLOSE','{}',auth.uid(),'Fixture prior empty month');end loop;
 for a in select * from public.finance_accounts where is_active and account_subtype in('CASH','BANK','MOBILE_BANK') loop
  preview:=public.daily_close_preview(a.id,last_day);
  select jsonb_agg(jsonb_build_object('value',n,'count',case when a.id=cash and n=100 then 5 else 0 end)) into counts from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
  perform public.daily_close_command(jsonb_build_object('action','COUNT','request_id',gen_random_uuid(),'account_id',a.id,'date',last_day,'actual',preview->'expected','denominations',counts,'preview_token',preview->>'token','statement_reference','Month-end verification','reason','Verified actual month-end cash and statements','variance_note',''));
 end loop;
 preview:=public.fiscal_year_preview(start_date);payload:=jsonb_build_object('action','CLOSE','start',start_date,'request_id',gen_random_uuid(),'preview_token',preview->>'token','reason','Reviewed complete fiscal year evidence');perform public.fiscal_year_command(payload);perform public.fiscal_year_command(payload);
 if public.finance_account_balance(income)<>0 or (public.monthly_financial_report(last_month)->>'profit')::numeric<>500 then raise exception 'Closing erased operating earnings or failed nominal transfer.';end if;
 if (select count(*) from public.finance_year_events)<>1 then raise exception 'Retry duplicated closing.';end if;
 begin perform public.finance_period_command(jsonb_build_object('action','REOPEN','month',last_month,'request_id',gen_random_uuid(),'reason','Attempt independent month reopening'));exception when others then rejected:=true;end;if not rejected then raise exception 'Closed year month reopened independently.';end if;
 preview:=public.fiscal_year_preview(start_date);payload:=jsonb_build_object('action','REOPEN','start',start_date,'request_id',gen_random_uuid(),'preview_token',preview->>'token','reason','Correct documented prior year evidence');perform public.fiscal_year_command(payload);perform public.fiscal_year_command(payload);
 if abs(public.finance_account_balance(income))<>500 or (select count(*) from public.finance_year_events)<>2 then raise exception 'Year reversal/retry failed.';end if;
 if has_function_privilege('anon','public.fiscal_year_command(jsonb)','EXECUTE') then raise exception 'Public year close exposed.';end if;
end $test$;
rollback;
