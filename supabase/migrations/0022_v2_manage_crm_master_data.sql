-- Manage CRM: audited create/update for shared master data used by public forms and offerings.
-- Permission: system.master_data.manage. No hard deletes — deactivate only.

-- Allow manage policy on academic groups (select-only until now).
grant select, insert, update on public.academic_groups to authenticated;

drop policy if exists master_data_manage_academic_groups on public.academic_groups;
create policy master_data_manage_academic_groups
on public.academic_groups for all to authenticated
using (public.has_permission('system.master_data.manage'))
with check (public.has_permission('system.master_data.manage'));

create or replace function public.manage_crm_master_record(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_entity text := lower(btrim(coalesce(p_input->>'entity', '')));
  v_reason text := btrim(coalesce(p_input->>'reason', ''));
  v_id uuid := nullif(p_input->>'id', '')::uuid;
  v_correlation uuid := gen_random_uuid();
  v_before jsonb;
  v_after jsonb;
  v_action text;
  v_code text;
  v_name text;
  v_is_active boolean;
  v_sort integer;
  v_starts date;
  v_ends date;
  v_description text;
  v_area_id uuid;
  v_verified boolean;
begin
  if v_actor is null or not public.has_permission('system.master_data.manage') then
    raise exception 'You are not authorized to manage CRM master data.';
  end if;
  if length(v_reason) < 5 then
    raise exception 'A change reason of at least five characters is required.';
  end if;

  select id into v_org from public.organizations where code = 'SOHOJ' and is_active limit 1;
  if v_org is null then
    raise exception 'Organization is not available.';
  end if;

  v_name := nullif(btrim(coalesce(p_input->>'name', '')), '');
  v_code := nullif(upper(btrim(coalesce(p_input->>'code', ''))), '');
  v_is_active := coalesce((p_input->>'is_active')::boolean, true);
  v_sort := coalesce((p_input->>'sort_order')::integer, 0);
  v_description := nullif(btrim(coalesce(p_input->>'description', '')), '');
  v_starts := nullif(p_input->>'starts_on', '')::date;
  v_ends := nullif(p_input->>'ends_on', '')::date;
  v_area_id := nullif(p_input->>'area_id', '')::uuid;
  v_verified := coalesce((p_input->>'is_verified')::boolean, false);

  if v_entity = 'academic_year' then
    if v_name is null or length(v_name) < 2 then
      raise exception 'Academic year name is required.';
    end if;
    if v_starts is null or v_ends is null or v_ends < v_starts then
      raise exception 'Academic year needs a valid start and end date.';
    end if;
    if v_id is null then
      insert into public.academic_years (organization_id, name, starts_on, ends_on, is_active)
      values (v_org, v_name, v_starts, v_ends, false)
      returning to_jsonb(academic_years.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(y.*) into v_before from public.academic_years y where y.id = v_id and y.organization_id = v_org for update;
      if v_before is null then raise exception 'Academic year not found.'; end if;
      if v_is_active then
        update public.academic_years set is_active = false
        where organization_id = v_org and id <> v_id and is_active;
      end if;
      update public.academic_years
      set name = v_name, starts_on = v_starts, ends_on = v_ends, is_active = v_is_active
      where id = v_id
      returning to_jsonb(academic_years.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'class' then
    if v_code is null or length(v_code) < 1 then raise exception 'Class code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Class name is required.'; end if;
    if v_id is null then
      insert into public.classes (organization_id, code, name, sort_order, is_active)
      values (v_org, v_code, v_name, v_sort, v_is_active)
      returning to_jsonb(classes.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(c.*) into v_before from public.classes c where c.id = v_id and c.organization_id = v_org for update;
      if v_before is null then raise exception 'Class not found.'; end if;
      update public.classes
      set code = v_code, name = v_name, sort_order = v_sort, is_active = v_is_active
      where id = v_id
      returning to_jsonb(classes.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'group' then
    if v_code is null or length(v_code) < 1 then raise exception 'Group code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Group name is required.'; end if;
    if v_id is null then
      insert into public.academic_groups (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(academic_groups.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(g.*) into v_before from public.academic_groups g where g.id = v_id and g.organization_id = v_org for update;
      if v_before is null then raise exception 'Group not found.'; end if;
      update public.academic_groups
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(academic_groups.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'subject' then
    if v_code is null or length(v_code) < 1 then raise exception 'Subject code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Subject name is required.'; end if;
    if v_id is null then
      insert into public.subjects (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(subjects.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(s.*) into v_before from public.subjects s where s.id = v_id and s.organization_id = v_org for update;
      if v_before is null then raise exception 'Subject not found.'; end if;
      update public.subjects
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(subjects.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'program' then
    if v_code is null or length(v_code) < 1 then raise exception 'Programme code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Programme name is required.'; end if;
    if v_id is null then
      insert into public.programs (organization_id, code, name, description, is_active)
      values (v_org, v_code, v_name, v_description, v_is_active)
      returning to_jsonb(programs.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(p.*) into v_before from public.programs p where p.id = v_id and p.organization_id = v_org for update;
      if v_before is null then raise exception 'Programme not found.'; end if;
      update public.programs
      set code = v_code, name = v_name, description = v_description, is_active = v_is_active
      where id = v_id
      returning to_jsonb(programs.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'school' then
    if v_name is null or length(v_name) < 2 then raise exception 'School name is required.'; end if;
    if v_area_id is not null and not exists (
      select 1 from public.areas a where a.id = v_area_id and a.organization_id = v_org
    ) then
      raise exception 'Selected area is not available.';
    end if;
    if v_id is null then
      insert into public.schools (organization_id, area_id, name, is_verified, is_active, created_by)
      values (v_org, v_area_id, v_name, v_verified, v_is_active, v_actor)
      returning to_jsonb(schools.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(s.*) into v_before from public.schools s where s.id = v_id and s.organization_id = v_org for update;
      if v_before is null then raise exception 'School not found.'; end if;
      update public.schools
      set area_id = v_area_id, name = v_name, is_verified = v_verified, is_active = v_is_active, updated_at = now()
      where id = v_id
      returning to_jsonb(schools.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'lead_source' then
    if v_code is null or length(v_code) < 1 then raise exception 'Lead source code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Lead source name is required.'; end if;
    if v_id is null then
      insert into public.lead_sources (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(lead_sources.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(l.*) into v_before from public.lead_sources l where l.id = v_id and l.organization_id = v_org for update;
      if v_before is null then raise exception 'Lead source not found.'; end if;
      update public.lead_sources
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(lead_sources.*) into v_after;
      v_action := 'UPDATE';
    end if;

  elsif v_entity = 'guardian_relationship' then
    if v_code is null or length(v_code) < 1 then raise exception 'Relationship code is required.'; end if;
    if v_name is null or length(v_name) < 1 then raise exception 'Relationship name is required.'; end if;
    if v_id is null then
      insert into public.guardian_relationships (organization_id, code, name, is_active)
      values (v_org, v_code, v_name, v_is_active)
      returning to_jsonb(guardian_relationships.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(r.*) into v_before from public.guardian_relationships r where r.id = v_id and r.organization_id = v_org for update;
      if v_before is null then raise exception 'Relationship not found.'; end if;
      update public.guardian_relationships
      set code = v_code, name = v_name, is_active = v_is_active
      where id = v_id
      returning to_jsonb(guardian_relationships.*) into v_after;
      v_action := 'UPDATE';
    end if;

  else
    raise exception 'Unsupported master-data entity.';
  end if;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    null,
    upper(v_entity),
    v_id::text,
    v_action,
    v_reason,
    v_before,
    v_after,
    jsonb_build_object('source', 'manage_crm', 'entity', v_entity)
  );

  return jsonb_build_object(
    'id', v_id,
    'entity', v_entity,
    'action', v_action,
    'correlation_id', v_correlation
  );
exception
  when unique_violation then
    raise exception 'A record with the same code or name already exists.';
end;
$$;

revoke all on function public.manage_crm_master_record(jsonb) from public, anon;
grant execute on function public.manage_crm_master_record(jsonb) to authenticated;
