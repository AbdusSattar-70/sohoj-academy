-- Generated from supabase/schema/academics/11_offering_setup_and_history_guards.sql; edit the source, then run pnpm db:baseline.
-- Complete setup editing while preserving actual placement history.
create or replace function public.save_programme_run(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.programme_runs; saved public.programme_runs; identity uuid:=nullif(p_input->>'id','')::uuid;
 division public.operating_divisions; programme public.programmes; year public.academic_years; class_row public.class_levels;
 campus uuid:=(p_input->>'campus_id')::uuid; year_id uuid:=nullif(p_input->>'academic_year_id','')::uuid;
 class_value text:=nullif(p_input->>'class_code',''); start_date date:=(p_input->>'starts_on')::date; end_date date:=(p_input->>'ends_on')::date;
 title_value text; subject_value uuid; active_value boolean:=coalesce((p_input->>'is_active')::boolean,true);
begin
 prior:=public.lookup_operation(req,'SAVE_RUN',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 select * into division from public.operating_divisions where id=(p_input->>'division_id')::uuid and academy_id=academy and is_active for share;
 select * into programme from public.programmes where id=(p_input->>'programme_id')::uuid and academy_id=academy and is_active for share;
 if division.id is null or programme.id is null then raise exception 'Choose an active division and programme.'; end if;
 perform 1 from public.campuses where id=campus and academy_id=academy and is_active for share;
 if not found then raise exception 'Choose an active campus.'; end if;
 if division.code in('SCHOOL','COACHING') then
  select * into year from public.academic_years where id=year_id and academy_id=academy and is_active for share;
  select * into class_row from public.class_levels where code=class_value and is_active for share;
  if year.id is null or class_row.code is null then raise exception 'School/coaching requires an active academic year and class.'; end if;
  if division.code='SCHOOL' and class_value not in('PLAY','NURSERY','KG','CLASS_1','CLASS_2','CLASS_3','CLASS_4','CLASS_5','CLASS_6','CLASS_7','CLASS_8') then raise exception 'Initial school scope is Play through Class 8.'; end if;
  if division.code='COACHING' and class_value not in('CLASS_9','CLASS_10','CLASS_11','CLASS_12') then raise exception 'Coaching scope is Class 9 through Class 12.'; end if;
  if start_date<year.starts_on or end_date>year.ends_on then raise exception 'Programme dates must fit the academic year.'; end if;
 elsif year_id is not null or class_value is not null then
  raise exception 'Training uses course dates; do not force a school year or class.';
 end if;
 if jsonb_typeof(coalesce(p_input->'subject_ids','[]'))<>'array' or jsonb_array_length(coalesce(p_input->'subject_ids','[]'))>100 then raise exception 'Select a valid subject list.'; end if;
 title_value:=coalesce(nullif(btrim(p_input->>'title'),''),concat_ws(' · ',programme.name,class_row.name,year.name));
 if identity is not null then
  select * into original from public.programme_runs where id=identity and academy_id=academy for update;
  if not found then raise exception 'Current programme not found.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Current programme changed. Reload before editing.'; end if;
  if original.division_id<>division.id or original.programme_id<>programme.id or original.campus_id<>campus or
   original.academic_year_id is distinct from year_id or original.class_code is distinct from class_value then
   if exists(select 1 from public.batch_seats s join public.teaching_batches b on b.id=s.batch_id where b.run_id=original.id) then raise exception 'Academic placement history exists. Keep its context and create a different offering instead.'; end if;
  end if;
  update public.programme_runs set division_id=division.id,campus_id=campus,programme_id=programme.id,academic_year_id=year_id,class_code=class_value,code=coalesce(nullif(btrim(p_input->>'code'),''),original.code),title=title_value,starts_on=start_date,ends_on=end_date,
   guardian_rule=coalesce(p_input->>'guardian_rule',original.guardian_rule),is_active=active_value,
   website_visible=active_value and coalesce((p_input->>'website_visible')::boolean,false),
   applications_open=active_value and coalesce((p_input->>'applications_open')::boolean,false),
   application_opens_on=nullif(p_input->>'application_opens_on','')::date,application_closes_on=nullif(p_input->>'application_closes_on','')::date,
   public_content=coalesce(p_input->'public_content',original.public_content),revision=revision+1 where id=identity returning * into saved;
 else
  if coalesce((p_input->>'website_visible')::boolean,false) or coalesce((p_input->>'applications_open')::boolean,false) then raise exception 'Save fees and a batch first, then publish this current programme.'; end if;
  insert into public.programme_runs(academy_id,division_id,campus_id,programme_id,academic_year_id,class_code,code,title,starts_on,ends_on,guardian_rule,is_active,application_opens_on,application_closes_on,public_content)
  values(academy,division.id,campus,programme.id,year_id,class_value,coalesce(nullif(btrim(p_input->>'code'),''),'RUN_'||upper(replace(gen_random_uuid()::text,'-',''))),title_value,start_date,end_date,coalesce(p_input->>'guardian_rule','MINOR_REQUIRED'),active_value,nullif(p_input->>'application_opens_on','')::date,nullif(p_input->>'application_closes_on','')::date,coalesce(p_input->'public_content','{}')) returning * into saved;
 end if;
 if saved.website_visible or saved.applications_open then
  if not exists(select 1 from public.run_fee_settings f join public.run_fee_components c on c.run_id=f.run_id where f.run_id=saved.id and c.is_active and c.charge_type='TUITION' and c.recurrence='PER_CYCLE') then raise exception 'Save standard tuition before publishing.'; end if;
 end if;
 if saved.applications_open and not exists(select 1 from public.teaching_batches where run_id=saved.id and is_active) then raise exception 'Create an active batch before opening applications.'; end if;
 -- Preserve relationship history: subjects are activated/inactivated, never deleted.
 update public.run_subjects set is_active=false where run_id=saved.id;
 for subject_value in select distinct value::uuid from jsonb_array_elements_text(coalesce(p_input->'subject_ids','[]')) loop
  perform 1 from public.directory_entries where id=subject_value and academy_id=academy and kind='SUBJECT' and is_active for share;
  if not found then raise exception 'Select active subjects in this academy.'; end if;
  insert into public.run_subjects(run_id,subject_id,academy_id,is_active) values(saved.id,subject_value,academy,true)
  on conflict(run_id,subject_id) do update set is_active=true;
 end loop;
 return public.finish_operation(req,'SAVE_RUN',p_input,to_jsonb(saved),'PROGRAMME_RUN',saved.id,to_jsonb(original));
end $$;

create or replace function public.save_teaching_batch(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.teaching_batches; saved public.teaching_batches; run public.programme_runs;
 identity uuid:=nullif(p_input->>'id','')::uuid; occupied integer;
begin
 prior:=public.lookup_operation(req,'SAVE_BATCH',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 select * into run from public.programme_runs where id=(p_input->>'run_id')::uuid and academy_id=academy and is_active for update;
 if not found then raise exception 'Choose an active current programme.'; end if;
 if not exists(select 1 from public.run_fee_settings where run_id=run.id) then raise exception 'Save programme fees before creating a batch.'; end if;
 if identity is null then
  insert into public.teaching_batches(academy_id,run_id,code,name,capacity)
  values(academy,run.id,coalesce(nullif(btrim(p_input->>'code'),''),'BATCH_'||upper(replace(gen_random_uuid()::text,'-',''))),btrim(p_input->>'name'),(p_input->>'capacity')::integer) returning * into saved;
 else
  select * into original from public.teaching_batches where id=identity and academy_id=academy for update;
  if not found then raise exception 'Batch not found.'; end if;
  if original.run_id<>run.id then raise exception 'Keep the original batch programme; use an enrollment transfer for placement changes.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Batch changed. Reload before editing.'; end if;
  select count(*) into occupied from public.batch_seats where batch_id=identity and is_active;
  if (p_input->>'capacity')::integer<occupied then raise exception 'Capacity cannot be below enrolled students.'; end if;
  if not coalesce((p_input->>'is_active')::boolean,true) then
   if occupied>0 then raise exception 'Move or close active enrollments before marking this batch inactive.';end if;
   if run.applications_open and not exists(select 1 from public.teaching_batches where run_id=run.id and id<>identity and is_active) then raise exception 'Close application intake before marking the last batch inactive.';end if;
  end if;
  update public.teaching_batches set code=coalesce(nullif(btrim(p_input->>'code'),''),original.code),name=btrim(p_input->>'name'),capacity=(p_input->>'capacity')::integer,
   is_active=coalesce((p_input->>'is_active')::boolean,true),revision=revision+1 where id=identity returning * into saved;
 end if;
 return public.finish_operation(req,'SAVE_BATCH',p_input,to_jsonb(saved),'BATCH',saved.id,to_jsonb(original));
end $$;

create or replace function public.programme_run_setup(p_run_id uuid,p_batch_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.view'); run public.programme_runs; result jsonb;
begin
 if p_batch_page is null or p_batch_page not between 1 and 100000 then raise exception 'Choose a valid batch page.'; end if;
 select * into run from public.programme_runs where id=p_run_id and academy_id=academy;
 if not found then raise exception 'Current programme not found.'; end if;
 select jsonb_build_object('run',to_jsonb(run),'programmeName',(select name from public.programmes where id=run.programme_id),'contextLocked',exists(select 1 from public.batch_seats s join public.teaching_batches b on b.id=s.batch_id where b.run_id=run.id),'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'name_bn',d.name_bn,'is_active',d.is_active) order by d.sort_order,d.name) from public.run_subjects rs join public.directory_entries d on d.id=rs.subject_id where rs.run_id=run.id and rs.is_active),'[]'),'feeSettings',(select to_jsonb(f) from public.run_fee_settings f where run_id=run.id),
 'components',coalesce((select jsonb_agg(to_jsonb(c) order by c.code) from public.run_fee_components c where run_id=run.id and is_active),'[]'),
 'subjectIds',coalesce((select jsonb_agg(subject_id order by subject_id) from public.run_subjects where run_id=run.id and is_active),'[]'),
 'batchPage',p_batch_page,'batchPageSize',25,'batchTotal',(select count(*) from public.teaching_batches where run_id=run.id),
 'batches',coalesce((select jsonb_agg(to_jsonb(b) order by b.name,b.id) from (
  select tb.*,(select count(*) from public.batch_seats s where s.batch_id=tb.id and s.is_active) occupied
  from public.teaching_batches tb where tb.run_id=run.id order by name,id limit 25 offset(p_batch_page-1)*25)b),'[]')) into result;
 return result;
end $$;

create function public.search_academic_years(p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('directory.view'); result jsonb;
begin
 if p_page is null or p_page not between 1 and 100000 then raise exception 'Invalid page.';end if;
 with matched as(select id,name,starts_on,ends_on,is_active,revision from public.academic_years where academy_id=academy), paged as(select * from matched order by starts_on desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by starts_on desc,id) from paged),'[]')) into result;return result;
end $$;
revoke all on function public.search_academic_years(integer) from public,anon;
grant execute on function public.search_academic_years(integer) to authenticated;

create or replace function public.guard_batch_seat() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare batch public.teaching_batches; run_identity uuid;
begin
 if tg_op='UPDATE' and (new.batch_id<>old.batch_id or new.person_id<>old.person_id or new.academy_id<>old.academy_id) then raise exception 'Seat identity is fixed. Record a new placement.'; end if;
 select run_id into run_identity from public.teaching_batches where id=new.batch_id;
 -- Lock run before batch: context edits and seat assignment cannot race.
 perform 1 from public.programme_runs where id=run_identity for share;
 select * into batch from public.teaching_batches where id=new.batch_id for update;
 if new.is_active then
  if not batch.is_active or not exists(select 1 from public.programme_runs r join public.programmes p on p.id=r.programme_id join public.operating_divisions d on d.id=r.division_id join public.campuses c on c.id=r.campus_id where r.id=batch.run_id and r.is_active and p.is_active and d.is_active and c.is_active) then raise exception 'The batch and its academic context must be active.'; end if;
  if not exists(select 1 from public.people where id=new.person_id and academy_id=batch.academy_id and is_active) then raise exception 'Choose an active academy person.'; end if;
  if (select count(*) from public.batch_seats where batch_id=batch.id and is_active and person_id<>new.person_id)>=batch.capacity then raise exception 'This batch is full.'; end if;
 end if;
 return new;
end $$;
