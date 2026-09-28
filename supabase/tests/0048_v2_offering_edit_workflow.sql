-- Lifecycle, idempotency and audit coverage for Programme Offering edits.
begin;
do $$
declare
 actor uuid:=gen_random_uuid(); org uuid; branch_id uuid; year_id uuid; next_year_id uuid;
 class_id uuid; program_id uuid; offering_id uuid; request_id uuid:=gen_random_uuid();
 result jsonb; event_count integer; today date;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(actor,'offering-edit-'||actor||'@example.invalid','{"full_name":"Offering Edit Test"}');
 perform public.bootstrap_admin('offering-edit-'||actor||'@example.invalid','Offering Edit Test');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id,(now() at time zone timezone)::date into org,today from public.organizations where code='SOHOJ';
 select id into branch_id from public.branches where organization_id=org and is_active limit 1;
 select id into class_id from public.classes where organization_id=org and is_active limit 1;
 select id into program_id from public.programs where organization_id=org and is_active limit 1;
 select id into year_id from public.academic_years where organization_id=org order by starts_on desc limit 1;
 if org is null or branch_id is null or year_id is null or class_id is null or program_id is null then raise exception 'Seeded academic master data is required.'; end if;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active) values(org,'OFFER-EDIT-'||left(actor::text,8),today,today+364,true) returning id into next_year_id;
 result:=public.create_programme_offering(jsonb_build_object('branch_id',branch_id,'academic_year_id',year_id,'class_id',class_id,'program_id',program_id,'code','OFFER-'||left(actor::text,8),'name','Offering Before Edit','reason','Create offering edit test'));
 offering_id:=(result->>'offering_id')::uuid;
 result:=public.update_programme_offering(jsonb_build_object('offering_id',offering_id,'request_id',request_id,'branch_id',branch_id,'academic_year_id',next_year_id,'class_id',class_id,'program_id',program_id,'group_id',null,'code','OFFER-'||left(actor::text,8)||'-EDIT','name','Offering After Edit','reason','Correct draft offering identity'));
 if result->>'offering_id'<>offering_id::text then raise exception 'Draft update returned wrong identity'; end if;
 select count(*) into event_count from public.audit_events where entity_type='PROGRAMME_OFFERING' and entity_id=offering_id::text and action='UPDATE';
 if event_count<>1 then raise exception 'Edit should create one audit event'; end if;
 perform public.update_programme_offering(jsonb_build_object('offering_id',offering_id,'request_id',request_id,'branch_id',branch_id,'academic_year_id',next_year_id,'class_id',class_id,'program_id',program_id,'group_id',null,'code','OFFER-'||left(actor::text,8)||'-EDIT','name','Offering After Edit','reason','Correct draft offering identity'));
 select count(*) into event_count from public.audit_events where entity_type='PROGRAMME_OFFERING' and entity_id=offering_id::text and action='UPDATE';
 if event_count<>1 then raise exception 'Idempotent retry duplicated audit history'; end if;
 perform public.publish_fee_plan(jsonb_build_object('offering_id',offering_id,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Activate offering edit test','components','[{"code":"TUITION","name":"Tuition","amount":1000,"charge_type":"TUITION","recurrence":"PER_CYCLE"}]'::jsonb));
 perform public.update_programme_offering(jsonb_build_object('offering_id',offering_id,'request_id',gen_random_uuid(),'branch_id',branch_id,'academic_year_id',next_year_id,'class_id',class_id,'program_id',program_id,'group_id',null,'code','OFFER-'||left(actor::text,8)||'-LIVE','name','Active Offering Renamed','reason','Correct staff facing offering name'));
 if not exists(select 1 from public.programme_offerings where id=offering_id and name='Active Offering Renamed') then raise exception 'Active code/name edit did not persist'; end if;
 begin
  perform public.update_programme_offering(jsonb_build_object('offering_id',offering_id,'request_id',gen_random_uuid(),'branch_id',branch_id,'academic_year_id',year_id,'class_id',class_id,'program_id',program_id,'group_id',null,'code','OFFER-'||left(actor::text,8)||'-BAD','name','Wrong Academic Context','reason','Try changing active academic context'));
  raise exception 'Active academic context edit was accepted';
 exception when others then
  if position('Academic context cannot change after activation' in sqlerrm)=0 then raise; end if;
 end;
end $$;
rollback;
