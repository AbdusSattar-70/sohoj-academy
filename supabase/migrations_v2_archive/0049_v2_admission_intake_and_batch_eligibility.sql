-- Clear staff-assisted intake, preserve full application particulars, and make
-- a Prospect's recorded offering the source of batch eligibility.
alter table public.prospects
  add column if not exists date_of_birth date,
  add column if not exists gender text,
  add column if not exists school_roll text,
  add column if not exists guardian_address text;

comment on column public.prospects.guardian_address is
  'Guardian address collected during staff-assisted or public admission intake.';

create table if not exists public.staff_admission_intake_requests (
  request_id uuid primary key,
  actor_id uuid not null references public.profiles(id),
  payload jsonb not null,
  prospect_id uuid not null references public.prospects(id),
  admission_id uuid not null references public.admission_cases(id),
  created_at timestamptz not null default now()
);
alter table public.staff_admission_intake_requests enable row level security;
revoke all on public.staff_admission_intake_requests from public, anon, authenticated;

-- Add the recorded offering to the admission workspace contract.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,$old$;
  new_block := $new$'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'interestedOfferingId',p.interested_offering_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,$new$;
  if position(old_block in definition)=0 then
    if position('interestedOfferingId' in definition)>0 then return; end if;
    raise exception 'Cannot add Prospect offering to admission workspace; expected contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Offer only choices for which a currently effective published Fee Plan exists.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'classId',o.class_id,'className',c.name)) from public.programme_offerings o join public.classes c on c.id=o.class_id where o.status='ACTIVE'),'[]'::jsonb),$old$;
  new_block := $new$'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'code',o.code,
      'classId',o.class_id,'className',c.name,'yearName',ay.name,'branchName',br.name))
    from public.programme_offerings o join public.classes c on c.id=o.class_id
    join public.academic_years ay on ay.id=o.academic_year_id left join public.branches br on br.id=o.branch_id
    join public.organizations org on org.id=o.organization_id
    where o.status='ACTIVE' and exists(select 1 from public.fee_plan_versions f
      where f.offering_id=o.id and f.status='ACTIVE'
        and f.effective_from<=timezone(org.timezone,now())::date)),'[]'::jsonb),$new$;
  if position(old_block in definition)=0 then
    if position('f.effective_from<=timezone(org.timezone,now())::date' in definition)>0 then return; end if;
    raise exception 'Cannot scope admission offerings to effective Fee Plans; expected workspace contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Expose the complete consent/application particulars in the permission-scoped
-- case read model so the case-specific printable form reflects the intake.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'name',a.identity_snapshot->>'student_name','guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',$old$;
  new_block := $new$'name',a.identity_snapshot->>'student_name','nameBn',a.identity_snapshot->>'student_name_bn',
      'gender',a.identity_snapshot->>'gender','dateOfBirth',a.identity_snapshot->>'date_of_birth',
      'schoolName',a.identity_snapshot->>'school_name','schoolRoll',a.identity_snapshot->>'school_roll',
      'guardianAddress',a.identity_snapshot->>'guardian_address','alternateMobile',a.identity_snapshot->>'alternate_mobile',
      'guardianRelationship',a.identity_snapshot->>'guardian_relationship',
      'guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',$new$;
  if position(old_block in definition)=0 then
    if position('guardianAddress' in definition)>0 then return; end if;
    raise exception 'Cannot add application details to the admission read model; expected case contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Pin the captured application details in every newly created admission case,
-- including public applications already held in the CRM review queue.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  old_block := $old$'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot),v_actor)$old$;
  new_block := $new$'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot,
     'student_name_bn',v_prospect.student_name_bn,'gender',v_prospect.gender,
     'date_of_birth',v_prospect.date_of_birth,'school_roll',v_prospect.school_roll,
     'alternate_mobile',v_prospect.alternate_mobile,
     'guardian_address',coalesce(v_prospect.guardian_address,
       (select pa.guardian_address from public.public_admission_applications pa where pa.prospect_id=v_prospect.id)),
     'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian')),v_actor)$new$;
  if position(old_block in definition)=0 then
    if position('public_admission_applications pa where pa.prospect_id=v_prospect.id' in definition)>0 then return; end if;
    raise exception 'Cannot preserve applicant details in the admission snapshot; expected creation block changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Existing Prospects without an assigned class can be admitted only when the
