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
declare account uuid;equity uuid;org uuid;cid uuid;counter_account uuid;sid uuid;shift_value uuid;payload jsonb;count_id uuid;preview jsonb;denoms jsonb;day date:=(now() at time zone 'Asia/Dhaka')::date;
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
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
 preview:=public.daily_close_preview(counter_account,(now() at time zone 'Asia/Dhaka')::date);
 select jsonb_agg(jsonb_build_object('value',n,'count',case when n=1000 then 1 else 0 end)) into denoms from unnest(array[1000,500,200,100,50,20,10,5,2,1]) n;
 count_id:=(public.daily_close_command(jsonb_build_object('action','COUNT','request_id','c0000000-0000-0000-0000-000000000006','account_id',counter_account,'date',(now() at time zone 'Asia/Dhaka')::date,'actual',1000,'denominations',denoms,'preview_token',preview->>'token','statement_reference','Counter count sheet','reason','Confirmed actual closing cash'))->>'id')::uuid;
 perform public.cash_counter_command(jsonb_build_object('action','CLOSE','request_id','c0000000-0000-0000-0000-000000000007','counter_id',cid,'close_id',count_id,'reason','Verified closing count and ended duty'));
 if not exists(select 1 from public.finance_counter_shifts where id=shift_value and closed_at is not null) then raise exception 'Duty not closed';end if;
 begin perform public.finance_post_journal(org,day,'MANUAL','COUNTER_TEST','closed-write','Rejected closed counter write',auth.uid(),jsonb_build_array(jsonb_build_object('account_id',counter_account,'debit',10,'credit',0),jsonb_build_object('account_id',equity,'debit',0,'credit',10)));raise exception 'Closed counter posting accepted';exception when others then if sqlerrm='Closed counter posting accepted' then raise;end if;end;
 if exists(select 1 from public.payment_methods pm join public.finance_cash_counters cc on cc.payment_method_id=pm.id where cc.id=cid and pm.is_active) then raise exception 'Closed counter collection enabled';end if;
 if public.finance_account_balance(counter_account,day)<>1000 then raise exception 'Closing changed cash';end if;
 if has_function_privilege('authenticated','public.finance_post_journal_engine(uuid,date,text,text,text,text,uuid,jsonb)','execute') then raise exception 'Internal journal engine callable';end if;
end $test$;


-- Historical fixture rows exercise pagination without posting extra money.
do $test$
declare cid uuid;account uuid;sid uuid;other_staff uuid;close_value uuid;shift_value uuid;own_shift uuid;i integer;j integer;day date:=(now() at time zone 'Asia/Dhaka')::date;report jsonb;rejected boolean:=false;
begin
 select id,account_id into cid,account from public.finance_cash_counters limit 1;select id into sid from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 insert into public.staff(full_name,status,created_by) values('Other history cashier','ACTIVE',auth.uid()) returning id into other_staff;
 for i in 1..27 loop
  insert into public.finance_daily_closes(account_id,close_date,opening,receipts,payments,expected,actual,variance,ledger_token,statement_reference,explanation,recorded_by) values(account,day-i,0,0,0,0,0,0,'fixture historical count','Historical count fixture','Pagination evidence fixture',auth.uid()) returning id into close_value;
  insert into public.finance_counter_shifts(counter_id,staff_id,work_date,opening_balance,float_amount,opened_by,reason,opened_at,closed_at,close_id,closed_by) values(cid,case when i=27 then other_staff else sid end,day-i,0,0,auth.uid(),'Historical duty fixture',now()-interval '2 hours',now(),close_value,auth.uid()) returning id into shift_value;
  if i=1 then own_shift:=shift_value;for j in 1..26 loop insert into public.finance_counter_receipts(shift_id,actor_id,outcome,counted_amount,reason) values(shift_value,'92000000-0000-0000-0000-000000000002','DISPUTED',1,'Historical disputed count fixture');end loop;insert into public.finance_counter_receipts(shift_id,actor_id,outcome,counted_amount,reason) values(shift_value,'92000000-0000-0000-0000-000000000002','RECEIVED',0,'Historical matching recount fixture');end if;
 end loop;
 report:=public.cash_counter_history(cid);if (report->>'total')::integer<>28 or jsonb_array_length(report->'rows')<>25 or jsonb_array_length(public.cash_counter_history(cid,2)->'rows')<>3 then raise exception 'Duty pagination/count failed.';end if;
 if (public.cash_counter_history(cid,1,day-2,day-1)->>'total')::int<>2 then raise exception 'Date filter failed.';end if;
 if jsonb_array_length(public.cash_counter_history(cid,1,null,null,own_shift)->'rows')<>25 or jsonb_array_length(public.cash_counter_history(cid,2,null,null,own_shift)->'rows')<>2 then raise exception 'Receipt pagination failed.';end if;
 if jsonb_array_length((select x->'shifts'->0->'receipts' from jsonb_array_elements(public.cash_counter_workspace()->'records')x where x->>'id'=cid::text))>25 then raise exception 'Operational snapshot receipt bound failed.';end if;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 report:=public.cash_counter_history(cid);if (report->>'total')::int<>27 or exists(select 1 from jsonb_array_elements(report->'rows')x where x->>'cashier'='Other history cashier') then raise exception 'Staff duty history scope failed.';end if;
 begin perform public.cash_counter_history(cid,1,null,null,shift_value);exception when others then rejected:=true;end;if not rejected then raise exception 'Staff read another cashier receipt history.';end if;
 perform set_config('request.jwt.claim.sub','',true);rejected:=false;begin perform public.cash_counter_history(cid);exception when others then rejected:=true;end;if not rejected then raise exception 'Public read duty history.';end if;
 if has_function_privilege('anon','public.cash_counter_history(uuid,integer,date,date,uuid)','EXECUTE') then raise exception 'Public duty history privilege exposed.';end if;
end $test$;
rollback;
