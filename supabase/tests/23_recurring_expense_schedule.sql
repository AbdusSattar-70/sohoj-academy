begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('93000000-0000-0000-0000-000000000001','recurring-admin@example.test',now(),'{"full_name":"Admin"}');
select public.bootstrap_admin('recurring-admin@example.test','Admin');
select set_config('request.jwt.claim.sub','93000000-0000-0000-0000-000000000001',true);
do $test$
declare vendor uuid;category uuid;schedule_uuid uuid;input jsonb;res jsonb;mon date:=date_trunc('month',now() at time zone 'Asia/Dhaka')::date;pid uuid;rejected boolean:=false;
begin
 vendor:=(public.purchase_command(jsonb_build_object('action','CREATE_VENDOR','request_id',gen_random_uuid(),'name','Rent supplier','reason','Verified rent supplier'))->>'id')::uuid;select c.id into category from public.finance_expense_categories c where is_active limit 1;
 input:=jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'name','Monthly classroom rent','vendor_id',vendor,'category_id',category,'amount',10000,'first_month',mon,'due_day',10,'reason','Verified monthly rent agreement');schedule_uuid:=(public.recurring_expense_command(input)->>'id')::uuid;perform public.recurring_expense_command(input);
 input:=input||jsonb_build_object('request_id',gen_random_uuid(),'id',schedule_uuid,'revision',1,'amount',12000);perform public.recurring_expense_command(input);
 if (select amount from public.finance_recurring_expenses r where r.id=schedule_uuid)<>12000 then raise exception 'Schedule amount edit failed.';end if;
 input:=jsonb_build_object('action','GENERATE','request_id',gen_random_uuid(),'id',schedule_uuid,'month',mon,'reason','Prepared rent verification draft');res:=public.recurring_expense_command(input);perform public.recurring_expense_command(input);pid:=(res->>'purchaseId')::uuid;
 if (select total from public.finance_purchases where id=pid)<>12000 or exists(select 1 from public.general_ledger_journals where source_id=pid::text) then raise exception 'Wrong or posted recurring draft.';end if;
 begin perform public.recurring_expense_command(input||jsonb_build_object('request_id',gen_random_uuid()));exception when others then rejected:=true;end;if not rejected then raise exception 'Recurring month duplicate allowed.';end if;
 perform public.purchase_command(jsonb_build_object('action','CANCEL','request_id',gen_random_uuid(),'id',pid,'revision',1,'reason','Cancelled incorrect bill preparation'));
 perform public.recurring_expense_command(input||jsonb_build_object('request_id',gen_random_uuid()));
 if (select count(*) from public.finance_recurring_occurrences where schedule_id=schedule_uuid)<>2 then raise exception 'Replacement evidence missing.';end if;
 if (public.recurring_expense_workspace(mon)->>'total')::integer<>1 then raise exception 'Schedule retry duplicated register.';end if;
 perform public.recurring_expense_command(jsonb_build_object('action','SET_ACTIVE','request_id',gen_random_uuid(),'id',schedule_uuid,'revision',2,'is_active',false,'reason','Agreement no longer applies'));
 if (select is_active from public.finance_recurring_expenses r where r.id=schedule_uuid) then raise exception 'Inactivation failed.';end if;
 if has_function_privilege('anon','public.recurring_expense_command(jsonb)','EXECUTE') then raise exception 'Anonymous recurring mutation exposed.';end if;
end $test$;
rollback;
