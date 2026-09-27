-- Completes open-offering validation inside submit_public_interest.
-- Replace submit RPC with offering validation while preserving existing behaviour.
create or replace function public.submit_public_interest(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org public.organizations;
  v_branch public.branches;
  v_prospect public.prospects;
  v_class public.classes;
  v_school public.schools;
  v_source public.lead_sources;
  v_relationship public.guardian_relationships;
  v_offering public.programme_offerings;
  v_program_id uuid;
  v_subject_id uuid;
  v_school_name text;
  v_relationship_text text;
  v_mobile text;
  v_correlation_id uuid := gen_random_uuid();
  v_offering_id uuid;
  v_intent text;
  v_today date := (timezone('utc', now()))::date;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Interest request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'student_name','')), '') is null then
    raise exception 'Student name is required.';
  end if;

  if nullif(btrim(coalesce(p_payload->>'guardian_name','')), '') is null then
    raise exception 'Guardian name is required.';
  end if;

  v_mobile := nullif(btrim(coalesce(p_payload->>'mobile','')), '');

  if v_mobile is null or length(regexp_replace(v_mobile, '\D', '', 'g')) < 10 then
    raise exception 'A valid mobile number is required.';
  end if;

  if coalesce((p_payload->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Consent to contact is required.';
  end if;

  v_intent := lower(coalesce(nullif(btrim(p_payload->>'intent'), ''), 'interest'));
  if v_intent not in ('interest', 'admission') then
    raise exception 'Invalid submission intent.';
  end if;

  select * into v_org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  select * into v_branch
  from public.branches
  where organization_id=v_org.id and code='MAIN' and is_active
  limit 1;

  v_offering_id := nullif(btrim(coalesce(p_payload->>'offering_id','')), '')::uuid;
  if v_offering_id is not null then
    select * into v_offering
    from public.programme_offerings
    where id = v_offering_id
      and organization_id = v_org.id
      and status = 'ACTIVE';

    if v_offering.id is null then
      raise exception 'Selected programme offering is not available.';
    end if;

    if coalesce(v_offering.is_accepting_applications, false) is not true then
      raise exception 'Applications are closed for this programme offering.';
    end if;

    if v_offering.applications_open_on is not null and v_today < v_offering.applications_open_on then
      raise exception 'Applications are not open yet for this programme offering.';
    end if;

    if v_offering.applications_close_on is not null and v_today > v_offering.applications_close_on then
      raise exception 'Applications are closed for this programme offering.';
    end if;

    if v_offering.branch_id is not null then
      select * into v_branch
      from public.branches
      where id = v_offering.branch_id and is_active;
    end if;
  elsif v_intent = 'admission' then
    raise exception 'An open programme offering is required for admission applications.';
  end if;

  begin
    select * into v_class
    from public.classes
    where id=(p_payload->>'class_id')::uuid
      and organization_id=v_org.id
      and is_active;
  exception when others then
    raise exception 'Selected class is not available.';
  end;

  if v_class.id is null then
    raise exception 'Selected class is not available.';
  end if;

  if v_offering.id is not null and v_class.id is distinct from v_offering.class_id then
    raise exception 'Selected class does not match the chosen programme offering.';
  end if;

  if exists (
    select 1
    from public.prospects p
    where regexp_replace(p.mobile, '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and p.current_class_id=v_class.id
      and p.created_at > now() - interval '10 minutes'
  ) then
    raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
  end if;

  v_school_name := nullif(btrim(coalesce(p_payload->>'school_name_snapshot','')), '');

  if nullif(p_payload->>'school_id','') is not null then
    begin
      select * into v_school
      from public.schools
      where id=(p_payload->>'school_id')::uuid
        and organization_id=v_org.id
        and is_active;
    exception when others then
      raise exception 'Selected school is not available.';
    end;

    if v_school.id is null then
      raise exception 'Selected school is not available.';
    end if;

    v_school_name := coalesce(v_school_name, v_school.name);
  elsif v_school_name is not null then
    select * into v_school
    from public.schools
    where organization_id=v_org.id
      and lower(btrim(name))=lower(v_school_name)
      and is_active
    order by is_verified desc, created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools(
        organization_id,
        name,
        is_verified,
        is_active
      )
      values(
        v_org.id,
        v_school_name,
        false,
        true
      )
      returning * into v_school;
    end if;

    v_school_name := v_school.name;
  end if;

  if nullif(p_payload->>'source_code','') is not null then
    select * into v_source
    from public.lead_sources
    where organization_id=v_org.id
      and code=upper(p_payload->>'source_code')
      and is_active;

    if v_source.id is null then
      raise exception 'Selected source is not available.';
    end if;
  end if;

  v_relationship_text := nullif(btrim(coalesce(p_payload->>'guardian_relationship','')), '');

  if v_relationship_text is not null then
    select * into v_relationship
    from public.guardian_relationships
    where organization_id=v_org.id
      and (
        upper(code)=upper(replace(v_relationship_text,' ','_'))
        or lower(name)=lower(v_relationship_text)
      )
      and is_active
    limit 1;
  end if;

  insert into public.prospects(
    organization_id,
    branch_id,
    student_name,
    student_name_bn,
    guardian_name,
    guardian_relationship_id,
    guardian_relationship_snapshot,
    mobile,
    alternate_mobile,
    current_class_id,
    school_id,
    school_name_snapshot,
    area_snapshot,
    preferred_schedule,
    preferred_days,
    trial_interest,
    source_id,
    referral_note,
    notes,
    consent_to_contact,
    submitted_via,
    interested_offering_id,
    submission_intent
  )
  values(
    v_org.id,
    v_branch.id,
    btrim(p_payload->>'student_name'),
    nullif(btrim(coalesce(p_payload->>'student_name_bn','')), ''),
    btrim(p_payload->>'guardian_name'),
    v_relationship.id,
    v_relationship_text,
    v_mobile,
    nullif(btrim(coalesce(p_payload->>'alternate_mobile','')), ''),
    v_class.id,
    v_school.id,
    v_school_name,
    nullif(btrim(coalesce(p_payload->>'area','')), ''),
    nullif(btrim(coalesce(p_payload->>'preferred_schedule','')), ''),
    case
      when nullif(btrim(coalesce(p_payload->>'preferred_days','')), '') is null
        then '{}'::text[]
      else string_to_array(p_payload->>'preferred_days', ',')
    end,
    coalesce((p_payload->>'trial_interest')::boolean, false),
    v_source.id,
    nullif(btrim(coalesce(p_payload->>'referral_note','')), ''),
    nullif(btrim(coalesce(p_payload->>'notes','')), ''),
    true,
    'PUBLIC_WEB',
    v_offering.id,
    v_intent
  )
  returning * into v_prospect;

  for v_program_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'program_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.programs
      where id=v_program_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected program is not available.';
    end if;

    insert into public.prospect_program_interests(prospect_id,program_id)
    values(v_prospect.id,v_program_id)
    on conflict do nothing;
  end loop;

  if v_offering.id is not null then
    insert into public.prospect_program_interests(prospect_id,program_id)
    values(v_prospect.id, v_offering.program_id)
    on conflict do nothing;
  end if;

  for v_subject_id in
    select value::text::uuid
    from jsonb_array_elements_text(coalesce(p_payload->'subject_ids','[]'::jsonb))
  loop
    if not exists (
      select 1
      from public.subjects
      where id=v_subject_id
        and organization_id=v_org.id
        and is_active
    ) then
      raise exception 'One selected subject is not available.';
    end if;

    if v_offering.id is not null and not exists (
      select 1 from public.programme_offering_subjects
      where offering_id = v_offering.id and subject_id = v_subject_id
    ) then
      raise exception 'One selected subject is not part of the chosen programme offering.';
    end if;

    insert into public.prospect_subject_interests(prospect_id,subject_id)
    values(v_prospect.id,v_subject_id)
    on conflict do nothing;
  end loop;

  insert into public.audit_events(
    correlation_id,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    'PROSPECT',
    v_prospect.id::text,
    'CREATE_PUBLIC_INTEREST',
    jsonb_build_object(
      'prospect_no',v_prospect.prospect_no,
      'student_name',v_prospect.student_name,
      'current_class_id',v_prospect.current_class_id,
      'source_id',v_prospect.source_id,
      'trial_interest',v_prospect.trial_interest,
      'interested_offering_id',v_prospect.interested_offering_id,
      'submission_intent',v_prospect.submission_intent
    ),
    jsonb_build_object('submitted_via','PUBLIC_WEB')
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no
  );
end;
$$;

revoke all on function public.submit_public_interest(jsonb) from public;
grant execute on function public.submit_public_interest(jsonb) to anon, authenticated;
