-- Audited, lifecycle-aware Programme Offering updates.
create or replace function public.update_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_actor uuid:=auth.uid();
  v_request uuid:=nullif(p_input->>'request_id','')::uuid;
  v_reason text:=btrim(coalesce(p_input->>'reason',''));
  v_org uuid;
  v_row public.programme_offerings;
  v_before jsonb;
  v_result jsonb;
  v_branch uuid:=(p_input->>'branch_id')::uuid;
  v_year uuid:=(p_input->>'academic_year_id')::uuid;
  v_class uuid:=(p_input->>'class_id')::uuid;
  v_program uuid:=(p_input->>'program_id')::uuid;
  v_group uuid:=nullif(p_input->>'group_id','')::uuid;
  v_code text:=upper(btrim(coalesce(p_input->>'code','')));
  v_name text:=btrim(coalesce(p_input->>'name',''));
  v_existing public.admission_command_keys;
begin
  if v_actor is null or not public.has_permission('academics.manage') then raise exception 'You are not authorized to manage Programme Offerings.'; end if;
  if v_request is null then raise exception 'A request identity is required.'; end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  if length(v_code)<2 or length(v_code)>40 or v_code !~ '^[A-Z0-9_-]+$' then raise exception 'Use a valid offering code with letters, numbers, underscores or hyphens.'; end if;
  if length(v_name)<2 or length(v_name)>160 then raise exception 'Enter a recognizable offering name.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
  select * into v_existing from public.admission_command_keys where request_id=v_request;
  if found then
    if v_existing.actor_id<>v_actor or v_existing.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
    return v_existing.result;
  end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active limit 1;
  select * into v_row from public.programme_offerings where id=(p_input->>'offering_id')::uuid and organization_id=v_org for update;
  if v_row.id is null then raise exception 'Programme Offering not found.'; end if;
  if v_row.status='RETIRED' then raise exception 'Retired offerings are read-only.'; end if;
  v_before:=to_jsonb(v_row);
  if v_row.status='ACTIVE' and (
    v_branch is distinct from v_row.branch_id or v_year is distinct from v_row.academic_year_id
    or v_class is distinct from v_row.class_id or v_program is distinct from v_row.program_id
    or v_group is distinct from v_row.group_id
  ) then raise exception 'Academic context cannot change after activation. Create a new offering for a new year, class, branch or programme.'; end if;
  if v_row.status='DRAFT' and exists(select 1 from public.batches where offering_id=v_row.id) and (
    v_branch is distinct from v_row.branch_id or v_year is distinct from v_row.academic_year_id
    or v_class is distinct from v_row.class_id or v_program is distinct from v_row.program_id
    or v_group is distinct from v_row.group_id
  ) then raise exception 'Academic context cannot change after batches reference this offering.'; end if;
  if v_row.status='DRAFT' and not exists (
    select 1 from public.branches b join public.academic_years y on y.id=v_year
    join public.classes c on c.id=v_class join public.programs p on p.id=v_program
    where b.id=v_branch and b.is_active and b.organization_id=v_org and y.organization_id=v_org
      and c.organization_id=v_org and c.is_active and p.organization_id=v_org and p.is_active
      and (v_group is null or exists(select 1 from public.academic_groups g where g.id=v_group and g.organization_id=v_org and g.is_active))
  ) then raise exception 'Offering context must use active master data from the same organization.'; end if;
  update public.programme_offerings set
    branch_id=case when status='DRAFT' then v_branch else branch_id end,
    academic_year_id=case when status='DRAFT' then v_year else academic_year_id end,
    class_id=case when status='DRAFT' then v_class else class_id end,
    program_id=case when status='DRAFT' then v_program else program_id end,
    group_id=case when status='DRAFT' then v_group else group_id end,
    code=v_code,name=v_name
  where id=v_row.id returning * into v_row;
  v_result:=jsonb_build_object('offering_id',v_row.id,'correlation_id',v_request);
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,branch_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
  values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'UPDATE',v_reason,v_before,to_jsonb(v_row),jsonb_build_object('request_id',v_request,'status',v_row.status));
  insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
  return v_result;
end $$;
revoke all on function public.update_programme_offering(jsonb) from public,anon;
grant execute on function public.update_programme_offering(jsonb) to authenticated;
