-- A programme is a reusable definition; an offering is its actual operating context.
alter table public.operating_divisions add unique(id,academy_id);
alter table public.campuses add unique(id,academy_id);
create table public.programmes (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 name text not null check(length(btrim(name)) between 2 and 160), name_bn text,
 normalized_name text generated always as(lower(regexp_replace(btrim(name),'\s+',' ','g'))) stored,
 programme_type_id uuid not null, is_active boolean not null default true, revision integer not null default 1,
 unique(academy_id,normalized_name), unique(id,academy_id),
 foreign key(programme_type_id,academy_id) references public.directory_entries(id,academy_id)
);
create table public.programme_runs (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 division_id uuid not null, campus_id uuid not null, programme_id uuid not null,
 academic_year_id uuid, class_code text references public.class_levels,
 code text not null, title text not null check(length(btrim(title)) between 2 and 240),
 starts_on date not null, ends_on date not null, guardian_rule text not null default 'MINOR_REQUIRED' check(guardian_rule in('MINOR_REQUIRED','REQUIRED','OPTIONAL')),
 is_active boolean not null default true, website_visible boolean not null default false,
 applications_open boolean not null default false, application_opens_on date, application_closes_on date,
 public_content jsonb not null default '{}', revision integer not null default 1,
 unique(academy_id,code), unique(id,academy_id),
 foreign key(division_id,academy_id) references public.operating_divisions(id,academy_id),
 foreign key(campus_id,academy_id) references public.campuses(id,academy_id),
 foreign key(programme_id,academy_id) references public.programmes(id,academy_id),
 foreign key(academic_year_id,academy_id) references public.academic_years(id,academy_id),
 check(ends_on>=starts_on), check(application_closes_on is null or application_opens_on is null or application_closes_on>=application_opens_on),
 check(jsonb_typeof(public_content)='object'), check(is_active or (not website_visible and not applications_open))
);
create table public.run_subjects (
 run_id uuid not null, subject_id uuid not null, academy_id uuid not null,
 is_active boolean not null default true, primary key(run_id,subject_id),
 foreign key(run_id,academy_id) references public.programme_runs(id,academy_id),
 foreign key(subject_id,academy_id) references public.directory_entries(id,academy_id)
);
create table public.run_fee_settings (
 run_id uuid primary key, academy_id uuid not null,
 cycle text not null check(cycle in('MONTHLY','TERM','COURSE')), due_day integer not null check(due_day between 1 and 28),
 allowed_discounts integer[] not null default '{}', revision integer not null default 1,
 foreign key(run_id,academy_id) references public.programme_runs(id,academy_id),
 check(allowed_discounts <@ array[5,10,15,20,25,30])
);
create table public.run_fee_components (
 id uuid primary key default gen_random_uuid(), run_id uuid not null references public.run_fee_settings(run_id),
 code text not null, name text not null check(length(btrim(name)) between 2 and 120),
 charge_type text not null check(charge_type in('TUITION','ADMISSION','EXAM','MATERIAL','OTHER')),
 recurrence text not null check(recurrence in('PER_CYCLE','ONE_TIME')),
 amount numeric(14,2) not null check(amount>=0 and amount<>'NaN'::numeric),
 is_active boolean not null default true, unique(run_id,code)
);
create table public.teaching_batches (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null, run_id uuid not null,
 code text not null, name text not null check(length(btrim(name)) between 2 and 160),
 capacity integer not null check(capacity between 1 and 200),
 is_active boolean not null default true, revision integer not null default 1,
 unique(run_id,code), unique(id,academy_id),
 foreign key(run_id,academy_id) references public.programme_runs(id,academy_id)
);
-- Canonical actual seat assignment. Admission will create this atomically with enrollment.
create table public.batch_seats (
 batch_id uuid not null, person_id uuid not null, academy_id uuid not null,
 is_active boolean not null default true, primary key(batch_id,person_id),
 foreign key(batch_id,academy_id) references public.teaching_batches(id,academy_id),
 foreign key(person_id,academy_id) references public.people(id,academy_id)
);
create index run_context_idx on public.programme_runs(academy_id,division_id,is_active,starts_on desc);
create index batch_run_idx on public.teaching_batches(run_id,is_active);

