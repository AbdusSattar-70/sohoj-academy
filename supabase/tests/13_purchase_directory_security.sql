begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('94000000-0000-0000-0000-000000000001','directory-admin@example.test',now(),'{"full_name":"Directory Admin"}');
select public.bootstrap_admin('directory-admin@example.test','Directory Admin');
select set_config('request.jwt.claim.sub','94000000-0000-0000-0000-000000000001',true);
do $test$ declare payload jsonb;id_value uuid;row_value public.vendors;account uuid;token text;rejected boolean:=false;begin
 payload:=jsonb_build_object('kind','VENDOR','request_id',gen_random_uuid(),'name','Directory Supplier','is_active',true,'reason','Created verified supplier');id_value:=(public.purchase_directory_command(payload)->>'id')::uuid;perform public.purchase_directory_command(payload);
 select * into row_value from public.vendors where id=id_value;
 payload:=jsonb_build_object('kind','VENDOR','request_id',gen_random_uuid(),'id',id_value,'token',md5(to_jsonb(row_value)::text),'name','Directory Supplier Updated','is_active',false,'reason','Stopped new purchases with supplier');perform public.purchase_directory_command(payload);
 if (select is_active from public.vendors where id=id_value) then raise exception 'Supplier not inactive.';end if;
 begin perform public.purchase_directory_command(jsonb_set(payload,'{request_id}',to_jsonb(gen_random_uuid())));exception when others then rejected:=true;end;if not rejected then raise exception 'Stale supplier edit accepted.';end if;
 select id into account from public.finance_accounts where account_type='EXPENSE' and is_active limit 1;
 payload:=jsonb_build_object('kind','CATEGORY','request_id',gen_random_uuid(),'name','Fixture category','code','FIXTURE_CAT','expense_account_id',account,'is_active',true,'reason','Configured expense category');id_value:=(public.purchase_directory_command(payload)->>'id')::uuid;
 select md5(to_jsonb(c)::text) into token from public.finance_expense_categories c where id=id_value;
 payload:=payload||jsonb_build_object('request_id',gen_random_uuid(),'id',id_value,'token',token,'is_active',false);perform public.purchase_directory_command(payload);
 if (select is_active from public.finance_expense_categories where id=id_value) then raise exception 'Category not inactive.';end if;
 if has_function_privilege('anon','public.purchase_directory_command(jsonb)','EXECUTE') then raise exception 'Public directory mutation available.';end if;
end $test$;
rollback;