-- staff member explicitly chooses the Prospect's recorded active offering.
do $migration$
declare definition text; old_check text; new_check text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  old_check := $old$if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id or v_prospect.current_class_id is distinct from v_offering.class_id then
     raise exception 'Batch must match the Prospect class and an active offering.';
   end if;$old$;
  new_check := $new$if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id
     or v_batch.offering_id is distinct from nullif(p_input->>'offering_id','')::uuid
     or (v_prospect.current_class_id is not null and v_prospect.current_class_id is distinct from v_offering.class_id)
     or (v_prospect.current_class_id is null and v_prospect.interested_offering_id is not null
         and v_prospect.interested_offering_id is distinct from v_offering.id) then
     raise exception 'Choose an active offering and a batch that match this Prospect.';
   end if;
   if v_prospect.current_class_id is null then
     update public.prospects set current_class_id=v_offering.class_id where id=v_prospect.id;
     v_prospect.current_class_id:=v_offering.class_id;
     insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
       entity_type,entity_id,action,reason,before_data,after_data,metadata)
     values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
       'PROSPECT',v_prospect.id::text,'ASSIGN_CLASS_FROM_OFFERING',v_reason,
       jsonb_build_object('current_class_id',null,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('current_class_id',v_offering.class_id,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('offering_id',v_offering.id,'batch_id',v_batch.id));
   end if;$new$;
  if position(old_check in definition)=0 then
    if position('interested_offering_id is distinct from v_offering.id' in definition)>0 then return; end if;
    raise exception 'Cannot update Prospect batch eligibility; expected admission guard changed.';
  end if;
  execute replace(definition,old_check,new_check);
end;
$migration$;

-- Copy the detailed applicant record into the permanent Student row at the
-- acceptance transition. The admission case snapshot remains the audit source.
create or replace function public.sync_admission_student_details()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.student_id is not null and old.student_id is null then
    update public.students s set
      name_bn = p.student_name_bn,
      gender = p.gender,
      date_of_birth = p.date_of_birth,
      school_roll = p.school_roll
    from public.prospects p
    where p.id = new.prospect_id and s.id = new.student_id;
    update public.guardians g set
      alternate_mobile = coalesce(g.alternate_mobile,p.alternate_mobile),
      address = coalesce(g.address,p.guardian_address,
        (select pa.guardian_address from public.public_admission_applications pa where pa.prospect_id=p.id))
    from public.student_guardians sg, public.prospects p
    where sg.student_id=new.student_id and sg.guardian_id=g.id
      and p.id=new.prospect_id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_admission_student_details() from public, anon, authenticated;
drop trigger if exists admission_student_details_sync on public.admission_cases;
create trigger admission_student_details_sync
after update of student_id on public.admission_cases
for each row execute function public.sync_admission_student_details();

create or replace function public.create_staff_admission_intake(p_input jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  req uuid := nullif(p_input->>'request_id','')::uuid;
  reason text := btrim(coalesce(p_input->>'reason',''));
  existing public.staff_admission_intake_requests;
  offering public.programme_offerings;
  batch public.batches;
  organization public.organizations;
  prospect public.prospects;
  result jsonb;
  command_result jsonb;
  open_seats integer;
  local_today date;
  v_student_name text := btrim(coalesce(p_input->>'student_name',''));
  guardian_name text := btrim(coalesce(p_input->>'guardian_name',''));
  v_mobile text := regexp_replace(coalesce(p_input->>'mobile',''), '\D', '', 'g');
  birth_date date := nullif(p_input->>'date_of_birth','')::date;
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if req is null or length(reason)<5 then
    raise exception 'Request identity and an audit reason of at least five characters are required.';
  end if;
  if length(v_student_name)<2 or length(v_student_name)>160 or length(guardian_name)<2 or length(guardian_name)>160
    or v_mobile !~ '^01[3-9][0-9]{8}$' or length(btrim(coalesce(p_input->>'guardian_address','')))<5
    or coalesce((p_input->>'consent_to_contact')::boolean,false) is not true then
    raise exception 'Enter the student, guardian, valid mobile, address, and confirm permission to contact.';
  end if;
  if coalesce(p_input->>'gender','') not in ('','Female','Male','Other','Prefer not to say') then
    raise exception 'Choose a valid gender option or leave it blank.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,0));
  select * into existing from public.staff_admission_intake_requests where request_id=req;
  if found then
    if existing.actor_id<>actor or existing.payload<>p_input then
      raise exception 'Request identity was already used for different intake details.';
    end if;
    return jsonb_build_object('prospect_no',(select prospect_no from public.prospects where id=existing.prospect_id),
      'prospect_id',existing.prospect_id,'admission_id',existing.admission_id);
  end if;

  select * into offering from public.programme_offerings
    where id=nullif(p_input->>'offering_id','')::uuid and status='ACTIVE' for share;
  if offering.id is null then raise exception 'Choose an active programme offering.'; end if;
  select * into batch from public.batches
    where id=nullif(p_input->>'batch_id','')::uuid and is_active for update;
  if batch.id is null or batch.offering_id is distinct from offering.id then
    raise exception 'Choose an active batch belonging to the selected programme offering.';
  end if;
  select * into organization from public.organizations where id=offering.organization_id;
  select timezone(organization.timezone,now())::date into local_today;
  if not exists(select 1 from public.fee_plan_versions f where f.offering_id=offering.id
    and f.status='ACTIVE' and f.effective_from<=local_today) then
    raise exception 'Publish an effective Fee Plan for this offering before starting admission.';
  end if;
  select count(*) into open_seats from public.enrollments where batch_id=batch.id and status='ACTIVE';
  if open_seats>=least(batch.capacity,coalesce((select (payload->>'max_students')::integer
    from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'
    order by version desc limit 1),batch.capacity)) then
    raise exception 'The selected batch is full. Choose another available batch.';
  end if;
  if exists(select 1 from public.prospects p where p.organization_id=offering.organization_id
    and regexp_replace(p.mobile,'\D','','g')=v_mobile and lower(btrim(p.student_name))=lower(v_student_name)
    and p.status not in ('CONVERTED','LOST')) then
    raise exception 'A matching open Prospect already exists. Open Prospects and continue that record instead of creating a duplicate.';
  end if;

  insert into public.prospects (
    organization_id,branch_id,student_name,student_name_bn,guardian_name,
    guardian_relationship_snapshot,mobile,alternate_mobile,current_class_id,
    school_name_snapshot,school_roll,date_of_birth,gender,guardian_address,
    interested_offering_id,referral_note,consent_to_contact,status,submitted_via
  ) values (
    offering.organization_id,offering.branch_id,v_student_name,
    nullif(btrim(coalesce(p_input->>'student_name_bn','')),''),guardian_name,
    nullif(btrim(coalesce(p_input->>'guardian_relationship','')),''),v_mobile,
    nullif(regexp_replace(coalesce(p_input->>'alternate_mobile',''),'\D','','g'),''),
    offering.class_id,nullif(btrim(coalesce(p_input->>'school_name','')),''),
    nullif(btrim(coalesce(p_input->>'school_roll','')),''),birth_date,
    nullif(p_input->>'gender',''),btrim(p_input->>'guardian_address'),offering.id,
    nullif(btrim(coalesce(p_input->>'referral_note','')),''),true,'NEW','ERP'
  ) returning * into prospect;

  command_result := public.admission_command(jsonb_build_object(
    'action','CREATE','request_id',gen_random_uuid(),'reason',reason,
    'prospect_id',prospect.id,'offering_id',offering.id,'batch_id',batch.id
  ));
  update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(jsonb_build_object(
    'student_name_bn',prospect.student_name_bn,'gender',prospect.gender,
    'date_of_birth',prospect.date_of_birth,'school_roll',prospect.school_roll,
    'guardian_address',prospect.guardian_address,'alternate_mobile',prospect.alternate_mobile,
    'guardian_relationship',prospect.guardian_relationship_snapshot
  )) where id=(command_result->>'id')::uuid;

  result := jsonb_build_object('prospect_no',prospect.prospect_no,'prospect_id',prospect.id,
    'admission_id',command_result->>'id');
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    entity_type,entity_id,action,reason,before_data,after_data,metadata)
  values(req,actor,(select id from public.staff where profile_id=actor limit 1),
    'PROSPECT',prospect.id::text,'CREATE_STAFF_ADMISSION_INTAKE',reason,null,to_jsonb(prospect),
    jsonb_build_object('admission_id',command_result->>'id','offering_id',offering.id,'batch_id',batch.id));
  insert into public.staff_admission_intake_requests(request_id,actor_id,payload,prospect_id,admission_id)
  values(req,actor,p_input,prospect.id,(command_result->>'id')::uuid);
  return result;
end;
$$;
revoke all on function public.create_staff_admission_intake(jsonb) from public, anon;
grant execute on function public.create_staff_admission_intake(jsonb) to authenticated;
