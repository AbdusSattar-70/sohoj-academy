-- Batch register read model and audited create/edit workflow.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,'classId',b.class_id,'capacity',b.capacity,'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE'))) from public.batches b where b.is_active and b.offering_id is not null),'[]'::jsonb),$old$;
  new_block := $new$'batches',coalesce((select jsonb_agg(jsonb_build_object(
    'id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,
    'offeringName',o.name,'classId',b.class_id,'className',c.name,
    'yearName',y.name,'branchName',br.name,'capacity',b.capacity,
    'isActive',b.is_active,
    'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE')
  ) order by y.starts_on desc,o.name,b.name)
    from public.batches b
    join public.programme_offerings o on o.id=b.offering_id
    join public.classes c on c.id=b.class_id
    join public.academic_years y on y.id=b.academic_year_id
    left join public.branches br on br.id=b.branch_id
  ),'[]'::jsonb),$new$;
  if position(old_block in definition)=0 then
    raise exception 'Cannot update batch register read model; expected definition changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

create or replace function public.batch_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid(); req uuid:=nullif(p_input->>'request_id','')::uuid;
 action text:=p_input->>'action'; reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys; org uuid; batch public.batches;
 offering public.programme_offerings; policy public.business_rule_versions;
 v_requested_capacity integer; occupied integer; before_data jsonb; result jsonb;
begin
 if actor is null or not public.has_permission('academics.manage') then
  raise exception 'Batch management permission required.';
 end if;
 if req is null or length(reason)<5 then raise exception 'Request identity and a reason of at least five characters are required.'; end if;
 if action not in('CREATE_BATCH','EDIT_BATCH') then raise exception 'Unsupported batch action.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
  return key.result;
 end if;
 select id into org from public.organizations where code='SOHOJ' and is_active limit 1;
 select * into policy from public.business_rule_versions where domain='academics'
   and rule_key='batch_capacity_policy' and status='ACTIVE' order by version desc limit 1;
 if org is null or policy.id is null then raise exception 'Organization or active capacity policy is unavailable.'; end if;
 v_requested_capacity:=nullif(p_input->>'capacity','')::integer;
 if v_requested_capacity is null or v_requested_capacity<1 or v_requested_capacity>(policy.payload->>'max_students')::integer then
   raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',policy.payload->>'max_students';
 end if;
 if length(btrim(coalesce(p_input->>'name','')))<2 or length(btrim(coalesce(p_input->>'code','')))<2 then
   raise exception 'Enter a batch code and a recognizable batch name.';
 end if;
 if action='CREATE_BATCH' then
  select * into offering from public.programme_offerings
   where id=(p_input->>'offering_id')::uuid and organization_id=org and status='ACTIVE' for update;
  if offering.id is null then raise exception 'Choose an active offering with a published Fee Plan.'; end if;
  insert into public.batches(organization_id,branch_id,academic_year_id,class_id,program_id,
   code,name,capacity,created_by,offering_id,capacity_policy_version_id)
  values(org,offering.branch_id,offering.academic_year_id,offering.class_id,offering.program_id,
   upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_requested_capacity,actor,offering.id,policy.id)
  returning * into batch;
  result:=jsonb_build_object('id',batch.id,'status','CREATED');
 else
  select * into batch from public.batches where id=(p_input->>'batch_id')::uuid
    and organization_id=org and offering_id is not null for update;
  if batch.id is null then raise exception 'Batch not found.'; end if;
  before_data:=to_jsonb(batch);
  select count(*) into occupied from public.enrollments where batch_id=batch.id and status='ACTIVE';
  if v_requested_capacity<occupied then raise exception 'Capacity cannot be lower than the % students already enrolled.',occupied; end if;
  update public.batches b set code=upper(btrim(p_input->>'code')),
    name=btrim(p_input->>'name'),capacity=v_requested_capacity,
    capacity_policy_version_id=policy.id,updated_at=now()
  where b.id=batch.id returning b.* into batch;
  result:=jsonb_build_object('id',batch.id,'status','UPDATED');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
   entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,(select id from public.staff where profile_id=actor limit 1),
   'BATCH',batch.id::text,action,reason,
   before_data,
   to_jsonb(batch),jsonb_build_object('module','batch_register','offering_id',batch.offering_id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end $$;
revoke all on function public.batch_command(jsonb) from public,anon;
grant execute on function public.batch_command(jsonb) to authenticated;

do $migration$
declare definition text; anchor text; guard text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  anchor := $anchor$if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;$anchor$;
  guard := $guard$if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;
   if coalesce((p_input->>'capacity')::integer,0)<1
      or (p_input->>'capacity')::integer>(v_capacity.payload->>'max_students')::integer then
     raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',v_capacity.payload->>'max_students';
   end if;$guard$;
  if position(anchor in definition)=0 then raise exception 'Cannot enforce batch capacity in admission command; expected guard changed.'; end if;
  execute replace(definition,anchor,guard);
end;
$migration$;
