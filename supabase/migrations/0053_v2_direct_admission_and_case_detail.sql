-- SOURCE: 0053_v3_admission_origin_direct_intake.sql
-- ============================================================

-- V3 transition: make admission origin explicit and stop direct staff intake
-- from manufacturing CRM Prospects.
--
-- Existing V2 records remain intact. Legacy staff-created Prospect links are
-- retained for historical compatibility, while new DIRECT_STAFF cases use
-- prospect_id = null.

alter table public.admission_cases
  add column if not exists origin text,
  add column if not exists origin_prospect_id uuid references public.prospects(id);

update public.admission_cases a
set
  origin = case
    when a.existing_student then 'EXISTING_STUDENT'
    when exists (
      select 1
      from public.public_admission_applications pa
      where pa.prospect_id = a.prospect_id
    ) then 'PUBLIC_APPLICATION'
    when exists (
      select 1
      from public.prospects p
      where p.id = a.prospect_id
        and p.submitted_via = 'ERP'
    ) then 'DIRECT_STAFF'
    else 'PROSPECT_CONVERSION'
  end,
  origin_prospect_id = case
    when a.existing_student then null
    when exists (
      select 1
      from public.public_admission_applications pa
      where pa.prospect_id = a.prospect_id
    ) then a.prospect_id
    when exists (
      select 1
      from public.prospects p
      where p.id = a.prospect_id
        and p.submitted_via = 'ERP'
    ) then null
    else a.prospect_id
  end;

alter table public.admission_cases
  alter column origin set default 'PROSPECT_CONVERSION',
  alter column origin set not null;

alter table public.admission_cases
  drop constraint if exists admission_identity_source;

alter table public.admission_cases
  add constraint admission_identity_source check (
    (
      origin = 'DIRECT_STAFF'
      and not existing_student
      and origin_prospect_id is null
    )
    or (
      origin in ('PROSPECT_CONVERSION', 'PUBLIC_APPLICATION')
      and not existing_student
      and prospect_id is not null
      and origin_prospect_id = prospect_id
    )
    or (
      origin = 'EXISTING_STUDENT'
      and existing_student
      and student_id is not null
      and origin_prospect_id is null
    )
  );

create index if not exists admission_cases_origin_idx
  on public.admission_cases(origin, created_at desc);

comment on column public.admission_cases.origin is
  'Canonical source of the admission: DIRECT_STAFF, PROSPECT_CONVERSION, PUBLIC_APPLICATION or EXISTING_STUDENT.';

comment on column public.admission_cases.origin_prospect_id is
  'Real CRM Prospect only when the admission originated from Prospect conversion or a public application.';

comment on column public.admission_cases.prospect_id is
  'V2 compatibility link. New DIRECT_STAFF admissions leave this null; use origin_prospect_id for canonical Prospect origin.';

alter table public.staff_admission_intake_requests
  alter column prospect_id drop not null;

