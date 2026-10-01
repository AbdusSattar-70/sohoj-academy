-- Sohoj Academy fresh database baseline: platform crm setup workflows.
-- Install on an empty application schema. Each object is defined once.

create view public.current_fee_plans with (security_invoker=true) as
 SELECT DISTINCT ON (offering_id) id,
    offering_id,
    version,
    status,
    billing_cycle,
    due_day,
    currency_code,
    effective_from,
    effective_to,
    change_reason,
    created_by,
    created_at
   FROM fee_plan_versions fp
  WHERE status = ANY (ARRAY['ACTIVE'::rule_status, 'RETIRED'::rule_status, 'DRAFT'::rule_status])
  ORDER BY offering_id, (
        CASE
            WHEN status = 'ACTIVE'::rule_status THEN 0
            ELSE 1
        END), effective_from DESC, created_at DESC, version DESC;

create view public.current_fee_plan_components with (security_invoker=true) as
 SELECT c.id,
    c.fee_plan_version_id,
    c.code,
    c.name,
    c.amount,
    c.charge_type,
    c.recurrence,
    c.sort_order
   FROM fee_plan_components c
     JOIN current_fee_plans fp ON fp.id = c.fee_plan_version_id;

create view public.current_operating_rules with (security_invoker=true) as
 SELECT DISTINCT ON (domain, rule_key) id,
    domain,
    rule_key,
    status,
    payload
   FROM business_rule_versions r
  WHERE status = ANY (ARRAY['ACTIVE'::rule_status, 'RETIRED'::rule_status, 'DRAFT'::rule_status])
  ORDER BY domain, rule_key, (
        CASE
            WHEN status = 'ACTIVE'::rule_status THEN 0
            ELSE 1
        END), version DESC;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles(id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email,''), '@', 1), ''),
      'User'
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.has_permission(p_permission_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.user_role_assignments ura
    join public.system_roles sr on sr.id = ura.role_id
    join public.role_permissions rp on rp.role_id = sr.id
    join public.permissions p on p.id = rp.permission_id
    join public.profiles pr on pr.id = ura.profile_id
    where ura.profile_id = auth.uid()
      and ura.is_active
      and (ura.effective_to is null or ura.effective_to >= current_date)
      and ura.effective_from <= current_date
      and sr.is_active
      and pr.status = 'ACTIVE'
      and p.code = p_permission_code
  );
$function$;

