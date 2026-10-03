begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('95000000-0000-0000-0000-000000000001','stock-admin@example.test',now(),'{"full_name":"Admin"}'),('95000000-0000-0000-0000-000000000002','stock-outsider@example.test',now(),'{"full_name":"Outsider"}');
select public.bootstrap_admin('stock-admin@example.test','Admin');select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',true);
do $test$
declare id uuid;payload jsonb;row_value jsonb;journals integer;rejected boolean:=false;
begin
 select count(*) into journals from public.general_ledger_journals;
 id:=(public.consumable_command(jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'name','Whiteboard markers','unit','PIECE','reorder_level',5,'is_active',true,'reason','Track classroom supplies'))->>'id')::uuid;
 payload:=jsonb_build_object('action','RECEIPT','request_id',gen_random_uuid(),'id',id,'expected_order',0,'quantity',12,'reference','Delivery note 001','confirmed',true,'reason','Actually received twelve markers');perform public.consumable_command(payload);perform public.consumable_command(payload);
 row_value:=public.consumable_workspace()->'rows'->0;if (row_value->>'stock')::numeric<>12 then raise exception 'Receipt retry doubled stock.';end if;
 begin perform public.consumable_command(payload||jsonb_build_object('request_id',gen_random_uuid(),'quantity',3));exception when others then rejected:=true;end;if not rejected then raise exception 'Stale stock receipt accepted.';end if;
 payload:=payload||jsonb_build_object('request_id',gen_random_uuid(),'action','ISSUE','expected_order',row_value->'expected_order','quantity',15);rejected:=false;begin perform public.consumable_command(payload);exception when others then rejected:=true;end;if not rejected then raise exception 'Negative stock accepted.';end if;
 perform public.consumable_command(payload||jsonb_build_object('request_id',gen_random_uuid(),'quantity',4));row_value:=public.consumable_workspace()->'rows'->0;
 perform public.consumable_command(payload||jsonb_build_object('request_id',gen_random_uuid(),'action','COUNT','quantity',7,'expected_order',row_value->'expected_order','reference','Physical count 001'));row_value:=public.consumable_workspace()->'rows'->0;
 if (row_value->>'stock')::numeric<>7 or (select count(*) from public.consumable_movements)<>3 or (select count(*) from public.general_ledger_journals)<>journals then raise exception 'Count append or no-double-expense invariant failed.';end if;
 rejected:=false;begin perform public.consumable_command(jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'id',id,'revision',1,'name','Whiteboard markers','unit','BOX','reorder_level',5,'is_active',true,'reason','Attempt unit change'));exception when others then rejected:=true;end;if not rejected then raise exception 'Historical unit changed.';end if;
 if has_function_privilege('anon','public.consumable_command(jsonb)','EXECUTE') then raise exception 'Public stock mutation exposed.';end if;
end $test$;
select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000002',true);
do $test$ declare rejected boolean:=false;begin begin perform public.consumable_workspace();exception when others then rejected:=true;end;if not rejected then raise exception 'Outsider read stock.';end if;end $test$;
rollback;
