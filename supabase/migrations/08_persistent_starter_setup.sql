-- Generated from supabase/schema/setup/08_persistent_starter_setup.sql; edit the source, then run pnpm db:baseline.
-- Reusable starter configuration. Insert-only: never overwrite later operator edits.
-- No fabricated People, admissions, invoices, payments or login credentials.
insert into public.directory_entries(academy_id,kind,code,name,name_bn,sort_order)
select a.id,'AREA',v.code,v.name,v.bn,v.ord from public.academies a cross join(values
 ('GOPALPUR_BAZAR','Gopalpur Bazar','গোপালপুর বাজার',1),('NARUNDI','Narundi','নরুন্দি',2),
 ('NANDINA','Nandina','নান্দিনা',3),('VARUAKHALI','Varuakhali','ভারুয়াখালী',4))v(code,name,bn,ord)
on conflict do nothing;
-- Names verified from the official Jamalpur Sadar primary education office list.
-- EIIN, phone/address and school particulars are deliberately not guessed.
insert into public.directory_entries(academy_id,kind,code,name,name_bn,locality,institution_type,source_url,verified_on,is_verified)
select a.id,'INSTITUTION',v.code,v.name,v.name,v.area,'SCHOOL',
 'https://dpe.jamalpursadar.jamalpur.gov.bd/pages/static-pages/69708eb8a31054345f15c107','2026-10-05',true
from public.academies a cross join(values
 ('NARUNDI_PRIMARY','নরুন্দি সরকারি প্রাথমিক বিদ্যালয়','narundi'),
 ('NORTH_NARUNDI_PRIMARY','উত্তর নরুন্দি সরকারি প্রাথমিক বিদ্যালয়','narundi'),
 ('SOUTH_NARUNDI_PRIMARY','দক্ষিণ নরুন্দি সরকারি প্রাথমিক বিদ্যালয়','narundi'),
 ('NANDINA_PRIMARY','নান্দিনা সরকারি প্রাথমিক বিদ্যালয়','nandina'),
 ('NANDINA_NEKJAHAN_PRIMARY','নান্দিনা নেকজাহান সরকারি প্রাথমিক বিদ্যালয়','nandina'),
 ('SHAILERKANDA_PRIMARY','শৈলেরকান্দা সরকারি প্রাথমিক বিদ্যালয়','shailerkanda'))v(code,name,area)
on conflict do nothing;
insert into public.academic_years(id,academy_id,name,starts_on,ends_on)
select md5('sohoj-year-'||y)::uuid,a.id,y::text,make_date(y,1,1),make_date(y,12,31) from public.academies a cross join generate_series(2026,2027)y
on conflict do nothing;
insert into public.programmes(id,academy_id,name,name_bn,programme_type_id)
select md5('sohoj-programme-'||v.code)::uuid,a.id,v.name,v.bn,t.id
from public.academies a cross join(values
 ('SCHOOL','School Academic Programme','স্কুল একাডেমিক প্রোগ্রাম','SCHOOL'),
 ('SSC','SSC A+ Preparation','SSC A+ প্রস্তুতি','COACHING'),
 ('SPOKEN','Spoken English','স্পোকেন ইংলিশ','TRAINING'),
 ('PRIMARY_JOB','Primary Teacher Job Preparation','প্রাথমিক শিক্ষক নিয়োগ প্রস্তুতি','JOB_PREPARATION'))v(code,name,bn,type)
join public.directory_entries t on t.academy_id=a.id and t.kind='PROGRAMME_TYPE' and t.code=v.type
on conflict do nothing;
do $$ declare academy uuid; campus uuid; spec record; run uuid; programme uuid;
begin
 select id into academy from public.academies; select id into campus from public.campuses where academy_id=academy and code='MAIN';
 for spec in select * from(values
 ('SCHOOL_8_2026','SCHOOL','School Academic Programme','SCHOOL',2026,'CLASS_8','2026-01-01'::date,'2026-12-31'::date,2000,'MONTHLY'),
 ('SSC_10_2027','SSC','SSC A+ Preparation','COACHING',2027,'CLASS_10','2027-01-01'::date,'2027-12-31'::date,3000,'MONTHLY'),
 ('SPOKEN_2026','SPOKEN','Spoken English','TRAINING',null,null,'2026-10-01'::date,'2026-12-31'::date,0,'COURSE'))v(code,pcode,pname,division,year,class_code,starts_on,ends_on,amount,cycle)
 loop
  select id into programme from public.programmes where academy_id=academy and (id=md5('sohoj-programme-'||spec.pcode)::uuid or normalized_name=lower(spec.pname)) order by (id=md5('sohoj-programme-'||spec.pcode)::uuid) desc limit 1;
  insert into public.programme_runs(id,academy_id,division_id,campus_id,programme_id,academic_year_id,class_code,code,title,starts_on,ends_on,guardian_rule,public_content)
  select md5('sohoj-run-'||spec.code)::uuid,academy,d.id,campus,programme,y.id,spec.class_code,spec.code,spec.pname||' · '||coalesce(spec.class_code,'Training'),spec.starts_on,spec.ends_on,
   case when spec.division='TRAINING' then 'OPTIONAL' else 'MINOR_REQUIRED' end,
   jsonb_build_object('description','Small-group learning with regular practice and progress review.','description_bn','ছোট দলে নিয়মিত অনুশীলন ও অগ্রগতি পর্যালোচনা।','policy','Academy staff verify identity, fees and placement before confirming admission.')
  from public.operating_divisions d left join public.academic_years y on y.academy_id=academy and (y.id=md5('sohoj-year-'||spec.year)::uuid or y.name=spec.year::text)
  where d.academy_id=academy and d.code=spec.division on conflict do nothing;
  select id into run from public.programme_runs where academy_id=academy and (id=md5('sohoj-run-'||spec.code)::uuid or code=spec.code) limit 1;
  insert into public.run_fee_settings(run_id,academy_id,cycle,due_day,allowed_discounts) values(run,academy,spec.cycle,10,array[5,10,15,20,25,30]) on conflict do nothing;
  insert into public.run_fee_components(run_id,code,name,charge_type,recurrence,amount) values
   (run,'TUITION','Tuition','TUITION','PER_CYCLE',spec.amount),(run,'ADMISSION','Admission fee','ADMISSION','ONE_TIME',0) on conflict do nothing;
  insert into public.teaching_batches(id,academy_id,run_id,code,name,capacity) values(md5('sohoj-batch-'||spec.code)::uuid,academy,run,'MORNING_A','Morning A',12) on conflict do nothing;
  insert into public.run_subjects(run_id,subject_id,academy_id)
  select run,id,academy from public.directory_entries where academy_id=academy and kind='SUBJECT' and
   ((spec.division='SCHOOL' and code in('BANGLA','ENGLISH','MATHEMATICS','GENERAL_SCIENCE','ICT')) or
    (spec.division='COACHING' and code in('BANGLA','ENGLISH','MATHEMATICS','PHYSICS','CHEMISTRY','BIOLOGY','ICT')) or
    (spec.division='TRAINING' and code='ENGLISH')) on conflict do nothing;
 end loop;
end $$;
-- Website/intake stay closed until the administrator reviews starter amounts/dates.