CREATE OR REPLACE FUNCTION public.my_erp_context()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'profile_id', p.id,
    'display_name', p.display_name,
    'status', p.status,
    'staff_id', s.id,
    'staff_no', s.staff_no,
    'staff_name', s.full_name,
    'roles', coalesce((
      select jsonb_agg(distinct sr.code order by sr.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct pe.code order by pe.code)
      from public.user_role_assignments ura
      join public.system_roles sr on sr.id = ura.role_id
      join public.role_permissions rp on rp.role_id = sr.id
      join public.permissions pe on pe.id = rp.permission_id
      where ura.profile_id = p.id
        and ura.is_active
        and ura.effective_from <= current_date
        and (ura.effective_to is null or ura.effective_to >= current_date)
        and sr.is_active
    ), '[]'::jsonb)
  )
  from public.profiles p
  left join public.staff s on s.profile_id = p.id
  where p.id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.bootstrap_admin(p_email text, p_full_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_user auth.users;
  v_profile public.profiles;
  v_role public.system_roles;
  v_staff public.staff;
  v_staff_role public.staff_roles;
  v_branch public.branches;
begin
  select * into v_user
  from auth.users
  where lower(email) = lower(btrim(p_email))
  order by created_at asc
  limit 1;

  if v_user.id is null then
    raise exception 'Auth user not found for email %', p_email;
  end if;

  insert into public.profiles(id, display_name, status)
  values (
    v_user.id,
    coalesce(
      nullif(btrim(p_full_name), ''),
      nullif(v_user.raw_user_meta_data ->> 'full_name', ''),
      split_part(v_user.email, '@', 1)
    ),
    'ACTIVE'
  )
  on conflict (id) do update
  set
    display_name = excluded.display_name,
    status = 'ACTIVE',
    updated_at = now()
  returning * into v_profile;

  select * into v_role
  from public.system_roles
  where code = 'ADMIN';

  select * into v_staff_role
  from public.staff_roles
  where code = 'ADMINISTRATION';

  select * into v_branch
  from public.branches
  where code = 'MAIN'
  order by created_at asc
  limit 1;

  select * into v_staff
  from public.staff
  where profile_id = v_profile.id;

  if v_staff.id is null then
    insert into public.staff(
      profile_id,
      branch_id,
      full_name,
      email,
      joined_on,
      status
    )
    values (
      v_profile.id,
      v_branch.id,
      v_profile.display_name,
      v_user.email,
      current_date,
      'ACTIVE'
    )
    returning * into v_staff;
  end if;

  insert into public.user_role_assignments(
    profile_id,
    role_id,
    branch_id,
    is_active
  )
  values (
    v_profile.id,
    v_role.id,
    null,
    true
  )
  on conflict do nothing;

  insert into public.staff_role_assignments(
    staff_id,
    staff_role_id,
    branch_id,
    effective_from,
    is_primary
  )
  select
    v_staff.id,
    v_staff_role.id,
    v_branch.id,
    current_date,
    true
  where not exists (
    select 1
    from public.staff_role_assignments sra
    where sra.staff_id = v_staff.id
      and sra.staff_role_id = v_staff_role.id
      and sra.effective_to is null
  );

  return jsonb_build_object(
    'profile_id', v_profile.id,
    'staff_id', v_staff.id,
    'staff_no', v_staff.staff_no,
    'role', 'ADMIN'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_approval_decision()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.status <> 'PENDING' and new.status is distinct from old.status then
    raise exception 'A decided approval request cannot be decided again.';
  end if;

  if new.status = 'APPROVED' and old.requested_by = new.decided_by then
    raise exception 'Maker-checker violation: requester cannot approve their own request.';
  end if;

  if new.status in ('APPROVED','REJECTED','CANCELLED') then
    if new.decided_by is null then
      raise exception 'Decision actor is required.';
    end if;
    if new.decided_at is null then
      new.decided_at := now();
    end if;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.protect_active_business_rule()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if tg_op = 'DELETE' then
    raise exception 'Business rule versions are never deleted.';
  end if;

  if old.status = 'ACTIVE' and (
    new.domain is distinct from old.domain
    or new.rule_key is distinct from old.rule_key
    or new.version is distinct from old.version
    or new.payload is distinct from old.payload
    or new.effective_from is distinct from old.effective_from
  ) then
    raise exception 'Active business rule content is immutable. Retire it and create a new version.';
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_public_interest(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 org public.organizations; branch public.branches; applicant public.prospects;
 mobile_value text; snapshot jsonb; item jsonb; correlation uuid:=gen_random_uuid();
begin
 if jsonb_typeof(p_payload) is distinct from 'object' or octet_length(p_payload::text)>16000 then
  raise exception 'Enter a valid application.';
 end if;
 if length(btrim(coalesce(p_payload->>'student_name',''))) not between 2 and 160
 or length(btrim(coalesce(p_payload->>'guardian_name',''))) not between 2 and 160 then
  raise exception 'Student and guardian names are required.';
 end if;
 mobile_value:=regexp_replace(coalesce(p_payload->>'mobile',''),'\D','','g');
 if mobile_value !~ '^01[3-9][0-9]{8}$' then raise exception 'A valid mobile number is required.'; end if;
 if coalesce((p_payload->>'consent_to_contact')::boolean,false) is not true then
  raise exception 'Consent to contact is required.';
 end if;
 select * into org from public.organizations where code='SOHOJ' and is_active limit 1;
 if org.id is null then raise exception 'The academy is not accepting applications yet.'; end if;
 select * into branch from public.branches where organization_id=org.id and is_active order by created_at limit 1;
 perform pg_advisory_xact_lock(hashtextextended(mobile_value,3));
 if exists(select 1 from public.prospects p where p.mobile=mobile_value
   and lower(p.student_name)=lower(btrim(p_payload->>'student_name'))
   and p.created_at>now()-interval '2 minutes') then
  raise exception 'A similar interest request was submitted recently. Please wait before submitting again.';
 end if;
 -- Preserve submitted IDs and text. Labels are captured for review, never FK links.
 snapshot:=p_payload||jsonb_build_object('verification','UNVERIFIED',
   'class_label',(select name from public.classes where id::text=p_payload->>'class_id' and organization_id=org.id),
   'offering_label',(select name from public.programme_offerings where id::text=p_payload->>'offering_id' and organization_id=org.id),
   'program_labels',coalesce((select jsonb_agg(name) from public.programs where organization_id=org.id
     and coalesce(p_payload->'program_ids','[]'::jsonb) ? id::text),'[]'::jsonb),
   'subject_labels',coalesce((select jsonb_agg(name) from public.subjects where organization_id=org.id
     and coalesce(p_payload->'subject_ids','[]'::jsonb) ? id::text),'[]'::jsonb));
 insert into public.prospects(organization_id,branch_id,student_name,student_name_bn,
  guardian_name,guardian_relationship_snapshot,mobile,alternate_mobile,
  school_name_snapshot,area_snapshot,guardian_address,referral_note,notes,
  consent_to_contact,submitted_via,submission_intent,application_snapshot)
 values(org.id,branch.id,btrim(p_payload->>'student_name'),nullif(btrim(p_payload->>'student_name_bn'),''),
  btrim(p_payload->>'guardian_name'),nullif(btrim(p_payload->>'guardian_relationship'),''),
  mobile_value,nullif(btrim(p_payload->>'alternate_mobile'),''),
  coalesce(nullif(btrim(p_payload->>'school_name_snapshot'),''),
   (select name from public.schools where id::text=p_payload->>'school_id' and organization_id=org.id)),
  nullif(btrim(p_payload->>'area'),''),nullif(btrim(p_payload->>'guardian_address'),''),
  nullif(btrim(p_payload->>'referral_note'),''),nullif(btrim(p_payload->>'notes'),''),
  true,'PUBLIC_WEB',case when p_payload->>'intent'='admission' then 'admission' else 'interest' end,snapshot) returning * into applicant;
 insert into public.audit_events(correlation_id,entity_type,entity_id,action,metadata)
 values(correlation,'PROSPECT',applicant.id::text,'RECEIVE_UNVERIFIED_APPLICATION',
  jsonb_build_object('intent',p_payload->>'intent','verification','UNVERIFIED'));
 return jsonb_build_object('prospect_no',applicant.prospect_no,'prospect_id',applicant.id);
end $function$;

CREATE OR REPLACE FUNCTION public.create_staff_member(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_staff public.staff;
  v_role public.staff_roles;
  v_branch public.branches;
  v_subject_id uuid;
  v_subjects jsonb;
  v_mobile text;
  v_joined_on date;
  v_correlation_id uuid := gen_random_uuid();
  v_actor_role text;
begin
  if v_actor is null or not public.has_permission('staff.manage') then
    raise exception 'You are not authorized to create Staff identities.';
  end if;

  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Staff request must be a JSON object.';
  end if;

  if nullif(btrim(coalesce(p_input->>'full_name','')), '') is null then
    raise exception 'Full name is required.';
  end if;

  select * into v_role
  from public.staff_roles
  where code=upper(btrim(coalesce(p_input->>'staff_role_code','')))
    and is_active;

  if v_role.id is null then
    raise exception 'Select a valid Staff role.';
  end if;

  if nullif(p_input->>'branch_id','') is not null then
    begin
      select * into v_branch
      from public.branches
      where id=(p_input->>'branch_id')::uuid
        and is_active;
    exception when others then
      raise exception 'Selected branch is invalid.';
    end;
  else
    select * into v_branch
    from public.branches
    where code='MAIN' and is_active
    order by created_at asc
    limit 1;
  end if;

  if v_branch.id is null then
    raise exception 'An active branch is required.';
  end if;

  begin
    v_joined_on := coalesce(
      nullif(p_input->>'joined_on','')::date,
      current_date
    );
  exception when others then
    raise exception 'Joining date is invalid.';
  end;

  v_mobile := nullif(btrim(coalesce(p_input->>'mobile','')), '');

  if v_mobile is not null and exists (
    select 1
    from public.staff s
    where regexp_replace(coalesce(s.mobile,''), '\D', '', 'g')
        = regexp_replace(v_mobile, '\D', '', 'g')
      and s.status in ('ACTIVE','ON_LEAVE')
  ) then
    raise exception 'Another active Staff identity already uses this mobile number.';
  end if;

  insert into public.staff(
    branch_id,
    full_name,
    mobile,
    alternate_mobile,
    email,
    address,
    emergency_contact_name,
    emergency_contact_mobile,
    joined_on,
    status,
    notes,
    created_by
  )
  values(
    v_branch.id,
    btrim(p_input->>'full_name'),
    v_mobile,
    nullif(btrim(coalesce(p_input->>'alternate_mobile','')), ''),
    nullif(lower(btrim(coalesce(p_input->>'email',''))), ''),
    nullif(btrim(coalesce(p_input->>'address','')), ''),
    nullif(btrim(coalesce(p_input->>'emergency_contact_name','')), ''),
    nullif(btrim(coalesce(p_input->>'emergency_contact_mobile','')), ''),
    v_joined_on,
    'ACTIVE',
    nullif(btrim(coalesce(p_input->>'notes','')), ''),
    v_actor
  )
  returning * into v_staff;

  insert into public.staff_role_assignments(
    staff_id,
    staff_role_id,
    branch_id,
    effective_from,
    is_primary,
    assigned_by
  )
  values(
    v_staff.id,
    v_role.id,
    v_branch.id,
    v_joined_on,
    true,
    v_actor
  );

  v_subjects := coalesce(p_input->'subject_ids','[]'::jsonb);

  if jsonb_typeof(v_subjects) <> 'array' then
    raise exception 'Teaching subject selection must be an array.';
  end if;

  if not v_role.is_teaching_role
     and jsonb_array_length(v_subjects) > 0 then
    raise exception 'Teaching subjects can only be selected for a teaching Staff role.';
  end if;

  for v_subject_id in
    select value::text::uuid
    from jsonb_array_elements_text(v_subjects)
  loop
    if not exists (
      select 1 from public.subjects
      where id=v_subject_id and is_active
    ) then
      raise exception 'One selected subject is not available.';
    end if;

    insert into public.staff_subject_assignments(
      staff_id,
      subject_id,
      effective_from,
      assigned_by
    )
    values(
      v_staff.id,
      v_subject_id,
      v_joined_on,
      v_actor
    );
  end loop;

  select sr.code into v_actor_role
  from public.user_role_assignments ura
  join public.system_roles sr on sr.id=ura.role_id
  where ura.profile_id=v_actor
    and ura.is_active
    and ura.effective_from<=current_date
    and (ura.effective_to is null or ura.effective_to>=current_date)
  order by case when sr.code='ADMIN' then 0 else 1 end, sr.code
  limit 1;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    actor_role_code,
    branch_id,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    v_actor_role,
    v_branch.id,
    'STAFF',
    v_staff.id::text,
    'CREATE',
    jsonb_build_object(
      'staff_no',v_staff.staff_no,
      'full_name',v_staff.full_name,
      'staff_role_code',v_role.code,
      'joined_on',v_staff.joined_on,
      'status',v_staff.status
    ),
    jsonb_build_object(
      'workflow','CREATE_STAFF_MEMBER',
      'subject_count',jsonb_array_length(v_subjects)
    )
  );

  return jsonb_build_object(
    'staff_id',v_staff.id,
    'staff_no',v_staff.staff_no,
    'correlation_id',v_correlation_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.is_valid_prospect_transition(p_from prospect_status, p_to prospect_status)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select
    p_from = p_to
    or (p_from='NEW' and p_to in ('CONTACTED','COUNSELLING','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='CONTACTED' and p_to in ('COUNSELLING','TRIAL_SCHEDULED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='COUNSELLING' and p_to in ('TRIAL_SCHEDULED','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_SCHEDULED' and p_to in ('TRIAL_ATTENDED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_ATTENDED' and p_to in ('COUNSELLING','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='REGISTERED' and p_to='LOST')
    or (p_from='FUTURE_FOLLOW_UP' and p_to in ('CONTACTED','COUNSELLING','TRIAL_SCHEDULED','LOST'))
    or (p_from='LOST' and p_to='FUTURE_FOLLOW_UP');
$function$;

CREATE OR REPLACE FUNCTION public.record_prospect_followup(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_prospect public.prospects;
  v_followup public.prospect_followups;
  v_followup_type text;
  v_new_status public.prospect_status;
  v_next_follow_up_at timestamptz;
  v_notes text;
  v_outcome text;
  v_lost_reason text;
  v_correlation_id uuid := gen_random_uuid();
  v_actor_role text;
  v_before jsonb;
begin
  if v_actor is null or not public.has_permission('crm.followups.manage') then
    raise exception 'You are not authorized to record CRM follow-ups.';
  end if;

  begin
    select * into v_prospect
    from public.prospects
    where id=(p_input->>'prospect_id')::uuid
    for update;
  exception when others then
    raise exception 'Prospect identity is invalid.';
  end;

  if v_prospect.id is null then
    raise exception 'Prospect was not found.';
  end if;

  if v_prospect.status='CONVERTED' then
    raise exception 'Converted prospects are read-only in CRM. Continue from the Student record.';
  end if;

  v_followup_type := upper(btrim(coalesce(p_input->>'followup_type','')));
  if v_followup_type not in ('CALL','WHATSAPP','IN_PERSON','COUNSELLING','TRIAL','OTHER') then
    raise exception 'Select a valid follow-up type.';
  end if;

  v_notes := nullif(btrim(coalesce(p_input->>'notes','')), '');
  if v_notes is null then
    raise exception 'Follow-up notes are required.';
  end if;

  v_outcome := nullif(btrim(coalesce(p_input->>'outcome','')), '');
  v_lost_reason := nullif(btrim(coalesce(p_input->>'lost_reason','')), '');

  begin
    v_new_status := coalesce(
      nullif(p_input->>'new_status','')::public.prospect_status,
      v_prospect.status
    );
    v_next_follow_up_at := nullif(p_input->>'next_follow_up_at','')::timestamptz;
  exception when others then
    raise exception 'Follow-up status or next follow-up date is invalid.';
  end;

  if not public.is_valid_prospect_transition(v_prospect.status,v_new_status) then
    raise exception 'Prospect status cannot move from % to % through a follow-up.', v_prospect.status, v_new_status;
  end if;

  if v_new_status='LOST' and v_lost_reason is null then
    raise exception 'Lost reason is required when a prospect is marked LOST.';
  end if;

  if v_new_status='FUTURE_FOLLOW_UP' and v_next_follow_up_at is null then
    raise exception 'Next follow-up date is required for FUTURE FOLLOW UP.';
  end if;

  v_before := to_jsonb(v_prospect);

  insert into public.prospect_followups(
    prospect_id,
    followup_type,
    occurred_at,
    outcome,
    notes,
    next_follow_up_at,
    recorded_by
  )
  values(
    v_prospect.id,
    v_followup_type,
    now(),
    v_outcome,
    v_notes,
    v_next_follow_up_at,
    v_actor
  )
  returning * into v_followup;

  update public.prospects
  set
    status=v_new_status,
    next_follow_up_at=v_next_follow_up_at,
    lost_reason=case
      when v_new_status='LOST' then v_lost_reason
      when v_prospect.status='LOST' and v_new_status<>'LOST' then null
      else lost_reason
    end,
    updated_at=now()
  where id=v_prospect.id
  returning * into v_prospect;

  select sr.code into v_actor_role
  from public.user_role_assignments ura
  join public.system_roles sr on sr.id=ura.role_id
  where ura.profile_id=v_actor
    and ura.is_active
    and ura.effective_from<=current_date
    and (ura.effective_to is null or ura.effective_to>=current_date)
  order by case when sr.code='ADMIN' then 0 else 1 end, sr.code
  limit 1;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    actor_role_code,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    v_actor_role,
    v_prospect.branch_id,
    'PROSPECT',
    v_prospect.id::text,
    'RECORD_FOLLOW_UP',
    v_notes,
    v_before,
    to_jsonb(v_prospect),
    jsonb_build_object(
      'workflow','PROSPECT_FOLLOW_UP',
      'followup_id',v_followup.id,
      'followup_type',v_followup.followup_type,
      'outcome',v_followup.outcome
    )
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no,
    'followup_id',v_followup.id,
    'status',v_prospect.status,
    'correlation_id',v_correlation_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.publish_business_rule_version(p_domain text, p_rule_key text, p_payload jsonb, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare previous public.business_rule_versions; saved public.business_rule_versions; next_version integer; trace uuid:=gen_random_uuid();
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Settings management permission required.'; end if;
 if (p_domain,p_rule_key) not in (('academics','batch_capacity_policy'),('admissions','activation_policy'),('teacher_compensation','default_policy')) then raise exception 'Choose a supported operating rule.'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 5 and 500 or not public.validate_business_rule_payload(p_domain,p_rule_key,p_payload) then raise exception 'Check the operating values and change reason.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_domain||'.'||p_rule_key,0));
 select * into previous from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key and status='ACTIVE' for update;
 if previous.id is not null and previous.payload=p_payload then return jsonb_build_object('id',previous.id,'version',previous.version); end if;
 select coalesce(max(version),0)+1 into next_version from public.business_rule_versions where domain=p_domain and rule_key=p_rule_key;
 update public.business_rule_versions set status='RETIRED',effective_to=current_date where id=previous.id;
 insert into public.business_rule_versions(domain,rule_key,version,status,effective_from,payload,change_reason,created_by)
 values(p_domain,p_rule_key,next_version,'ACTIVE',current_date,p_payload,btrim(p_reason),auth.uid()) returning * into saved;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(trace,auth.uid(),'BUSINESS_RULE',p_domain||'.'||p_rule_key,case when previous.id is null then 'CREATE_SETTINGS' else 'SAVE_SETTINGS' end,p_reason,to_jsonb(previous),to_jsonb(saved));
 return jsonb_build_object('id',saved.id,'version',saved.version,'correlation_id',trace);
end $function$;

CREATE OR REPLACE FUNCTION public.set_role_permissions(p_role_code text, p_permission_codes text[], p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_role public.system_roles;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.roles.manage') then
    raise exception 'You are not authorized to manage role permissions.';
  end if;

  select * into v_role
  from public.system_roles
  where code=upper(btrim(p_role_code))
    and is_active
  for update;

  if v_role.id is null then
    raise exception 'Role was not found.';
  end if;

  if v_role.code='ADMIN' then
    raise exception 'The bootstrap ADMIN role is protected. Create or edit operational roles instead.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  if exists (
    select unnest(coalesce(p_permission_codes,'{}'::text[]))
    except
    select code from public.permissions
  ) then
    raise exception 'One or more permission codes are invalid.';
  end if;

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_before
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  delete from public.role_permissions where role_id=v_role.id;

  insert into public.role_permissions(role_id,permission_id)
  select v_role.id,p.id
  from public.permissions p
  where p.code=any(coalesce(p_permission_codes,'{}'::text[]));

  select coalesce(jsonb_agg(p.code order by p.code),'[]'::jsonb)
    into v_after
  from public.role_permissions rp
  join public.permissions p on p.id=rp.permission_id
  where rp.role_id=v_role.id;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    'SYSTEM_ROLE',
    v_role.id::text,
    'SET_PERMISSIONS',
    btrim(p_reason),
    jsonb_build_object('permissions',v_before),
    jsonb_build_object('permissions',v_after)
  );

  return jsonb_build_object(
    'role_code',v_role.code,
    'permissions',v_after,
    'correlation_id',v_correlation_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.validate_business_rule_payload(p_domain text, p_rule_key text, p_payload jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare
  v_pool numeric;
  v_pool_max numeric;
  v_acquisition numeric;
  v_retention_3 numeric;
  v_retention_6 numeric;
  v_capacity numeric;
  v_payment_requirement text;
  v_minimum_payment numeric;
begin
  if p_payload is null or jsonb_typeof(p_payload)<>'object' then return false; end if;

  if p_domain='academics' and p_rule_key='batch_capacity_policy' then
    if jsonb_typeof(p_payload->'max_students')<>'number' then return false; end if;
    v_capacity:=(p_payload->>'max_students')::numeric;
    return v_capacity=trunc(v_capacity) and v_capacity between 1 and 500;
  end if;

  if p_domain='teacher_compensation' and p_rule_key='default_policy' then
    if jsonb_typeof(p_payload->'teaching_pool_percent')<>'number'
       or jsonb_typeof(p_payload->'teaching_pool_review_max_percent')<>'number'
       or jsonb_typeof(p_payload->'acquisition_bonus_percent')<>'number'
       or jsonb_typeof(p_payload->'retention_3_month_percent')<>'number'
       or jsonb_typeof(p_payload->'retention_6_month_percent')<>'number' then
      return false;
    end if;
    v_pool:=(p_payload->>'teaching_pool_percent')::numeric;
    v_pool_max:=(p_payload->>'teaching_pool_review_max_percent')::numeric;
    v_acquisition:=(p_payload->>'acquisition_bonus_percent')::numeric;
    v_retention_3:=(p_payload->>'retention_3_month_percent')::numeric;
    v_retention_6:=(p_payload->>'retention_6_month_percent')::numeric;
    if coalesce(p_payload->>'teaching_allocation_method','APPROVED_SESSION_WEIGHT')
       not in('APPROVED_SESSION_WEIGHT') then
      return false;
    end if;
    return v_pool between 0 and 100
      and v_pool_max between 0 and 100
      and v_pool<=v_pool_max
      and v_acquisition between 0 and 100
      and v_retention_3 between 0 and 100
      and v_retention_6 between 0 and 100;
  end if;

  if p_domain='admissions' and p_rule_key='activation_policy' then
    if jsonb_typeof(p_payload->'requires_admission_acceptance')<>'boolean'
       or jsonb_typeof(p_payload->'requires_initial_billing_posted')<>'boolean'
       or jsonb_typeof(p_payload->'allow_credit_enrollment')<>'boolean'
       or jsonb_typeof(p_payload->'count_student_active_only_when_enrollment_active')<>'boolean'
       or jsonb_typeof(p_payload->'minimum_payment_percent')<>'number'
       or jsonb_typeof(p_payload->'payment_requirement')<>'string' then return false; end if;
    v_payment_requirement:=p_payload->>'payment_requirement';
    v_minimum_payment:=(p_payload->>'minimum_payment_percent')::numeric;
    if v_payment_requirement not in('NONE','MINIMUM_PERCENT','FULL') then return false; end if;
    if v_minimum_payment<0 or v_minimum_payment>100 then return false; end if;
    if v_payment_requirement='NONE' and v_minimum_payment<>0 then return false; end if;
    if v_payment_requirement='MINIMUM_PERCENT' and (v_minimum_payment<=0 or v_minimum_payment>=100) then return false; end if;
    if v_payment_requirement='FULL' and v_minimum_payment<>100 then return false; end if;
    return true;
  end if;

  return false;
exception when others then
  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_user_operational_roles(p_profile_id uuid, p_role_codes text[], p_reason text, p_branch_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_profile public.profiles;
  v_branch public.branches;
  v_before jsonb;
  v_after jsonb;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null or not public.has_permission('system.users.manage') then
    raise exception 'You are not authorized to manage user access.';
  end if;

  if nullif(btrim(coalesce(p_reason,'')), '') is null then
    raise exception 'A change reason is required.';
  end if;

  select * into v_profile
  from public.profiles
  where id=p_profile_id
    and status='ACTIVE'
  for update;

  if v_profile.id is null then
    raise exception 'Active user profile was not found.';
  end if;

  if p_branch_id is not null then
    select * into v_branch
    from public.branches
    where id=p_branch_id and is_active;

    if v_branch.id is null then
      raise exception 'Selected branch is not available.';
    end if;
  end if;

  if 'ADMIN'=any(coalesce(p_role_codes,'{}'::text[])) then
    raise exception 'ADMIN assignment is protected and cannot be changed through the operational access editor.';
  end if;

  if exists (
    select unnest(coalesce(p_role_codes,'{}'::text[]))
    except
    select code
    from public.system_roles
    where code<>'ADMIN' and is_active
  ) then
    raise exception 'One or more operational role codes are invalid.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_before
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  update public.user_role_assignments ura
  set
    is_active=false,
    effective_to=current_date
  from public.system_roles r
  where ura.role_id=r.id
    and ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id
    and not (r.code=any(coalesce(p_role_codes,'{}'::text[])));

  insert into public.user_role_assignments(
    profile_id,
    role_id,
    branch_id,
    effective_from,
    is_active,
    assigned_by
  )
  select
    p_profile_id,
    r.id,
    p_branch_id,
    current_date,
    true,
    v_actor
  from public.system_roles r
  where r.code=any(coalesce(p_role_codes,'{}'::text[]))
    and r.code<>'ADMIN'
    and r.is_active
    and not exists (
      select 1
      from public.user_role_assignments existing
      where existing.profile_id=p_profile_id
        and existing.role_id=r.id
        and existing.branch_id is not distinct from p_branch_id
        and existing.is_active
        and existing.effective_to is null
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role_code',r.code,
        'branch_id',ura.branch_id,
        'effective_from',ura.effective_from
      )
      order by r.code
    ),
    '[]'::jsonb
  )
  into v_after
  from public.user_role_assignments ura
  join public.system_roles r on r.id=ura.role_id
  where ura.profile_id=p_profile_id
    and r.code<>'ADMIN'
    and ura.is_active
    and ura.effective_to is null
    and ura.branch_id is not distinct from p_branch_id;

  if v_before=v_after then
    raise exception 'The proposed access assignment is identical to the current assignment.';
  end if;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    p_branch_id,
    'USER_ACCESS',
    p_profile_id::text,
    'SET_OPERATIONAL_ROLES',
    btrim(p_reason),
    jsonb_build_object('roles',v_before),
    jsonb_build_object('roles',v_after),
    jsonb_build_object('scope_branch_id',p_branch_id)
  );

  return jsonb_build_object(
    'profile_id',p_profile_id,
    'branch_id',p_branch_id,
    'roles',v_after,
    'correlation_id',v_correlation_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.guard_fee_plan_history()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name='fee_plan_components' then
    if tg_op='DELETE' then return old; end if;
    return new;
  end if;
  if tg_op='DELETE' then raise exception 'Fee Plans cannot be deleted.'; end if;
  if old.id is distinct from new.id or old.offering_id is distinct from new.offering_id
     or old.version is distinct from new.version or old.created_by is distinct from new.created_by then
    raise exception 'Fee Plan identity fields cannot be changed.';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.manage_crm_master_record(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      values (v_org, v_name, v_starts, v_ends, v_is_active)
      returning to_jsonb(academic_years.*) into v_after;
      v_id := (v_after->>'id')::uuid;
      v_action := 'CREATE';
    else
      select to_jsonb(y.*) into v_before from public.academic_years y where y.id = v_id and y.organization_id = v_org for update;
      if v_before is null then raise exception 'Academic year not found.'; end if;
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
$function$;

CREATE OR REPLACE FUNCTION public.update_programme_offering_public_controls(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_correlation uuid := gen_random_uuid();
  v_offering_id uuid;
  v_reason text;
  v_row public.programme_offerings%rowtype;
  v_before jsonb;
  v_title text;
  v_title_bn text;
  v_desc text;
  v_desc_bn text;
  v_eyebrow text;
  v_eyebrow_bn text;
  v_icon text;
  v_sort integer;
  v_visible boolean;
  v_accepting boolean;
  v_open date;
  v_close date;
  v_subjects jsonb;
  v_subject_id uuid;
  v_idx integer := 0;
begin
  if v_actor is null then
    raise exception 'Authentication required.';
  end if;
  if not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to curate programme public controls.';
  end if;

  v_offering_id := nullif(p_input->>'offering_id', '')::uuid;
  v_reason := nullif(trim(coalesce(p_input->>'reason', '')), '');
  v_title := nullif(trim(coalesce(p_input->>'showcase_title', '')), '');
  v_title_bn := nullif(trim(coalesce(p_input->>'showcase_title_bn', '')), '');
  v_desc := nullif(trim(coalesce(p_input->>'showcase_description', '')), '');
  v_desc_bn := nullif(trim(coalesce(p_input->>'showcase_description_bn', '')), '');
  v_eyebrow := nullif(trim(coalesce(p_input->>'showcase_eyebrow', '')), '');
  v_eyebrow_bn := nullif(trim(coalesce(p_input->>'showcase_eyebrow_bn', '')), '');
  v_icon := nullif(trim(coalesce(p_input->>'showcase_icon', '')), '');
  v_sort := coalesce((p_input->>'showcase_sort_order')::integer, 100);
  v_visible := coalesce((p_input->>'is_website_visible')::boolean, false);
  v_accepting := coalesce((p_input->>'is_accepting_applications')::boolean, false);
  v_open := nullif(p_input->>'applications_open_on', '')::date;
  v_close := nullif(p_input->>'applications_close_on', '')::date;
  v_subjects := coalesce(p_input->'subject_ids', '[]'::jsonb);

  if v_offering_id is null then
    raise exception 'Offering is required.';
  end if;
  if v_reason is null or length(v_reason) < 5 then
    raise exception 'A short reason (at least 5 characters) is required for the audit trail.';
  end if;
  if v_sort < 0 or v_sort > 9999 then
    raise exception 'Sort order must be between 0 and 9999.';
  end if;
  if v_icon is not null and v_icon not in (
    'clipboard-check', 'graduation-cap', 'users-round',
    'book-open-check', 'line-chart', 'shield-check'
  ) then
    raise exception 'Unsupported showcase icon.';
  end if;
  if v_open is not null and v_close is not null and v_close < v_open then
    raise exception 'Applications close date must be on or after the open date.';
  end if;

  select * into v_row from public.programme_offerings where id = v_offering_id for update;
  if not found then
    raise exception 'Programme offering not found.';
  end if;

  if v_visible and v_row.status <> 'ACTIVE' then
    raise exception 'Only ACTIVE offerings (with a published Fee Plan) can be shown on the website.';
  end if;
  if v_visible and v_title is null then
    raise exception 'Showcase title (English) is required when website visibility is enabled.';
  end if;
  if v_visible and v_desc is null then
    raise exception 'Showcase description (English) is required when website visibility is enabled.';
  end if;
  if v_accepting and v_row.status = 'RETIRED' then
    raise exception 'Retired offerings cannot accept new applications.';
  end if;

  v_before := to_jsonb(v_row);

  update public.programme_offerings set
    showcase_title = v_title,
    showcase_title_bn = v_title_bn,
    showcase_description = v_desc,
    showcase_description_bn = v_desc_bn,
    showcase_eyebrow = v_eyebrow,
    showcase_eyebrow_bn = v_eyebrow_bn,
    showcase_icon = v_icon,
    showcase_sort_order = v_sort,
    is_website_visible = v_visible,
    is_accepting_applications = v_accepting,
    applications_open_on = v_open,
    applications_close_on = v_close,
    public_schedule = case when p_input ? 'public_schedule' then nullif(btrim(p_input->>'public_schedule'), '') else public_schedule end,
    public_requirements = case when p_input ? 'public_requirements' then nullif(btrim(p_input->>'public_requirements'), '') else public_requirements end,
    admission_policy = case when p_input ? 'admission_policy' then nullif(btrim(p_input->>'admission_policy'), '') else admission_policy end,
    public_schedule_bn = case when p_input ? 'public_schedule_bn' then nullif(btrim(p_input->>'public_schedule_bn'), '') else public_schedule_bn end,
    public_requirements_bn = case when p_input ? 'public_requirements_bn' then nullif(btrim(p_input->>'public_requirements_bn'), '') else public_requirements_bn end,
    admission_policy_bn = case when p_input ? 'admission_policy_bn' then nullif(btrim(p_input->>'admission_policy_bn'), '') else admission_policy_bn end,
    updated_at = now()
  where id = v_offering_id
  returning * into v_row;

  delete from public.programme_offering_subjects where offering_id = v_offering_id;
  if jsonb_typeof(v_subjects) = 'array' then
    for v_idx in 0 .. greatest(jsonb_array_length(v_subjects) - 1, -1) loop
      v_subject_id := nullif(v_subjects->>v_idx, '')::uuid;
      if v_subject_id is null then
        continue;
      end if;
      if not exists (
        select 1 from public.subjects s
        where s.id = v_subject_id and s.is_active
      ) then
        raise exception 'One selected subject is not available.';
      end if;
      insert into public.programme_offering_subjects (offering_id, subject_id, sort_order)
      values (v_offering_id, v_subject_id, v_idx);
    end loop;
  end if;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation,
    v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_row.branch_id,
    'PROGRAMME_OFFERING',
    v_row.id::text,
    'UPDATE_PUBLIC_CONTROLS',
    v_reason,
    v_before,
    to_jsonb(v_row),
    jsonb_build_object(
      'is_website_visible', v_visible,
      'is_accepting_applications', v_accepting,
      'showcase_sort_order', v_sort,
      'subject_count', coalesce(jsonb_array_length(v_subjects), 0)
    )
  );

  return jsonb_build_object(
    'offering_id', v_row.id,
    'is_website_visible', v_row.is_website_visible,
    'is_accepting_applications', v_row.is_accepting_applications,
    'correlation_id', v_correlation
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_public_programme_offerings()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id, ay.name as academic_year_name,
      b.name as branch_name, c.name as class_name, ag.name as group_name,
      o.showcase_title, o.showcase_title_bn, o.showcase_description,
      o.showcase_description_bn, o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      o.public_schedule, o.public_schedule_bn, o.public_requirements,
      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (select count(*)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as active_batch_count,
      (select coalesce(sum(bb.capacity),0)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_total_seats,
      (select coalesce(sum(greatest(bb.capacity-(select count(*) from public.enrollments e where e.batch_id=bb.id and e.status='ACTIVE'),0)),0)::integer
       from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_open_seats,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN' end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name)
        order by pos.sort_order), '[]'::jsonb)
       from public.programme_offering_subjects pos
       join public.subjects s on s.id = pos.subject_id
       where pos.offering_id = o.id and s.is_active) as subjects,
      (select jsonb_build_object('billing_cycle', fp.billing_cycle,
        'currency_code', fp.currency_code,
        'components', coalesce((select jsonb_agg(jsonb_build_object(
          'code', fc.code, 'name', fc.name, 'amount', fc.amount,
          'charge_type', fc.charge_type, 'recurrence', fc.recurrence)
          order by fc.sort_order) from public.fee_plan_components fc
          where fc.fee_plan_version_id = fp.id), '[]'::jsonb))
       from public.fee_plan_versions fp
       where fp.offering_id = o.id and fp.status = 'ACTIVE' limit 1) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at limit 24
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.link_staff_profile_by_email(p_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_email text := lower(nullif(btrim(coalesce(p_email, '')), ''));
  v_user_id uuid;
  v_staff_ids uuid[];
begin
  if v_email is null then
    return null;
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_email
    and u.email_confirmed_at is not null
  order by u.created_at asc
  limit 1;

  if v_user_id is null
     or not exists (select 1 from public.profiles where id = v_user_id)
     or exists (select 1 from public.staff where profile_id = v_user_id) then
    return null;
  end if;

  select array_agg(s.id) into v_staff_ids
  from public.staff s
  where s.profile_id is null
    and lower(s.email) = v_email
    and s.status in ('ACTIVE', 'ON_LEAVE');

  if coalesce(array_length(v_staff_ids, 1), 0) <> 1 then
    return null;
  end if;

  update public.staff
  set profile_id = v_user_id
  where id = v_staff_ids[1]
    and profile_id is null;

  insert into public.audit_events(entity_type, entity_id, action, reason, metadata)
  values (
    'STAFF',
    v_staff_ids[1]::text,
    'LINK_PROFILE',
    'Linked to Auth profile by confirmed email match.',
    jsonb_build_object('profile_id', v_user_id, 'email', v_email)
  );

  return v_staff_ids[1];
end;
$function$;

CREATE OR REPLACE FUNCTION public.staff_link_profile_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.link_staff_profile_by_email(new.email);
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.auth_user_link_staff_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.email_confirmed_at is not null then
    perform public.link_staff_profile_by_email(new.email);
  end if;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_review_queue()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with queue as (
    select
      a.id,
      'ATTENDANCE'::text as review_type,
      a.id::text as entity_id,
      ('Attendance · ' || b.name || ' · ' || s.name) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(ar.requested_at, a.created_at) as submitted_at,
      a.revision,
      '/dashboard/academics/sessions/' || cs.id::text as href
    from public.attendance_submissions a
    left join public.approval_requests ar
      on ar.id = a.approval_id
    join public.class_sessions cs on cs.id = a.session_id
    join public.batches b on b.id = cs.batch_id
    join public.subjects s on s.id = cs.subject_id
    join public.profiles p on p.id = a.recorded_by
    left join public.staff st on st.profile_id = a.recorded_by
    where a.status = 'SUBMITTED'
      and public.has_permission('academics.attendance.approve')

    union all

    select
      l.id,
      'CLASS_LOG'::text as review_type,
      l.id::text as entity_id,
      ('Class log · ' || b.name || ' · ' || s.name) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      l.submitted_at as submitted_at,
      l.revision,
      '/dashboard/academics/sessions/' || cs.id::text as href
    from public.class_logs l
    join public.class_sessions cs on cs.id = l.session_id
    join public.batches b on b.id = cs.batch_id
    join public.subjects s on s.id = cs.subject_id
    join public.profiles p on p.id = l.authored_by
    left join public.staff st on st.profile_id = l.authored_by
    where l.status = 'SUBMITTED'
      and public.has_permission('academics.attendance.approve')

    union all

    select
      r.id,
      'ASSESSMENT_RESULTS'::text as review_type,
      r.id::text as entity_id,
      ('Assessment results · ' || a.title) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(r.submitted_at, r.created_at) as submitted_at,
      r.revision,
      '/dashboard/academics/assessments?assessment=' || a.id::text as href
    from public.assessment_result_submissions r
    join public.academic_assessments a on a.id = r.assessment_id
    join public.batches b on b.id = a.batch_id
    join public.subjects s on s.id = a.subject_id
    join public.profiles p on p.id = r.author_id
    left join public.staff st on st.profile_id = r.author_id
    where r.status = 'SUBMITTED'
      and public.has_permission('academics.assessments.approve')

    union all

    select
      q.id,
      'QUESTION'::text as review_type,
      q.id::text as entity_id,
      ('Question · ' || q.topic) as title,
      coalesce(st.full_name, p.display_name) as teacher_name,
      st.staff_no as teacher_staff_no,
      b.name as batch_name,
      s.name as subject_name,
      coalesce(q.submitted_at, q.created_at) as submitted_at,
      q.revision,
      '/dashboard/academics/questions?item=' || q.id::text as href
    from public.question_bank_items q
    join public.batches b on b.id = q.batch_id
    join public.subjects s on s.id = q.subject_id
    join public.profiles p on p.id = q.author_id
    left join public.staff st on st.profile_id = q.author_id
    where q.status = 'SUBMITTED'
      and public.has_permission('academics.assessments.approve')
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'reviewType', review_type,
        'entityId', entity_id,
        'title', title,
        'teacherName', teacher_name,
        'teacherStaffNo', teacher_staff_no,
        'batchName', batch_name,
        'subjectName', subject_name,
        'submittedAt', submitted_at,
        'revision', revision,
        'href', href
      )
      order by submitted_at asc, review_type, entity_id
    ),
    '[]'::jsonb
  )
  from queue;
$function$;

CREATE OR REPLACE FUNCTION public.save_fee_plan(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_offering public.programme_offerings;
  v_previous public.fee_plan_versions;
  v_current public.fee_plan_versions;
  v_components jsonb := p_input->'components';
  v_component jsonb;
  v_today date;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_cycle text := p_input->>'billing_cycle';
  v_due_day integer;
  v_correlation uuid := gen_random_uuid();
  v_prior_components jsonb;
  v_next_version integer;
begin
  if v_actor is null or not public.has_permission('finance.billing.manage') then
    raise exception 'You are not authorized to edit Fee Plans.';
  end if;
  if length(v_reason) < 5 then
    raise exception 'Explain the fee change in at least five characters.';
  end if;
  if v_cycle not in ('MONTHLY','TERM','ONE_TIME') then
    raise exception 'Choose a valid billing cycle.';
  end if;
  v_due_day := nullif(p_input->>'due_day','')::integer;
  if (v_cycle = 'MONTHLY' and (v_due_day is null or v_due_day not between 1 and 28))
     or (v_cycle <> 'MONTHLY' and v_due_day is not null) then
    raise exception 'Monthly plans require a due day from 1 to 28; other plans have no monthly due day.';
  end if;
  if jsonb_typeof(v_components) is distinct from 'array' then
    raise exception 'Fee components must be a list.';
  end if;
  if jsonb_array_length(v_components) not between 1 and 30 then
    raise exception 'Enter between one and thirty fee components.';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v_components) c
    where c->>'charge_type' = 'TUITION'
      and c->>'recurrence' = 'PER_CYCLE'
      and (c->>'amount')::numeric > 0
  ) then
    raise exception 'Enter a positive recurring Tuition charge.';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_components) c
    where (c->>'amount')::numeric < 0
      or (c->>'charge_type' = 'TUITION' and (c->>'amount')::numeric <= 0)
  ) then
    raise exception 'Fee amounts cannot be negative; Tuition must be positive.';
  end if;

  -- Lock the offering to serialize simultaneous saves and version assignment.
  select * into v_offering
  from public.programme_offerings
  where id = (p_input->>'offering_id')::uuid and status <> 'RETIRED'
  for update;
  if v_offering.id is null then raise exception 'Offering is not available.'; end if;

  select (now() at time zone timezone)::date into v_today
  from public.organizations where id = v_offering.organization_id;
  if (p_input->>'effective_from')::date is distinct from v_today then
    raise exception 'Changes to current charges take effect today in the academy timezone.';
  end if;

  select * into v_previous
  from public.fee_plan_versions
  where offering_id = v_offering.id and status = 'ACTIVE'
  for update;
  select coalesce(max(version), 0) + 1 into v_next_version
  from public.fee_plan_versions where offering_id = v_offering.id;

  if v_previous.id is not null then
    select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order), '[]'::jsonb)
      into v_prior_components
    from public.fee_plan_components c
    where c.fee_plan_version_id = v_previous.id;

    update public.fee_plan_versions
    set status = 'RETIRED',
        effective_to = greatest(v_previous.effective_from, v_today)
    where id = v_previous.id;
  end if;

  insert into public.fee_plan_versions (
    offering_id, version, status, billing_cycle, due_day, currency_code,
    effective_from, effective_to, change_reason, created_by
  ) values (
    v_offering.id, v_next_version, 'DRAFT', v_cycle, v_due_day,
    (select currency_code from public.organizations where id = v_offering.organization_id),
    v_today, null, v_reason, v_actor
  ) returning * into v_current;

  for v_component in select value from jsonb_array_elements(v_components)
  loop
    insert into public.fee_plan_components (
      fee_plan_version_id, code, name, amount, charge_type, recurrence, sort_order
    ) values (
      v_current.id, upper(btrim(v_component->>'code')),
      btrim(v_component->>'name'), (v_component->>'amount')::numeric,
      v_component->>'charge_type', v_component->>'recurrence',
      coalesce((v_component->>'sort_order')::integer, 0)
    );
  end loop;

  -- Finalize only after all components have been inserted. Published-plan guards
  -- must never be bypassed or weakened to permit later component mutation.
  update public.fee_plan_versions set status = 'ACTIVE'
  where id = v_current.id
  returning * into v_current;

  update public.programme_offerings set status = 'ACTIVE'
  where id = v_offering.id;

  insert into public.audit_events (
    correlation_id, actor_profile_id, actor_staff_id, branch_id,
    entity_type, entity_id, action, reason, before_data, after_data, metadata
  ) values (
    v_correlation, v_actor,
    (select id from public.staff where profile_id = v_actor limit 1),
    v_offering.branch_id, 'FEE_PLAN', v_current.id::text,
    case when v_previous.id is null then 'CREATE' else 'SAVE' end,
    v_reason,
    case when v_previous.id is null then null else jsonb_build_object(
      'plan', to_jsonb(v_previous), 'components', v_prior_components
    ) end,
    jsonb_build_object(
      'plan', to_jsonb(v_current), 'components', v_components
    ),
    jsonb_build_object('offering_id', v_offering.id, 'current_state', true)
  );

  return jsonb_build_object('fee_plan_id', v_current.id, 'correlation_id', v_correlation);
end;
$function$;

CREATE OR REPLACE FUNCTION public.save_offering_discount_policy(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.programme_offerings; choices integer[]; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
 select array_agg(distinct value::integer order by value::integer) into choices
 from jsonb_array_elements_text(coalesce(p_input->'percentages','[]'::jsonb));
 choices:=coalesce(choices,'{}');
 if not choices <@ array[5,10,15,20,25,30] then raise exception 'Choose discounts from 5 to 30 in steps of five.'; end if;
 select * into o from public.programme_offerings where id=(p_input->>'offering_id')::uuid for update;
 if o.id is null then raise exception 'Offering not found.'; end if;
 before_data:=to_jsonb(o);
 update public.programme_offerings set allowed_discount_percentages=choices where id=o.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'OFFERING',o.id::text,'SAVE_DISCOUNT_POLICY','Updated permitted admission discounts',before_data,
 jsonb_build_object('allowed_discount_percentages',choices));
 return jsonb_build_object('id',o.id);
end $function$;

CREATE OR REPLACE FUNCTION public.academy_setup_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.organizations; steps jsonb; ready boolean;
begin
 if auth.uid() is null or not public.has_permission('dashboard.view') then raise exception 'ERP access required.'; end if;
 select * into o from public.organizations where code='SOHOJ' and is_active limit 1;
 steps:=jsonb_build_array(
 jsonb_build_object('id','academy','title','Academy and campus','href','/dashboard/setup','done',o.id is not null and o.setup_identity_confirmed_at is not null and exists(select 1 from public.branches where organization_id=o.id and is_active)),
 jsonb_build_object('id','directory','title','Academic years, classes, subjects and programmes','href','/dashboard/crm/manage','done',
 exists(select 1 from public.academic_years where organization_id=o.id and is_active) and
 exists(select 1 from public.classes where organization_id=o.id and is_active) and
 exists(select 1 from public.subjects where organization_id=o.id and is_active) and
 exists(select 1 from public.programs where organization_id=o.id and is_active)),
 jsonb_build_object('id','rules','title','Capacity and enrollment rules','href','/dashboard/governance/rules','done',
 exists(select 1 from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE') and
 exists(select 1 from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE')),
 jsonb_build_object('id','offering','title','Programme offering','href','/dashboard/academics/offerings','done',exists(select 1 from public.programme_offerings where organization_id=o.id and status<>'RETIRED')),
 jsonb_build_object('id','fees','title','Standard fees and permitted discounts','href','/dashboard/finance/fee-plans','done',exists(select 1 from public.programme_offerings off join public.fee_plan_versions f on f.offering_id=off.id where off.organization_id=o.id and off.status='ACTIVE' and f.status='ACTIVE' and f.effective_from<=timezone(o.timezone,now())::date)),
 jsonb_build_object('id','batches','title','At least one admission-ready batch','href','/dashboard/academics/batches','done',exists(select 1 from public.batches b join public.programme_offerings off on off.id=b.offering_id join public.fee_plan_versions f on f.offering_id=off.id where off.organization_id=o.id and off.status='ACTIVE' and b.is_active and f.status='ACTIVE' and f.effective_from<=timezone(o.timezone,now())::date)));
 select bool_and((value->>'done')::boolean) into ready from jsonb_array_elements(steps);
 return jsonb_build_object('completed',o.setup_completed_at is not null,'ready',coalesce(ready,false),'steps',steps,'academyName',o.name);
end $function$;

CREATE OR REPLACE FUNCTION public.complete_academy_setup()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Academy setup permission required.'; end if;
 perform pg_advisory_xact_lock(871604);
 if not (public.academy_setup_status()->>'ready')::boolean then raise exception 'Finish all prerequisite settings before opening operations.'; end if;
 update public.organizations set setup_completed_at=now(),setup_completed_by=auth.uid() where code='SOHOJ' and is_active;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason) values(auth.uid(),'ACADEMY',(select id::text from public.organizations where code='SOHOJ'),'COMPLETE_SETUP','Reviewed academy configuration before opening operations');
 return public.academy_setup_status();
end $function$;

CREATE OR REPLACE FUNCTION public.record_lifecycle_command(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare target_table text; permission text; status_column text; active_value text; inactive_value text;
 before_data jsonb; after_data jsonb; target uuid:=(p_input->>'id')::uuid; enabled boolean:=(p_input->>'active')::boolean;
begin
 case p_input->>'entity'
 when 'batch' then target_table:='batches';permission:='academics.manage';status_column:='is_active';
 when 'offering' then target_table:='programme_offerings';permission:='academics.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='RETIRED';
 when 'student' then target_table:='students';permission:='students.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='INACTIVE';
 when 'staff' then target_table:='staff';permission:='staff.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='ARCHIVED';
 when 'referrer' then target_table:='referral_people';permission:='admissions.create';status_column:='is_active';
 else raise exception 'This record requires its dedicated correction workflow.';
 end case;
 if auth.uid() is null or not public.has_permission(permission) then raise exception 'Record management permission required.'; end if;
 if enabled is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Select a state and provide a reason.'; end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 for update',target_table) into before_data using target;
 if before_data is null then raise exception 'Record not found.'; end if;
 if target_table='staff' and before_data->>'profile_id'=auth.uid()::text and not enabled then raise exception 'You cannot deactivate your own staff record.'; end if;
 if target_table='programme_offerings' and enabled and not exists(select 1 from public.fee_plan_versions where offering_id=target and status='ACTIVE') then raise exception 'Save an effective Fee Plan before activating the offering.'; end if;
 if target_table='students' and enabled and not exists(select 1 from public.enrollments where student_id=target and status='ACTIVE') then raise exception 'Activate an enrollment before activating this student.'; end if;
 if target_table='students' and not enabled and exists(select 1 from public.enrollments where student_id=target and status='ACTIVE') then raise exception 'Withdraw or close the active enrollment first; its history and balances remain intact.'; end if;
 if status_column='is_active' then
 execute format('update public.%I set is_active=$2 where id=$1 returning to_jsonb(%I.*)',target_table,target_table) into after_data using target,enabled;
 else
 execute format('update public.%I set status=%L where id=$1 returning to_jsonb(%I.*)',target_table,case when enabled then active_value else inactive_value end,target_table) into after_data using target;
 end if;
 if target_table='staff' then update public.profiles set status=case when enabled then 'ACTIVE'::public.profile_status else 'SUSPENDED'::public.profile_status end where id=(before_data->>'profile_id')::uuid; end if;
 if target_table='programme_offerings' and not enabled then update public.programme_offerings set is_website_visible=false,is_accepting_applications=false where id=target; end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),upper(p_input->>'entity'),target::text,case when enabled then 'REACTIVATE' else 'MARK_INACTIVE' end,p_input->>'reason',before_data,after_data);
 return jsonb_build_object('id',target);
end $function$;

CREATE OR REPLACE FUNCTION public.request_staff_access(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare email_value text:=lower(btrim(coalesce(p_input->>'email',''))); count_recent integer;
begin
 if octet_length(p_input::text)>3000 or length(btrim(coalesce(p_input->>'full_name',''))) not between 2 and 160
 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(email_value)>254
 or coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$'
 or p_input->>'requested_role' not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT')
 or length(btrim(coalesce(p_input->>'purpose',''))) not between 5 and 500 then raise exception 'Enter valid contact details, role and purpose.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(email_value,5));
 if (select count(*) from public.staff_access_requests where email=email_value and created_at>now()-interval '1 hour')>=3 then
  return jsonb_build_object('received',true);
 end if;
 insert into public.staff_access_requests(full_name,email,mobile,requested_role,purpose)
 values(btrim(p_input->>'full_name'),email_value,p_input->>'mobile',p_input->>'requested_role',btrim(p_input->>'purpose'))
 on conflict do nothing;
 -- Identical response prevents disclosure of existing staff addresses.
 return jsonb_build_object('received',true);
end $function$;

CREATE OR REPLACE FUNCTION public.review_staff_access(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.staff_access_requests; role_value text:=p_input->>'assigned_role'; user_id uuid;
begin
 if auth.uid() is null or not public.has_permission('system.users.manage') then raise exception 'User management permission required.'; end if;
 if not exists(select 1 from public.user_role_assignments a join public.system_roles ro on ro.id=a.role_id
 where a.profile_id=auth.uid() and a.is_active and ro.code='ADMIN' and ro.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date)) then raise exception 'Super admin verification required.'; end if;
 select * into r from public.staff_access_requests where id=(p_input->>'id')::uuid for update;
 if r.id is null then raise exception 'Request not found.'; end if;
 if p_input->>'action'='DECLINE' then
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be declined.'; end if;
  update public.staff_access_requests set status='DECLINED',reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='VERIFY' then
  if role_value not in('ADMIN','OPERATOR','TEACHER','ACCOUNTANT') then raise exception 'Choose a role.'; end if;
  if r.status not in('PENDING','VERIFIED') then raise exception 'Only pending requests can be verified.'; end if;
  update public.staff_access_requests set status='VERIFIED',assigned_role=role_value,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_input->>'reason' where id=r.id;
 elsif p_input->>'action'='COMPLETE_INVITATION' then
  if r.status not in('VERIFIED','INVITED') then raise exception 'Verify the request before inviting.'; end if;
  -- Identity is resolved from the verified request email, never an arbitrary caller ID.
  select id into user_id from auth.users where lower(email)=r.email;
  if user_id is null then raise exception 'Supabase invitation has not created the user yet.'; end if;
  insert into public.profiles(id,display_name) values(user_id,r.full_name) on conflict(id) do nothing;
  insert into public.staff(profile_id,full_name,email,mobile,created_by)
   values(user_id,r.full_name,r.email,r.mobile,auth.uid()) on conflict(profile_id) do nothing;
  if not exists(select 1 from public.system_roles where code=r.assigned_role and is_active) then raise exception 'Assigned role is unavailable.'; end if;
  insert into public.user_role_assignments(profile_id,role_id,assigned_by)
   select user_id,id,auth.uid() from public.system_roles where code=r.assigned_role and is_active
   on conflict do nothing;
  insert into public.staff_role_assignments(staff_id,staff_role_id,is_primary,assigned_by)
   select s.id,role.id,true,auth.uid() from public.staff s join public.staff_roles role on role.code=r.assigned_role and role.is_active
   where s.profile_id=user_id and not exists(select 1 from public.staff_role_assignments old where old.staff_id=s.id and old.is_primary and old.effective_to is null);
  update public.staff_access_requests set status='INVITED',profile_id=user_id,invitation_sent_at=now() where id=r.id;
 else raise exception 'Unsupported staff verification action.';
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason)
 values(auth.uid(),'STAFF_ACCESS_REQUEST',r.id::text,p_input->>'action',coalesce(p_input->>'reason','Verified staff invitation'));
 return jsonb_build_object('id',r.id);
end $function$;

CREATE OR REPLACE FUNCTION public.edit_staff_record(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.staff; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('staff.manage') then raise exception 'Staff management permission required.'; end if;
 if length(btrim(coalesce(p_input->>'full_name',''))) not between 2 and 160 or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Staff name and correction reason required.'; end if;
 select * into s from public.staff where id=(p_input->>'id')::uuid for update;
 if s.id is null then raise exception 'Staff not found.'; end if;
 before_data:=to_jsonb(s);
 update public.staff set full_name=btrim(p_input->>'full_name'),mobile=nullif(btrim(p_input->>'mobile'),''),
  address=case when p_input ? 'address' then nullif(btrim(p_input->>'address'),'') else address end,notes=case when p_input ? 'notes' then nullif(btrim(p_input->>'notes'),'') else notes end where id=s.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'STAFF',s.id::text,'CORRECT_DETAILS',p_input->>'reason',before_data,p_input);
 return jsonb_build_object('id',s.id);
end $function$;

CREATE OR REPLACE FUNCTION public.prevent_permanent_record_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin raise exception 'Do not delete this record. Use edit, inactive, withdrawal or a recorded financial correction.'; end $function$;

CREATE OR REPLACE FUNCTION public.save_academy_identity(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare org public.organizations; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Academy setup permission required.'; end if;
 if length(btrim(coalesce(p_input->>'name',''))) not between 2 and 160 then raise exception 'Enter an academy name.'; end if;
 if length(btrim(coalesce(p_input->>'branch_name',''))) not between 2 and 160 then raise exception 'Enter the campus name.'; end if;
 select * into org from public.organizations where code='SOHOJ' for update;
 before_data:=to_jsonb(org);
 update public.organizations set name=btrim(p_input->>'name'),setup_identity_confirmed_at=now() where id=org.id;
 update public.branches set name=btrim(p_input->>'branch_name') where organization_id=org.id and code='MAIN';
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ACADEMY',org.id::text,'CONFIRM_IDENTITY','Confirmed academy name and campus',before_data,p_input);
 return jsonb_build_object('id',org.id);
end $function$;

CREATE OR REPLACE FUNCTION public.create_admission_directory_choice(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare org uuid; result jsonb; name_value text:=btrim(coalesce(p_input->>'name',''));
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if length(name_value) not between 2 and 160 then raise exception 'Enter a name of 2 to 160 characters.'; end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(lower(name_value),6));
 if p_input->>'entity'='school' then
  select jsonb_build_object('id',id,'name',name) into result from public.schools where organization_id=org and lower(name)=lower(name_value) and is_active limit 1;
  if result is null then insert into public.schools(organization_id,name,is_verified,is_active) values(org,name_value,true,true) returning jsonb_build_object('id',id,'name',name) into result; end if;
 elsif p_input->>'entity'='relationship' then
  select jsonb_build_object('id',id,'name',name) into result from public.guardian_relationships where organization_id=org and lower(name)=lower(name_value) and is_active limit 1;
  if result is null then insert into public.guardian_relationships(organization_id,code,name,is_active) values(org,'REL_'||replace(gen_random_uuid()::text,'-',''),name_value,true) returning jsonb_build_object('id',id,'name',name) into result; end if;
 else raise exception 'Only school and guardian relationship can be created during admission.';
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,after_data)
 values(auth.uid(),upper(p_input->>'entity'),result->>'id','SELECT_OR_CREATE_FOR_ADMISSION','Verified missing directory option during admission',result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.capture_audit_actor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare person public.staff; name text; roles text; trace text;
begin
 if new.actor_profile_id is null and exists(select 1 from public.profiles where id=auth.uid()) then new.actor_profile_id:=auth.uid(); end if;
 if new.actor_profile_id is not null then
  select * into person from public.staff where profile_id=new.actor_profile_id;
  new.actor_staff_id:=coalesce(new.actor_staff_id,person.id);
  select display_name into name from public.profiles where id=new.actor_profile_id;
  select string_agg(distinct r.code,', ' order by r.code) into roles from public.user_role_assignments a join public.system_roles r on r.id=a.role_id
   where a.profile_id=new.actor_profile_id and a.is_active and r.is_active and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date);
  new.actor_role_code:=coalesce(new.actor_role_code,roles,'AUTHENTICATED');
  new.metadata:=new.metadata||jsonb_build_object('actor_name',coalesce(person.full_name,name),'actor_staff_no',person.staff_no,'actor_roles',new.actor_role_code);
 end if;
 trace:=nullif(current_setting('sohoj.workflow_trace',true),'');
 if trace is not null then new.correlation_id:=trace::uuid; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.audit_event_list(p_correlation uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.has_permission('audit.view') then raise exception 'Audit permission required.'; end if;
 return coalesce((select jsonb_agg(row_data order by occurred_at desc,id desc) from (
 select e.id,e.occurred_at,to_jsonb(e)||jsonb_build_object(
 'actor_name',coalesce(e.metadata->>'actor_name',s.full_name,p.display_name),
 'actor_staff_no',coalesce(e.metadata->>'actor_staff_no',s.staff_no),
 'actor_role_code',coalesce(e.actor_role_code,(select string_agg(distinct r.code,', ' order by r.code) from public.user_role_assignments a join public.system_roles r on r.id=a.role_id where a.profile_id=e.actor_profile_id and a.effective_from<=e.occurred_at::date and (a.effective_to is null or a.effective_to>=e.occurred_at::date))),
 'identity_snapshot',e.metadata ? 'actor_name') as row_data
 from public.audit_events e left join public.profiles p on p.id=e.actor_profile_id
 left join public.staff s on s.id=e.actor_staff_id or (e.actor_staff_id is null and s.profile_id=e.actor_profile_id)
 where p_correlation is null or e.correlation_id=p_correlation order by e.occurred_at desc,e.id desc limit 250
 ) rows),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION public.prospect_assignment_options()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
 if auth.uid() is null or not public.has_permission('crm.prospects.view') then raise exception 'CRM access required.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',full_name||' · '||staff_no) order by full_name) from public.staff where status in('ACTIVE','ON_LEAVE')),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION public.assign_prospect_staff(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p public.prospects; chosen uuid:=nullif(p_input->>'staff_id','')::uuid;
begin
 if auth.uid() is null or not public.has_permission('crm.prospects.manage') then raise exception 'CRM management permission required.'; end if;
 if length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Assignment reason required.'; end if;
 if chosen is not null and not exists(select 1 from public.staff where id=chosen and status in('ACTIVE','ON_LEAVE')) then raise exception 'Choose an active staff member.'; end if;
 select * into p from public.prospects where id=(p_input->>'prospect_id')::uuid for update;
 if p.id is null then raise exception 'Prospect not found.'; end if;
 if chosen is not distinct from p.assigned_to_staff_id then return jsonb_build_object('id',p.id); end if;
 update public.prospects set assigned_to_staff_id=chosen where id=p.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'PROSPECT',p.id::text,'ASSIGN_FOLLOWUP_STAFF',p_input->>'reason',jsonb_build_object('staff_id',p.assigned_to_staff_id),jsonb_build_object('staff_id',chosen));
 return jsonb_build_object('id',p.id);
end $function$;

CREATE OR REPLACE FUNCTION public.create_programme_offering(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_org uuid;
  v_row public.programme_offerings;
  v_reason text := btrim(coalesce(p_input->>'reason',''));
  v_correlation uuid := gen_random_uuid();
begin
 p_input:=p_input||jsonb_build_object('name',coalesce(nullif(btrim(p_input->>'name'),''),(select name from public.programs where id=(p_input->>'program_id')::uuid)));
  if v_actor is null or not public.has_permission('academics.manage') then
    raise exception 'You are not authorized to manage Programme Offerings.';
  end if;
  if length(v_reason)<5 then raise exception 'A change reason of at least five characters is required.'; end if;
  select id into v_org from public.organizations where code='SOHOJ' and is_active;
  if v_org is null or not exists (
    select 1 from public.branches b
    join public.academic_years y on y.id=(p_input->>'academic_year_id')::uuid
    join public.classes c on c.id=(p_input->>'class_id')::uuid
    join public.programs p on p.id=(p_input->>'program_id')::uuid
    where b.id=(p_input->>'branch_id')::uuid and b.is_active
      and b.organization_id=v_org and y.organization_id=v_org
      and c.organization_id=v_org and c.is_active
      and p.organization_id=v_org and p.is_active
      and (nullif(p_input->>'group_id','') is null or exists (
        select 1 from public.academic_groups g
        where g.id=(p_input->>'group_id')::uuid
          and g.organization_id=v_org and g.is_active))
  ) then
    raise exception 'Offering context must use active master data from the same organization.';
  end if;
  insert into public.programme_offerings(
    organization_id,branch_id,academic_year_id,class_id,program_id,
    group_id,code,name,created_by
  ) values (
    v_org,(p_input->>'branch_id')::uuid,(p_input->>'academic_year_id')::uuid,
    (p_input->>'class_id')::uuid,(p_input->>'program_id')::uuid,
    nullif(p_input->>'group_id','')::uuid,
    upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_actor
  ) returning * into v_row;
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    branch_id,entity_type,entity_id,action,reason,after_data)
  values (v_correlation,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
    v_row.branch_id,'PROGRAMME_OFFERING',v_row.id::text,'CREATE',v_reason,to_jsonb(v_row));
  return jsonb_build_object('offering_id',v_row.id,'correlation_id',v_correlation);
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_programme_offering(p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
 p_input:=p_input||jsonb_build_object('name',coalesce(nullif(btrim(p_input->>'name'),''),(select name from public.programs where id=(p_input->>'program_id')::uuid)));
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
  
  v_before:=to_jsonb(v_row);
  if v_row.status in('ACTIVE','RETIRED') and (
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
end
$function$;
