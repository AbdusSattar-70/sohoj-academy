begin;
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values('95000000-0000-0000-0000-000000000001','evidence-admin@example.test',now(),'{"full_name":"Evidence Admin"}'),('95000000-0000-0000-0000-000000000002','evidence-outsider@example.test',now(),'{"full_name":"Evidence Outsider"}');
select public.bootstrap_admin('evidence-admin@example.test','Evidence Admin');
select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000001',true);
do $test$ declare org uuid;vendor uuid;category uuid;purchase uuid;ticket uuid:=gen_random_uuid();payload jsonb;prepared jsonb;rejected boolean:=false;begin
 select id into org from public.organizations where code='SOHOJ';select id into category from public.finance_expense_categories where is_active limit 1;
 vendor:=(public.purchase_command(jsonb_build_object('action','CREATE_VENDOR','request_id',gen_random_uuid(),'name','Evidence Supplier','reason','Verified evidence supplier'))->>'id')::uuid;
 purchase:=(public.purchase_command(jsonb_build_object('action','SAVE','request_id',gen_random_uuid(),'vendor_id',vendor,'category_id',category,'description','Purchase with document','items',jsonb_build_array(jsonb_build_object('name','Supplies','quantity',1,'price',100)),'reason','Preparing documented expense'))->>'id')::uuid;
 payload:=jsonb_build_object('request_id',ticket,'entity_type','PURCHASE','entity_id',purchase,'original_name','invoice.pdf','mime_type','application/pdf','byte_size',100,'sha256',repeat('a',64),'note','Supplier invoice evidence');prepared:=public.finance_document_prepare(payload);perform public.finance_document_prepare(payload);
 begin perform public.finance_document_complete(ticket);exception when others then rejected:=true;end;if not rejected then raise exception 'Missing storage file finalized.';end if;
 insert into storage.objects(bucket_id,name,metadata) values('finance-evidence',prepared->>'path','{"size":100,"mimetype":"application/pdf"}');
 perform public.finance_document_complete(ticket);perform public.finance_document_complete(ticket);
 if jsonb_array_length(public.finance_document_workspace('PURCHASE',purchase))<>1 then raise exception 'Upload retry duplicated evidence.';end if;
 rejected:=false;begin update public.finance_documents set note='Overwrite' where id=ticket;exception when others then rejected:=true;end;if not rejected then raise exception 'Ready evidence mutable.';end if;
 if not public.finance_document_storage_allowed(prepared->>'path',false) or public.finance_document_storage_allowed(prepared->>'path',true) then raise exception 'Ready storage permissions incorrect.';end if;
 if has_function_privilege('anon','public.finance_document_prepare(jsonb)','EXECUTE') then raise exception 'Public upload tickets exposed.';end if;
end $test$;
set local role authenticated;
do $test$ declare rejected boolean:=false;begin
 if (select count(*) from storage.objects where bucket_id='finance-evidence')<>1 then raise exception 'Manager cannot read evidence.';end if;
 begin insert into storage.objects(bucket_id,name,metadata) values('finance-evidence','unapproved/path.pdf','{}');exception when others then rejected:=true;end;if not rejected then raise exception 'Unticketed storage upload allowed.';end if;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','95000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $test$ begin if exists(select 1 from storage.objects where bucket_id='finance-evidence') then raise exception 'Outsider read private evidence.';end if;end $test$;
reset role;
rollback;