-- Shared retry helpers are internal and never grant privileges on their own.
create function public.lookup_operation(request_value uuid,command_value text,payload_value jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare prior public.operation_requests;
begin
 if auth.uid() is null or request_value is null then raise exception 'A verified account and request identity are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||request_value::text,0));
 select * into prior from public.operation_requests where actor_id=auth.uid() and request_id=request_value;
 if found then
  if prior.command<>command_value or prior.payload<>payload_value then raise exception 'This request identity belongs to different input.'; end if;
  return prior.result;
 end if;
 return null;
end $$;
create function public.finish_operation(request_value uuid,command_value text,payload_value jsonb,result_value jsonb,
 entity_value text,id_value uuid,before_value jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform public.record_activity(command_value,entity_value,id_value::text,payload_value->>'reason',before_value,result_value,request_value);
 insert into public.operation_requests values(auth.uid(),request_value,command_value,payload_value,result_value,now());
 return result_value;
end $$;
create function public.check_change_reason(reason_value text) returns void language plpgsql immutable set search_path=public,pg_temp as $$
begin
 if reason_value is null or length(btrim(reason_value)) not between 5 and 1000 then raise exception 'Choose or enter a short change reason.'; end if;
end $$;

create function public.save_programme(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.programmes; saved public.programmes; identity uuid:=nullif(p_input->>'id','')::uuid; type_id uuid:=(p_input->>'programme_type_id')::uuid;
begin
 prior:=public.lookup_operation(req,'SAVE_PROGRAMME',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 perform 1 from public.directory_entries where id=type_id and academy_id=academy and kind='PROGRAMME_TYPE' and is_active for share;
 if not found then raise exception 'Choose an active programme type.'; end if;
 if identity is null then
  insert into public.programmes(academy_id,name,name_bn,programme_type_id)
  values(academy,btrim(p_input->>'name'),nullif(btrim(p_input->>'name_bn'),''),type_id) returning * into saved;
 else
  select * into original from public.programmes where id=identity and academy_id=academy for update;
  if not found then raise exception 'Programme not found.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Programme changed. Reload before editing.'; end if;
  update public.programmes set name=btrim(p_input->>'name'),name_bn=nullif(btrim(p_input->>'name_bn'),''),
   programme_type_id=type_id,is_active=coalesce((p_input->>'is_active')::boolean,true),revision=revision+1 where id=identity returning * into saved;
 end if;
 return public.finish_operation(req,'SAVE_PROGRAMME',p_input,to_jsonb(saved),'PROGRAMME',saved.id,to_jsonb(original));
end $$;

create function public.save_programme_run(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
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
   raise exception 'Keep the academic context stable; create another current programme for a new context.';
  end if;
  update public.programme_runs set title=title_value,starts_on=start_date,ends_on=end_date,
   guardian_rule=coalesce(p_input->>'guardian_rule',original.guardian_rule),is_active=active_value,
   website_visible=active_value and coalesce((p_input->>'website_visible')::boolean,false),
   applications_open=active_value and coalesce((p_input->>'applications_open')::boolean,false),
   application_opens_on=nullif(p_input->>'application_opens_on','')::date,application_closes_on=nullif(p_input->>'application_closes_on','')::date,
   public_content=coalesce(p_input->'public_content',original.public_content),revision=revision+1 where id=identity returning * into saved;
 else
  if coalesce((p_input->>'website_visible')::boolean,false) or coalesce((p_input->>'applications_open')::boolean,false) then raise exception 'Save fees and a batch first, then publish this current programme.'; end if;
  insert into public.programme_runs(academy_id,division_id,campus_id,programme_id,academic_year_id,class_code,code,title,starts_on,ends_on,guardian_rule)
  values(academy,division.id,campus,programme.id,year_id,class_value,coalesce(nullif(btrim(p_input->>'code'),''),'RUN_'||upper(replace(gen_random_uuid()::text,'-',''))),title_value,start_date,end_date,coalesce(p_input->>'guardian_rule','MINOR_REQUIRED')) returning * into saved;
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

create function public.save_run_fees(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('fees.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.run_fee_settings; saved public.run_fee_settings; run public.programme_runs;
 discounts integer[]; component jsonb; amount_value numeric; component_code text; previous_components jsonb;
begin
 prior:=public.lookup_operation(req,'SAVE_FEES',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 select * into run from public.programme_runs where id=(p_input->>'run_id')::uuid and academy_id=academy and is_active for update;
 if not found then raise exception 'Choose an active current programme.'; end if;
 select * into original from public.run_fee_settings where run_id=run.id;
 select coalesce(jsonb_agg(to_jsonb(c) order by c.code),'[]') into previous_components from public.run_fee_components c where run_id=run.id and is_active;
 if (p_input->>'revision')::integer is distinct from coalesce(original.revision,0) then raise exception 'Fees changed. Reload before saving.'; end if;
 if jsonb_typeof(coalesce(p_input->'allowed_discounts','[]'))<>'array' then raise exception 'Choose valid discount percentages.'; end if;
 select coalesce(array_agg(distinct value::integer),'{}'::integer[]) into discounts from jsonb_array_elements_text(coalesce(p_input->'allowed_discounts','[]'));
 if jsonb_typeof(p_input->'components') is distinct from 'array' or jsonb_array_length(p_input->'components') not between 1 and 20 then raise exception 'Enter one to twenty fee components.'; end if;
 if not exists(select 1 from jsonb_array_elements(p_input->'components') c where c->>'charge_type'='TUITION' and c->>'recurrence'='PER_CYCLE') then raise exception 'Include standard tuition for the billing cycle; zero tuition is allowed.'; end if;
 if exists(select 1 from jsonb_array_elements(p_input->'components') c group by upper(btrim(c->>'code')) having count(*)>1) then raise exception 'Fee component codes must be unique.'; end if;
 insert into public.run_fee_settings(run_id,academy_id,cycle,due_day,allowed_discounts)
 values(run.id,academy,p_input->>'cycle',(p_input->>'due_day')::integer,discounts)
 on conflict(run_id) do update set cycle=excluded.cycle,due_day=excluded.due_day,allowed_discounts=excluded.allowed_discounts,revision=run_fee_settings.revision+1 returning * into saved;
 update public.run_fee_components set is_active=false where run_id=run.id;
 for component in select value from jsonb_array_elements(p_input->'components') loop
  amount_value:=(component->>'amount')::numeric; component_code:=upper(btrim(component->>'code'));
  if amount_value is null or amount_value='NaN'::numeric or amount_value<0 or amount_value>=1000000000000 or amount_value<>round(amount_value,2) then raise exception 'Fee amount must be a finite nonnegative BDT amount with at most two decimal places.'; end if;
  if component_code is null or component_code !~ '^[A-Z][A-Z0-9_]{1,79}$' then raise exception 'Choose a valid fee component code.'; end if;
  insert into public.run_fee_components(run_id,code,name,charge_type,recurrence,amount)
  values(run.id,component_code,btrim(component->>'name'),component->>'charge_type',component->>'recurrence',amount_value)
  on conflict(run_id,code) do update set name=excluded.name,charge_type=excluded.charge_type,recurrence=excluded.recurrence,amount=excluded.amount,is_active=true;
 end loop;
 return public.finish_operation(req,'SAVE_FEES',p_input,to_jsonb(saved)||jsonb_build_object('components',p_input->'components'),'RUN_FEES',run.id,coalesce(to_jsonb(original),'{}')||jsonb_build_object('components',previous_components));
end $$;

create function public.save_teaching_batch(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
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
  update public.teaching_batches set name=btrim(p_input->>'name'),capacity=(p_input->>'capacity')::integer,
   is_active=coalesce((p_input->>'is_active')::boolean,true),revision=revision+1 where id=identity returning * into saved;
 end if;
 return public.finish_operation(req,'SAVE_BATCH',p_input,to_jsonb(saved),'BATCH',saved.id,to_jsonb(original));
end $$;

create function public.guard_batch_seat() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare batch public.teaching_batches;
begin
 if tg_op='UPDATE' and (new.batch_id<>old.batch_id or new.person_id<>old.person_id or new.academy_id<>old.academy_id) then raise exception 'Seat identity is fixed. Record a new placement.'; end if;
 select * into batch from public.teaching_batches where id=new.batch_id for update;
 if new.is_active then
  if not batch.is_active or not exists(select 1 from public.programme_runs r join public.programmes p on p.id=r.programme_id join public.operating_divisions d on d.id=r.division_id join public.campuses c on c.id=r.campus_id where r.id=batch.run_id and r.is_active and p.is_active and d.is_active and c.is_active) then raise exception 'The batch and its academic context must be active.'; end if;
  if not exists(select 1 from public.people where id=new.person_id and academy_id=batch.academy_id and is_active) then raise exception 'Choose an active academy person.'; end if;
  if (select count(*) from public.batch_seats where batch_id=batch.id and is_active and person_id<>new.person_id)>=batch.capacity then raise exception 'This batch is full.'; end if;
 end if;
 return new;
end $$;
create trigger enforce_batch_capacity before insert or update on public.batch_seats for each row execute function public.guard_batch_seat();

create function public.list_current_programmes(p_division_id uuid default null,p_query text default '',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.view'); result jsonb;
begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 100000 then raise exception 'Choose a valid search/page.'; end if;
 with matched as(select r.*,d.code division_code,d.name division_name,p.name programme_name,c.name campus_name,
  (select count(*) from public.teaching_batches b where b.run_id=r.id and b.is_active) active_batches
  from public.programme_runs r join public.operating_divisions d on d.id=r.division_id join public.programmes p on p.id=r.programme_id join public.campuses c on c.id=r.campus_id
  where r.academy_id=academy and (p_division_id is null or r.division_id=p_division_id) and (btrim(p_query)='' or position(lower(btrim(p_query)) in lower(r.title||' '||r.code))>0)),
 paged as(select * from matched order by starts_on desc,title,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('total',(select count(*) from matched),'page',p_page,'pageSize',25,
 'rows',coalesce((select jsonb_agg(to_jsonb(paged) order by starts_on desc,title,id) from paged),'[]')) into result;
 return result;
end $$;
create function public.public_current_programmes() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'code',r.code,'title',r.title,'division',d.code,'classCode',r.class_code,
 'startsOn',r.starts_on,'endsOn',r.ends_on,'content',r.public_content,
 'activeBatches',(select count(*) from public.teaching_batches b where b.run_id=r.id and b.is_active),
 'openSeats',(select coalesce(sum(greatest(0,b.capacity-(select count(*) from public.batch_seats s where s.batch_id=b.id and s.is_active))),0) from public.teaching_batches b where b.run_id=r.id and b.is_active),
 'acceptingApplications',r.applications_open and exists(select 1 from public.teaching_batches b where b.run_id=r.id and b.is_active) and (r.application_opens_on is null or r.application_opens_on<=timezone(a.timezone,now())::date) and (r.application_closes_on is null or r.application_closes_on>=timezone(a.timezone,now())::date),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'nameBn',s.name_bn) order by s.sort_order,s.name) from public.run_subjects rs join public.directory_entries s on s.id=rs.subject_id where rs.run_id=r.id and rs.is_active and s.is_active),'[]'),
 'fees',jsonb_build_object('currency','BDT','cycle',f.cycle,'dueDay',f.due_day,'components',coalesce((select jsonb_agg(jsonb_build_object('name',c.name,'amount',c.amount,'chargeType',c.charge_type,'recurrence',c.recurrence) order by c.code) from public.run_fee_components c where c.run_id=r.id and c.is_active),'[]'))
 ) order by r.starts_on,r.title,r.id),'[]')
 from public.programme_runs r join public.academies a on a.id=r.academy_id join public.operating_divisions d on d.id=r.division_id
 join public.programmes p on p.id=r.programme_id join public.campuses c on c.id=r.campus_id join public.run_fee_settings f on f.run_id=r.id
 where r.is_active and r.website_visible and d.is_active and p.is_active and c.is_active
 and (r.academic_year_id is null or exists(select 1 from public.academic_years y where y.id=r.academic_year_id and y.is_active))
$$;

do $$ declare relation text; begin
 foreach relation in array array['programmes','programme_runs','run_subjects','run_fee_settings','run_fee_components','teaching_batches','batch_seats'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
  execute format('create trigger preserve_record before delete on public.%I for each row execute function public.reject_record_delete()',relation);
 end loop;
end $$;
revoke all on function public.lookup_operation(uuid,text,jsonb),public.finish_operation(uuid,text,jsonb,jsonb,text,uuid,jsonb),public.check_change_reason(text),public.guard_batch_seat() from public,anon,authenticated;
revoke all on function public.save_programme(jsonb),public.save_programme_run(jsonb),public.save_run_fees(jsonb),public.save_teaching_batch(jsonb),public.list_current_programmes(uuid,text,integer),public.public_current_programmes() from public,anon,authenticated;
grant execute on function public.save_programme(jsonb),public.save_programme_run(jsonb),public.save_run_fees(jsonb),public.save_teaching_batch(jsonb),public.list_current_programmes(uuid,text,integer) to authenticated;
grant execute on function public.public_current_programmes() to anon,authenticated;

alter table public.academic_years add column revision integer not null default 1;
create function public.save_academic_year(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('directory.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.academic_years; saved public.academic_years; identity uuid:=nullif(p_input->>'id','')::uuid;
begin
 prior:=public.lookup_operation(req,'SAVE_YEAR',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 if length(btrim(p_input->>'name')) not between 2 and 80 then raise exception 'Enter an academic year name.'; end if;
 if identity is null then
  insert into public.academic_years(academy_id,name,starts_on,ends_on,is_active)
  values(academy,btrim(p_input->>'name'),(p_input->>'starts_on')::date,(p_input->>'ends_on')::date,coalesce((p_input->>'is_active')::boolean,true)) returning * into saved;
 else
  select * into original from public.academic_years where id=identity and academy_id=academy for update;
  if not found then raise exception 'Academic year not found.'; end if;
  if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Academic year changed. Reload before editing.'; end if;
  if exists(select 1 from public.programme_runs where academic_year_id=identity and (starts_on<(p_input->>'starts_on')::date or ends_on>(p_input->>'ends_on')::date)) then raise exception 'Keep existing programme dates inside this year.'; end if;
  update public.academic_years set name=btrim(p_input->>'name'),starts_on=(p_input->>'starts_on')::date,ends_on=(p_input->>'ends_on')::date,
   is_active=coalesce((p_input->>'is_active')::boolean,true),revision=revision+1 where id=identity returning * into saved;
 end if;
 return public.finish_operation(req,'SAVE_YEAR',p_input,to_jsonb(saved),'ACADEMIC_YEAR',saved.id,to_jsonb(original));
end $$;
revoke all on function public.save_academic_year(jsonb) from public,anon;
grant execute on function public.save_academic_year(jsonb) to authenticated;

create function public.set_programme_run_active(p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.manage'); req uuid:=(p_input->>'request_id')::uuid;
 prior jsonb; original public.programme_runs; saved public.programme_runs;
begin
 prior:=public.lookup_operation(req,'SET_RUN_ACTIVE',p_input); if prior is not null then return prior; end if;
 perform public.check_change_reason(p_input->>'reason');
 if jsonb_typeof(p_input->'is_active') is distinct from 'boolean' then raise exception 'Choose active or inactive.'; end if;
 select * into original from public.programme_runs where id=(p_input->>'id')::uuid and academy_id=academy for update;
 if not found then raise exception 'Current programme not found.'; end if;
 if (p_input->>'revision')::integer is distinct from original.revision then raise exception 'Programme changed. Reload before changing status.'; end if;
 update public.programme_runs set is_active=(p_input->>'is_active')::boolean,website_visible=false,applications_open=false,revision=revision+1 where id=original.id returning * into saved;
 return public.finish_operation(req,'SET_RUN_ACTIVE',p_input,to_jsonb(saved),'PROGRAMME_RUN',saved.id,to_jsonb(original));
end $$;
create function public.programme_run_setup(p_run_id uuid,p_batch_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare academy uuid:=public.require_operation('academics.view'); run public.programme_runs; result jsonb;
begin
 if p_batch_page is null or p_batch_page not between 1 and 100000 then raise exception 'Choose a valid batch page.'; end if;
 select * into run from public.programme_runs where id=p_run_id and academy_id=academy;
 if not found then raise exception 'Current programme not found.'; end if;
 select jsonb_build_object('run',to_jsonb(run),'feeSettings',(select to_jsonb(f) from public.run_fee_settings f where run_id=run.id),
 'components',coalesce((select jsonb_agg(to_jsonb(c) order by c.code) from public.run_fee_components c where run_id=run.id and is_active),'[]'),
 'subjectIds',coalesce((select jsonb_agg(subject_id order by subject_id) from public.run_subjects where run_id=run.id and is_active),'[]'),
 'batchPage',p_batch_page,'batchPageSize',25,'batchTotal',(select count(*) from public.teaching_batches where run_id=run.id),
 'batches',coalesce((select jsonb_agg(to_jsonb(b) order by b.name,b.id) from (
  select tb.*,(select count(*) from public.batch_seats s where s.batch_id=tb.id and s.is_active) occupied
  from public.teaching_batches tb where tb.run_id=run.id order by name,id limit 25 offset(p_batch_page-1)*25)b),'[]')) into result;
 return result;
end $$;
revoke all on function public.set_programme_run_active(jsonb),public.programme_run_setup(uuid,integer) from public,anon;
grant execute on function public.set_programme_run_active(jsonb),public.programme_run_setup(uuid,integer) to authenticated;