create or replace function public.create_staff_admission_intake(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid := auth.uid();
  req uuid := nullif(p_input->>'request_id','')::uuid;
  reason text := btrim(coalesce(p_input->>'reason',''));
  existing public.staff_admission_intake_requests;
  offering public.programme_offerings;
  batch public.batches;
  fee public.fee_plan_versions;
  organization public.organizations;
  admission public.admission_cases;
  open_seats integer;
  local_today date;
  student_name text := btrim(coalesce(p_input->>'student_name',''));
  guardian_name text := btrim(coalesce(p_input->>'guardian_name',''));
  mobile text := regexp_replace(coalesce(p_input->>'mobile',''), '\\D', '', 'g');
  alternate_mobile text := nullif(regexp_replace(coalesce(p_input->>'alternate_mobile',''), '\\D', '', 'g'), '');
  birth_date date := nullif(p_input->>'date_of_birth','')::date;
  gender_value text := nullif(btrim(coalesce(p_input->>'gender','')), '');
  school_name text := nullif(btrim(coalesce(p_input->>'school_name','')), '');
  school_roll text := nullif(btrim(coalesce(p_input->>'school_roll','')), '');
  guardian_address text := btrim(coalesce(p_input->>'guardian_address',''));
  guardian_relationship text := nullif(btrim(coalesce(p_input->>'guardian_relationship','')), '');
  intake_note text := nullif(btrim(coalesce(p_input->>'referral_note','')), '');
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;

  if req is null or length(reason) < 5 or length(reason) > 500 then
    raise exception 'Request identity and an audit reason of 5 to 500 characters are required.';
  end if;

  if length(student_name) < 2 or length(student_name) > 160
    or length(guardian_name) < 2 or length(guardian_name) > 160
    or mobile !~ '^01[3-9][0-9]{8}$'
    or length(guardian_address) < 5
    or coalesce((p_input->>'consent_to_contact')::boolean, false) is not true then
    raise exception 'Enter the student, guardian, valid mobile, address, and confirm permission to contact.';
  end if;

  if gender_value is not null
    and gender_value not in ('Female','Male','Other','Prefer not to say') then
    raise exception 'Choose a valid gender option or leave it blank.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text, 0));

  select *
  into existing
  from public.staff_admission_intake_requests
  where request_id = req;

  if found then
    if existing.actor_id <> actor or existing.payload <> p_input then
      raise exception 'Request identity was already used for different intake details.';
    end if;

    select *
    into admission
    from public.admission_cases
    where id = existing.admission_id;

    return jsonb_build_object(
      'admission_id', existing.admission_id,
      'admission_no', admission.admission_no
    );
  end if;

  select *
  into offering
  from public.programme_offerings
  where id = nullif(p_input->>'offering_id','')::uuid
    and status = 'ACTIVE'
  for share;

  if offering.id is null then
    raise exception 'Choose an active programme offering.';
  end if;

  select *
  into batch
  from public.batches
  where id = nullif(p_input->>'batch_id','')::uuid
    and is_active
  for update;

  if batch.id is null or batch.offering_id is distinct from offering.id then
    raise exception 'Choose an active batch belonging to the selected programme offering.';
  end if;

  select *
  into organization
  from public.organizations
  where id = offering.organization_id;

  if organization.id is null then
    raise exception 'The selected programme organization is unavailable.';
  end if;

  local_today := timezone(organization.timezone, now())::date;

  select *
  into fee
  from public.fee_plan_versions
  where offering_id = offering.id
    and status = 'ACTIVE'
    and effective_from <= local_today
  order by effective_from desc, version desc
  limit 1;

  if fee.id is null then
    raise exception 'Publish an effective Fee Plan for this offering before starting admission.';
  end if;

  select count(*)
  into open_seats
  from public.enrollments
  where batch_id = batch.id
    and status = 'ACTIVE';

  if open_seats >= least(
    batch.capacity,
    coalesce(
      (
        select (payload->>'max_students')::integer
        from public.business_rule_versions
        where domain = 'academics'
          and rule_key = 'batch_capacity_policy'
          and status = 'ACTIVE'
        order by version desc
        limit 1
      ),
      batch.capacity
    )
  ) then
    raise exception 'The selected batch is full. Choose another available batch.';
  end if;

  if exists (
    select 1
    from public.admission_cases a
    where a.origin = 'DIRECT_STAFF'
      and lower(a.identity_snapshot->>'student_name') = lower(student_name)
      and regexp_replace(a.identity_snapshot->>'mobile', '\\D', '', 'g') = mobile
      and a.status <> 'CANCELLED'
  ) then
    raise exception 'A matching direct admission draft already exists. Open Admissions and continue that case.';
  end if;

  insert into public.admission_cases (
    prospect_id,
    origin,
    origin_prospect_id,
    batch_id,
    fee_plan_version_id,
    existing_student,
    identity_snapshot,
    created_by
  )
  values (
    null,
    'DIRECT_STAFF',
    null,
    batch.id,
    fee.id,
    false,
    jsonb_build_object(
      'student_name', student_name,
      'student_name_bn', nullif(btrim(coalesce(p_input->>'student_name_bn','')), ''),
      'date_of_birth', birth_date,
      'gender', gender_value,
      'school_name', school_name,
      'school_roll', school_roll,
      'guardian_name', guardian_name,
      'guardian_relationship', guardian_relationship,
      'mobile', mobile,
      'alternate_mobile', alternate_mobile,
      'guardian_address', guardian_address,
      'intake_note', intake_note,
      'consent_to_contact', true
    ),
    actor
  )
  returning *
  into admission;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values (
    req,
    actor,
    (select s.id from public.staff s where s.profile_id = actor limit 1),
    'ADMISSION',
    admission.id::text,
    'CREATE_DIRECT_STAFF_ADMISSION',
    reason,
    null,
    to_jsonb(admission),
    jsonb_build_object(
      'origin', 'DIRECT_STAFF',
      'offering_id', offering.id,
      'batch_id', batch.id
    )
  );

  insert into public.staff_admission_intake_requests(
    request_id,
    actor_id,
    payload,
    prospect_id,
    admission_id
  )
  values (
    req,
    actor,
    p_input,
    null,
    admission.id
  );

  return jsonb_build_object(
    'admission_id', admission.id,
    'admission_no', admission.admission_no
  );
end;
$$;

revoke all on function public.create_staff_admission_intake(jsonb)
from public, anon;

grant execute on function public.create_staff_admission_intake(jsonb)
to authenticated;



-- ============================================================
-- SOURCE: 0054_v3_admission_case_detail.sql
-- ============================================================

-- V3 focused read model for the admission working page.
-- Historical masters are read without requiring their current active status.

create or replace function public.admission_case_detail(p_admission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  result jsonb;
begin
  if auth.uid() is null or not public.has_permission('admissions.view') then
    raise exception 'Admission workspace access denied.';
  end if;

  select jsonb_build_object(
    'id', a.id,
    'number', a.admission_no,
    'status', a.status,
    'createdAt', a.created_at,
    'existingStudent', a.existing_student,
    'origin', a.origin,
    'originProspectId', a.origin_prospect_id,
    'batchId', a.batch_id,
    'batchName', b.name,
    'batchCode', b.code,
    'batchCapacity', b.capacity,
    'batchOccupied', (
      select count(*)
      from public.enrollments e
      where e.batch_id = b.id
        and e.status = 'ACTIVE'
    ),
    'offeringId', o.id,
    'offeringName', o.name,
    'className', cl.name,
    'yearName', ay.name,
    'branchName', br.name,
    'studentNo', s.student_no,
    'studentId', s.id,
    'name', a.identity_snapshot->>'student_name',
    'nameBn', a.identity_snapshot->>'student_name_bn',
    'gender', a.identity_snapshot->>'gender',
    'dateOfBirth', a.identity_snapshot->>'date_of_birth',
    'schoolName', a.identity_snapshot->>'school_name',
    'schoolRoll', a.identity_snapshot->>'school_roll',
    'guardianAddress', a.identity_snapshot->>'guardian_address',
    'alternateMobile', a.identity_snapshot->>'alternate_mobile',
    'guardianRelationship', a.identity_snapshot->>'guardian_relationship',
    'guardian', a.identity_snapshot->>'guardian_name',
    'mobile', a.identity_snapshot->>'mobile',
    'feeVersion', f.version,
    'feePlanId', f.id,
    'policyVersion', r.version,
    'paymentRequirement', r.payload->>'payment_requirement',
    'components', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', fc.name,
          'amount', fc.amount,
          'recurrence', fc.recurrence
        )
        order by fc.created_at, fc.id
      )
      from public.fee_plan_components fc
      where fc.fee_plan_version_id = f.id
    ), '[]'::jsonb),
    'invoice', case
      when i.id is null then null
      else jsonb_build_object(
        'number', i.invoice_no,
        'total', i.total,
        'dueOn', i.due_on,
        'paid', bal.paid,
        'credits', bal.credits,
        'net', bal.net,
        'refunded', bal.refunded,
        'due', bal.due,
        'credit', bal.credit_balance
      )
    end,
    'receipts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'number', p.receipt_no,
          'amount', pa.amount,
          'postedAt', p.posted_at,
          'method', pm.name,
          'refunded', coalesce((
            select sum(ra.amount)
            from public.refund_authorizations ra
            join public.refund_payouts rp
              on rp.authorization_id = ra.id
            where ra.payment_id = p.id
          ), 0)
        )
        order by p.posted_at, p.receipt_no
      )
      from public.admission_payment_allocations pa
      join public.admission_payments p
        on p.id = pa.payment_id
      join public.payment_methods pm
        on pm.id = p.payment_method_id
      where pa.invoice_id = i.id
    ), '[]'::jsonb)
  )
  into result
  from public.admission_cases a
  join public.fee_plan_versions f
    on f.id = a.fee_plan_version_id
  join public.batches b
    on b.id = a.batch_id
  join public.programme_offerings o
    on o.id = b.offering_id
  join public.classes cl
    on cl.id = b.class_id
  join public.academic_years ay
    on ay.id = b.academic_year_id
  left join public.branches br
    on br.id = b.branch_id
  left join public.students s
    on s.id = a.student_id
  left join public.business_rule_versions r
    on r.id = a.activation_policy_version_id
  left join public.admission_invoices i
    on i.admission_id = a.id
   and i.invoice_kind = 'INITIAL'
  left join lateral public.invoice_balance(i.id) bal
    on true
  where a.id = p_admission_id;

  if result is null then
    raise exception 'Admission Case not found.';
  end if;

  return result;
end;
$$;

revoke all on function public.admission_case_detail(uuid)
from public, anon;

grant execute on function public.admission_case_detail(uuid)
to authenticated;



-- ============================================================
