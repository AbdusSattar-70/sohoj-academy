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
 if has_function_privilege('anon' ,'public.review_staff_access(jsonb)','EXECUTE') then raise exception 'Anonymous user may review access.'; end if;
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

select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
do $test$
declare account uuid;equity uuid;org uuid;cid uuid;counter_account uuid;sid uuid;shift_value uuid;payload jsonb;count_id uuid;preview jsonb;denoms jsonb;transfer_payload jsonb;tid uuid;day date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 select id,organization_id into account,org from public.finance_accounts where account_subtype='CASH' limit 1;
 select id into equity from public.finance_accounts where account_subtype='RETAINED_EARNINGS' limit 1;
 select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 perform public.finance_post_journal(org,day,'MANUAL','COUNTER_TEST','seed','Opening test funds',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',account,'debit',5000,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',5000)));
 cid:=(public.cash_counter_command(jsonb_build_object('action','CREATE','request_id','c0000000-0000-0000-0000-000000000001','name','Front desk counter','reason','Registered front desk cash counter'))->>'id')::uuid;
 select account_id into counter_account from public.finance_cash_counters where id=cid;
 payload:=jsonb_build_object('action','OPEN','request_id','c0000000-0000-0000-0000-000000000002','counter_id',cid,'staff_id',sid,'amount',1000,'source_account_id',account,'reason','Delivered actual opening cash funds');
 begin perform public.cash_counter_command(payload||jsonb_build_object('request_id',gen_random_uuid(),'amount',6000));raise exception 'Excess float accepted';exception when others then if sqlerrm='Excess float accepted' then raise;end if;end;
 shift_value:=(public.cash_counter_command(payload)->>'id')::uuid;perform public.cash_counter_command(payload);
 if public.finance_account_balance(account,day)<>4000 or public.finance_account_balance(counter_account,day)<>1000 then raise exception 'Float transfer wrong or duplicated';end if;
 begin perform public.cash_counter_command(payload||jsonb_build_object('request_id','c0000000-0000-0000-0000-000000000003'));raise exception 'Duplicate shift accepted';exception when others then if sqlerrm='Duplicate shift accepted' then raise;end if;end;
 begin perform public.cash_counter_command(jsonb_build_object('action','EDIT','request_id',gen_random_uuid(),'counter_id',cid,'name','Closed counter','revision',1,'is_active',false,'reason','Attempt inactivation with open duty'));raise exception 'Open counter inactivated';exception when others then if sqlerrm='Open counter inactivated' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 if not exists(select 1 from jsonb_array_elements(public.cash_counter_workspace()->'records') r where r->>'id'=cid::text) then raise exception 'Cashier own counter missing';end if;
 begin perform public.cash_counter_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'name','Teacher counter','reason','Unauthorized counter creation'));raise exception 'Teacher created counter';exception when others then if sqlerrm='Teacher created counter' then raise;end if;end;
 perform public.cash_counter_command(jsonb_build_object('action','RECEIVE','request_id','c0000000-0000-0000-0000-000000000004','shift_id',shift_value,'amount',900,'outcome','DISPUTED','reason','Opening physical count was short'));
 perform public.cash_counter_command(jsonb_build_object('action','RECEIVE','request_id','c0000000-0000-0000-0000-000000000005','shift_id',shift_value,'amount',1000,'outcome','RECEIVED','reason','Recount found all delivered cash'));
 if (select count(*) from public.finance_counter_receipts where finance_counter_receipts.shift_id=shift_value)<>2 then raise exception 'Dispute evidence lost';end if;

 begin perform public.counter_transfer_command(jsonb_build_object('action','TOPUP','request_id',gen_random_uuid(),'counter_id',cid,'other_account_id',account,'amount',500,'reference','Teacher topup','actual_confirmed',true,'reason','Unauthorized worker transfer'));raise exception 'Worker created topup';exception when others then if sqlerrm='Worker created topup' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
 transfer_payload:=jsonb_build_object('action','TOPUP','request_id','d0000000-0000-0000-0000-000000000001','counter_id',cid,'other_account_id',account,'amount',500,'reference','TOPUP-001','actual_confirmed',true,'reason','Delivered actual additional counter cash');
 tid:=(public.counter_transfer_command(transfer_payload)->>'id')::uuid;perform public.counter_transfer_command(transfer_payload);
 if public.finance_account_balance(account,day)<>3500 or public.finance_account_balance(counter_account,day)<>1500 then raise exception 'Topup duplicated or wrong balances';end if;
 if exists(select 1 from public.payment_methods pm join public.finance_cash_counters cc on cc.payment_method_id=pm.id where cc.id=cid and pm.is_active) then raise exception 'Unreceived topup left collections enabled';end if;
 begin perform public.finance_post_journal(org,day,'MANUAL','COUNTER_TEST','pending-write','Pending cash blocked',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',counter_account,'debit',10,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',10)));raise exception 'Pending counter posting accepted';exception when others then if sqlerrm='Pending counter posting accepted' then raise;end if;end;
 begin perform public.cash_counter_command(jsonb_build_object('action','CLOSE','request_id',gen_random_uuid(),'counter_id',cid,'close_id',gen_random_uuid(),'reason','Attempt closing unreceived topup'));raise exception 'Pending counter closed';exception when others then if sqlerrm='Pending counter closed' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 perform public.counter_transfer_command(jsonb_build_object('action','RECEIVE','request_id','d0000000-0000-0000-0000-000000000002','transfer_id',tid,'amount',400,'outcome','DISPUTED','reason','Additional delivery count was short'));
 transfer_payload:=jsonb_build_object('action','RECEIVE','request_id','d0000000-0000-0000-0000-000000000003','transfer_id',tid,'amount',500,'outcome','RECEIVED','reason','Recount confirmed complete additional cash');
 perform public.counter_transfer_command(transfer_payload);perform public.counter_transfer_command(transfer_payload);
 if (select count(*) from public.finance_counter_transfer_receipts where transfer_id=tid)<>2 then raise exception 'Receipt retry duplicated or dispute lost';end if;
 if (public.counter_transfer_workspace(1,array[cid])->>'total')::int<>1 then raise exception 'Own transfer missing';end if;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
 preview:=public.daily_close_preview(counter_account,day);
 select jsonb_agg(jsonb_build_object('value',n,'count',case when n in(1000,500) then 1 else 0 end)) into denoms from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
 count_id:=(public.daily_close_command(jsonb_build_object('action','COUNT','request_id','d0000000-0000-0000-0000-000000000004','account_id',counter_account,'date',day,'actual',1500,'denominations',denoms,'preview_token',preview->>'token','statement_reference','Counter 1500 count','reason','Confirmed actual closing cash'))->>'id')::uuid;
 perform public.cash_counter_command(jsonb_build_object('action','CLOSE','request_id','d0000000-0000-0000-0000-000000000005','counter_id',cid,'close_id',count_id,'reason','Verified count and closed counter'));
 transfer_payload:=jsonb_build_object('action','RETURN','request_id','d0000000-0000-0000-0000-000000000006','counter_id',cid,'other_account_id',account,'amount',400,'close_id',count_id,'reference','RETURN-001','actual_confirmed',true,'reason','Received actual counter cash into main cash');
 begin perform public.counter_transfer_command(transfer_payload||jsonb_build_object('request_id',gen_random_uuid(),'amount',1501));raise exception 'Excess return accepted';exception when others then if sqlerrm='Excess return accepted' then raise;end if;end;
 perform public.counter_transfer_command(transfer_payload);perform public.counter_transfer_command(transfer_payload);
 if public.finance_account_balance(account,day)<>3900 or public.finance_account_balance(counter_account,day)<>1100 then raise exception 'Return duplicated or wrong balances';end if;
 begin perform public.counter_transfer_command(transfer_payload||jsonb_build_object('request_id',gen_random_uuid(),'reference','RETURN-STALE'));raise exception 'Stale count accepted for return';exception when others then if sqlerrm='Stale count accepted for return' then raise;end if;end;
 preview:=public.daily_close_preview(counter_account,day);
 select jsonb_agg(jsonb_build_object('value',n,'count',case when n in(1000,100) then 1 else 0 end)) into denoms from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
 count_id:=(public.daily_close_command(jsonb_build_object('action','COUNT','request_id','d0000000-0000-0000-0000-000000000007','account_id',counter_account,'date',day,'actual',1100,'denominations',denoms,'preview_token',preview->>'token','statement_reference','Counter 1100 count','reason','Verified remainder before second return'))->>'id')::uuid;
 perform public.counter_transfer_command(transfer_payload||jsonb_build_object('request_id','d0000000-0000-0000-0000-000000000008','reference','RETURN-002','amount',1000,'close_id',count_id));
 if public.finance_account_balance(counter_account,day)<>100 or public.finance_account_balance(account,day)<>4900 then raise exception 'Carry-forward cash incorrect';end if;
 if public.finance_account_balance(equity,day)<>5000 then raise exception 'Transfers changed equity or created profit';end if;
 if has_function_privilege('authenticated','public.cash_counter_base_command(jsonb)','execute') or has_function_privilege('anon','public.counter_transfer_command(jsonb)','execute') then raise exception 'Internal or anonymous transfer access';end if;
end $test$;
rollback;
