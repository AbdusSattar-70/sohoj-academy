begin;
do $$
declare
 actor uuid:=gen_random_uuid(); org uuid; branch uuid; class_id uuid; program_id uuid; year_id uuid;
 offering_id uuid; batch_id uuid; result jsonb; view_data jsonb; today date; max_capacity integer;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(actor,
  'batch-register-'||actor||'@example.invalid','{"full_name":"Batch Register Test"}');
 perform public.bootstrap_admin('batch-register-'||actor||'@example.invalid','Batch Register Test');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into class_id from public.classes where organization_id=org and code='CLASS_10';
 select id into program_id from public.programs where organization_id=org limit 1;
 select (payload->>'max_students')::integer into max_capacity from public.business_rule_versions
  where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE';
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
  values(org,'BATCH-'||actor,today,today+365,true) returning id into year_id;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',year_id,
  'class_id',class_id,'program_id',program_id,'code','BATCH-'||left(actor::text,8),
  'name','Batch Register Test Offering','reason','Batch workflow regression test'));
 offering_id:=(result->>'offering_id')::uuid;
 perform public.publish_fee_plan(jsonb_build_object('offering_id',offering_id,'billing_cycle','MONTHLY',
  'due_day',10,'effective_from',today,'reason','Publish batch test fees',
  'components','[{"code":"TUITION","name":"Tuition","amount":1000,"charge_type":"TUITION","recurrence":"PER_CYCLE"}]'::jsonb));
 result:=public.batch_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),
  'reason','Create a morning cohort','offering_id',offering_id,'code','BATCH-'||left(actor::text,8),
  'name','Morning A (7:30 am to 9:30 am)','capacity',least(max_capacity,12)));
 batch_id:=(result->>'id')::uuid;
 if batch_id is null or result->>'status'<>'CREATED' then raise exception 'Batch creation did not return identity'; end if;
 result:=public.batch_command(jsonb_build_object('action','EDIT_BATCH','request_id',gen_random_uuid(),
  'reason','Update cohort display and seat capacity','batch_id',batch_id,
  'code','BATCH-'||left(actor::text,8)||'-A','name','Morning A · Updated','capacity',least(max_capacity,11)));
 if result->>'status'<>'UPDATED' then raise exception 'Batch edit did not succeed'; end if;
 if not exists(select 1 from public.batches where id=batch_id and name='Morning A · Updated'
   and capacity=least(max_capacity,11)) then raise exception 'Batch changes were not persisted'; end if;
 if not exists(select 1 from public.audit_events where entity_type='BATCH' and entity_id=batch_id::text
   and action='EDIT_BATCH' and before_data->>'name'='Morning A (7:30 am to 9:30 am)'
   and after_data->>'name'='Morning A · Updated') then raise exception 'Batch edit audit snapshot is incorrect'; end if;
 begin
  perform public.batch_command(jsonb_build_object('action','EDIT_BATCH','request_id',gen_random_uuid(),
   'reason','Reject oversized batch','batch_id',batch_id,'code','OVERSIZED','name','Too large',
   'capacity',max_capacity+1));
  raise exception 'Policy limit was bypassed';
 exception when others then
  if position('policy maximum' in sqlerrm)=0 then raise; end if;
 end;
 view_data:=public.admission_workspace();
 if not exists(select 1 from jsonb_array_elements(view_data->'batches') b
   where b->>'id'=batch_id::text and b->>'offeringName'='Batch Register Test Offering'
   and b->>'yearName'='BATCH-'||actor::text and b->>'name'='Morning A · Updated') then
   raise exception 'Batch register context fields are incomplete'; end if;
end $$;
rollback;
