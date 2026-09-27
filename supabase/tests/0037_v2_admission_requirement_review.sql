-- Rollback-only checklist review and stale revision protection.
begin;
do $$
declare
 actor uuid := gen_random_uuid(); org uuid; branch uuid; cl uuid; program uuid; yr uuid;
 offering uuid; prospect uuid; application uuid; result jsonb;
begin
 insert into auth.users(id,email,raw_user_meta_data)
 values(actor,'review-'||actor||'@example.invalid','{"full_name":"Review Test"}');
 perform public.bootstrap_admin('review-'||actor||'@example.invalid','Review Test');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 select id into org from public.organizations where code='SOHOJ';
 select id into branch from public.branches where organization_id=org limit 1;
 select id into cl from public.classes where organization_id=org limit 1;
 select id into program from public.programs where organization_id=org limit 1;
 insert into public.academic_years(organization_id,name,starts_on,ends_on,is_active)
 values(org,'REVIEW-'||left(actor::text,8),current_date,current_date+365,false) returning id into yr;
 result := public.create_programme_offering(jsonb_build_object('branch_id',branch,'academic_year_id',yr,'class_id',cl,'program_id',program,'code','REVIEW-'||left(actor::text,8),'name','Review Test Offering','reason','Admission review fixture'));
 offering := (result->>'offering_id')::uuid;
 insert into public.prospects(organization_id,student_name,guardian_name,mobile,current_class_id)
 values(org,'Review Test Student','Review Test Guardian','01710000929',cl) returning id into prospect;
 insert into public.public_admission_applications(prospect_id,offering_id,guardian_address,requirements_acknowledged,policy_acknowledged,published_terms_snapshot)
 values(prospect,offering,'Review Test Address',true,true,'{}') returning id into application;
 result := public.review_admission_requirement(jsonb_build_object('application_id',application,'requirement_label','Previous school record','status','PENDING','expected_revision',0));
 if (result->>'revision')::integer <> 1 then raise exception 'Initial review missing.'; end if;
 result := public.review_admission_requirement(jsonb_build_object('application_id',application,'requirement_label','Previous school record','status','FOLLOW_UP','note','Request school record','expected_revision',1));
 if (result->>'revision')::integer <> 2 then raise exception 'Revision missing.'; end if;
 begin
  perform public.review_admission_requirement(jsonb_build_object('application_id',application,'requirement_label','Previous school record','status','VERIFIED','expected_revision',1));
  raise exception 'Stale review accepted.';
 exception when raise_exception then
  if sqlerrm = 'Stale review accepted.' then raise; end if;
 end;
 if (select count(*) from public.admission_requirement_reviews where application_id=application) <> 2 then raise exception 'Review history lost.'; end if;
 if not exists(select 1 from public.audit_events where entity_type='admission_requirement_review' and entity_id=application::text) then raise exception 'Audit missing.'; end if;
 if has_table_privilege('authenticated','public.admission_requirement_reviews','UPDATE') then raise exception 'Reviews are mutable.'; end if;
end $$;
rollback;
