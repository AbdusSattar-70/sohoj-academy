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
declare account uuid; receiver uuid; cid uuid; payload jsonb; result jsonb;
begin
 select id into account from public.finance_accounts where account_subtype='CASH' limit 1;
 select id into receiver from public.staff where profile_id='92000000-0000-0000-0000-000000000002';
 if not exists(select 1 from jsonb_array_elements(public.cash_handover_recipients()) r where r->>'id'=receiver::text) then raise exception 'Linked receiver not offered';end if;
 insert into public.finance_daily_closes(account_id,close_date,opening,receipts,payments,expected,actual,variance,ledger_token,statement_reference,explanation,handed_to,recorded_by)
 values(account,current_date,100,0,0,100,100,0,'test-token','Test cash count','Test handover',receiver,auth.uid()) returning id into cid;
 payload:=jsonb_build_object('request_id','b0000000-0000-0000-0000-000000000001','close_id',cid,'outcome','RECEIVED','counted_amount',100,'reason','Counted and received all cash');
 begin perform public.cash_handover_command(payload);raise exception 'Sender confirmation accepted';exception when others then if sqlerrm='Sender confirmation accepted' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 if (public.cash_handover_workspace()->>'total')::integer<>1 then raise exception 'Own handover missing';end if;
 begin perform public.cash_handover_command(payload||jsonb_build_object('counted_amount',90));raise exception 'Mismatch received accepted';exception when others then if sqlerrm='Mismatch received accepted' then raise;end if;end;
 result:=public.cash_handover_command(payload||jsonb_build_object('outcome','DISPUTED','counted_amount',90));
 perform public.cash_handover_command(payload||jsonb_build_object('outcome','DISPUTED','counted_amount',90));
 if (select count(*) from public.finance_handover_receipts where close_id=cid)<>1 then raise exception 'Retry duplicated receipt';end if;
 if (select actual from public.finance_daily_closes where id=cid)<>100 then raise exception 'Receipt changed original count';end if;
 begin perform public.cash_handover_command(payload||jsonb_build_object('request_id','b0000000-0000-0000-0000-000000000002'));raise exception 'Second receipt accepted';exception when others then if sqlerrm='Second receipt accepted' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
 insert into public.finance_daily_closes(account_id,close_date,opening,receipts,payments,expected,actual,variance,ledger_token,statement_reference,explanation,recorded_by)
 values(account,current_date,0,0,0,0,0,0,'another','Other count','No recipient',auth.uid());
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 if (public.cash_handover_workspace()->>'total')::integer<>1 then raise exception 'Staff saw unrelated closes';end if;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
 insert into public.finance_daily_closes(account_id,close_date,opening,receipts,payments,expected,actual,variance,ledger_token,statement_reference,explanation,handed_to,recorded_by)
 values(account,current_date,200,0,0,200,200,0,'received-test','Second cash count','Second handover',receiver,auth.uid()) returning id into cid;
 perform set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000002',true);
 payload:=jsonb_build_object('request_id','b0000000-0000-0000-0000-000000000003','close_id',cid,'outcome','RECEIVED','counted_amount',200,'reason','Counted and received all cash');
 perform public.cash_handover_command(payload);
 if not exists(select 1 from public.finance_handover_receipts where close_id=cid and outcome='RECEIVED') then raise exception 'Matching receipt missing';end if;
 begin update public.finance_handover_receipts set counted_amount=199 where close_id=cid;raise exception 'Immutable receipt edited';exception when others then if sqlerrm='Immutable receipt edited' then raise;end if;end;
 if has_function_privilege('anon' ,'public.cash_handover_command(jsonb)','execute') then raise exception 'Anonymous receipt access';end if;
end $test$;
rollback;
