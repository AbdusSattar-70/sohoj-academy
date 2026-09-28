-- Rollback-only metadata receipt test. Storage service upload/download is a live gate.
begin;
do $$
declare
 actor uuid := gen_random_uuid(); org uuid; branch uuid; cl uuid; program uuid; yr uuid;
 offering uuid; fee uuid; batch uuid; prospect uuid; admission uuid; document uuid;
 payload jsonb; path text; today date := current_date;
begin
 insert into auth.users(id,email,raw_user_meta_data)
 values(actor,'consent-'||actor||'@example.invalid','{"full_name":"Consent Test"}');
 perform public.bootstrap_admin('consent-'||actor||'@example.invalid','Consent Test');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id into org from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org limit 1;
 select id into program from public.programs where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
 values(org,'CONSENT-'||left(actor::text,8),today,today+365,false) returning id into yr;
 payload := public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',yr,'class_id',cl,'program_id',program,'code','CONSENT-'||left(actor::text,8),'name','Consent Test Offering','reason','Consent evidence acceptance'));
 offering := (payload->>'offering_id')::uuid;
 payload := public.publish_fee_plan(jsonb_build_object('offering_id',offering,'billing_cycle','MONTHLY','due_day',10,'effective_from',today,'reason','Consent test plan','components',jsonb_build_array(jsonb_build_object('code','TUITION','name','Tuition','amount',1000,'charge_type','TUITION','recurrence','PER_CYCLE'))));
 fee := (payload->>'fee_plan_version_id')::uuid;
 payload := public.admission_command(jsonb_build_object('action','CREATE_BATCH','request_id',gen_random_uuid(),'reason','Consent test batch','offering_id',offering,'code','CONSENT-'||left(actor::text,8),'name','Consent Test Batch','capacity',12));
 batch := (payload->>'id')::uuid;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id)
 values(org,'Consent Test Student','Consent Test Guardian','01710000919',cl) returning id into prospect;
 payload := public.admission_command(jsonb_build_object('action','CREATE','request_id',gen_random_uuid(),'reason','Consent test draft','prospect_id',prospect,'offering_id',offering,'batch_id',batch));
 admission := (payload->>'id')::uuid;
 path := admission::text || '/' || gen_random_uuid()::text || '.pdf';

 -- In isolated PostgreSQL, simulate the Storage object metadata. Live Supabase
 -- tests must upload through Storage API and verify RLS and signed downloads.
 if to_regclass('storage.objects') is null then
   execute 'create schema storage';
   execute 'create table storage.objects(bucket_id text,name text,owner_id text)';
   execute 'insert into storage.objects(bucket_id,name,owner_id) values($1,$2,$3)'
     using 'admission-consent',path,actor::text;
   payload := public.record_admission_consent(jsonb_build_object('admission_id',admission,'storage_path',path,'sha256',repeat('a',64),'mime_type','application/pdf','file_size',123,'guardian_signed_on',today,'student_signed',false));
   document := (payload->>'id')::uuid;
   if document is null or (select version from public.admission_consent_documents where id=document)<>1 then raise exception 'Consent receipt was not versioned.'; end if;
   if not exists(select 1 from public.audit_events where entity_type='ADMISSION_CONSENT' and entity_id=document::text and action='RECEIVE_SIGNED_FORM') then raise exception 'Consent receipt was not audited.'; end if;
   begin
     perform public.record_admission_consent(jsonb_build_object('admission_id',admission,'storage_path',path,'sha256',repeat('a',64),'mime_type','application/pdf','file_size',123,'guardian_signed_on',today));
     raise exception 'Duplicate storage path accepted.';
   exception when unique_violation then null; end;
 end if;
 if has_table_privilege('authenticated','public.admission_consent_documents','UPDATE') then raise exception 'Staff can overwrite signed evidence.'; end if;
end $$;
select 'PASS' as admission_consent_evidence_status;
rollback;
