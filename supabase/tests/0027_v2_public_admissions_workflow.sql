-- Public admissions workflow verification (rollback-only).
-- Covers website visibility, accepting applications, open-window checks,
-- admission intent requiring an offering, and prospect intent/offering fields.

begin;
do $$
declare
  u uuid := gen_random_uuid();
  org uuid;
  branch uuid;
  cl uuid;
  program uuid;
  yr uuid;
  offering uuid;
  fee uuid;
  prospect uuid;
  result jsonb;
  listed jsonb;
  today date := (now() at time zone 'Asia/Dhaka')::date;
  raised boolean;
begin
  insert into auth.users(id, email, raw_user_meta_data)
  values (u, 'public-adm-' || u || '@example.invalid', '{"full_name":"Public Admissions Test"}');
  perform public.bootstrap_admin('public-adm-' || u || '@example.invalid', 'Public Admissions Test');
  perform set_config('request.jwt.claim.sub', u::text, true);

  select id into org from public.organizations where code = 'SOHOJ' and is_active limit 1;
  select id into branch from public.branches where organization_id = org and is_active limit 1;
  select id into cl from public.classes where organization_id = org and is_active order by sort_order limit 1;
  select id into program from public.programs where organization_id = org and is_active limit 1;

  if org is null or branch is null or cl is null or program is null then
    raise exception 'Seed org/branch/class/program required for public admissions tests.';
  end if;

  insert into public.academic_years(organization_id, name, starts_on, ends_on, is_active)
  values (org, 'PADM-' || left(u::text, 8), today, today + 365, false)
  returning id into yr;

  result := public.create_programme_offering(jsonb_build_object(
    'branch_id', branch,
    'academic_year_id', yr,
    'class_id', cl,
    'program_id', program,
    'code', 'PADM-' || left(u::text, 8),
    'name', 'Public Admissions Test Offering',
    'reason', 'Public admissions acceptance fixture'
  ));
  offering := (result->>'offering_id')::uuid;

  result := public.publish_fee_plan(jsonb_build_object(
    'offering_id', offering,
    'billing_cycle', 'MONTHLY',
    'due_day', 10,
    'effective_from', today,
    'reason', 'Activate offering for public admissions tests',
    'components', jsonb_build_array(
      jsonb_build_object(
        'code', 'TUITION',
        'name', 'Tuition',
        'amount', 1000,
        'charge_type', 'TUITION',
        'recurrence', 'PER_CYCLE'
      )
    )
  ));
  fee := (result->>'fee_plan_version_id')::uuid;
  if fee is null then
    raise exception 'Fee plan publish did not activate offering.';
  end if;

  -- Hidden by default: not website visible, not accepting
  listed := public.list_public_programme_offerings();
  if exists (
    select 1 from jsonb_array_elements(listed) e
    where (e->>'id')::uuid = offering
  ) then
    raise exception 'Offering must not appear publicly before website visibility is enabled.';
  end if;

  perform public.update_programme_offering_public_controls(jsonb_build_object(
    'offering_id', offering,
    'showcase_title', 'Public Test Programme',
    'showcase_title_bn', 'পাবলিক টেস্ট প্রোগ্রাম',
    'showcase_description', 'Acceptance fixture description',
    'showcase_description_bn', 'যাচাইকরণ বর্ণনা',
    'showcase_eyebrow', 'Class fixture',
    'showcase_eyebrow_bn', 'ক্লাস',
    'showcase_icon', 'book-open-check',
    'showcase_sort_order', 10,
    'is_website_visible', true,
    'is_accepting_applications', false,
    'applications_open_on', null,
    'applications_close_on', null,
    'subject_ids', '[]'::jsonb,
    'reason', 'Publish card but keep applications closed'
  ));

  listed := public.list_public_programme_offerings();
  if not exists (
    select 1 from jsonb_array_elements(listed) e
    where (e->>'id')::uuid = offering
      and coalesce((e->>'is_accepting_applications')::boolean, false) = false
  ) then
    raise exception 'Website-visible offering should list with applications closed.';
  end if;

  -- Interest without offering still allowed
  result := public.submit_public_interest(jsonb_build_object(
    'student_name', 'Queue Student',
    'guardian_name', 'Queue Guardian',
    'mobile', '01710000001',
    'class_id', cl,
    'school_name_snapshot', 'Unlisted Review School',
    'consent_to_contact', true,
    'intent', 'interest'
  ));
  prospect := (result->>'prospect_id')::uuid;
  if prospect is null then
    raise exception 'General interest submit failed.';
  end if;
  if not exists (
    select 1 from public.prospects
    where id = prospect
      and submission_intent = 'interest'
      and interested_offering_id is null
      and school_id is null
      and school_name_snapshot = 'Unlisted Review School'
      and status = 'NEW'
  ) then
    raise exception 'General interest prospect fields incorrect.';
  end if;

  -- Admission without offering must fail
  raised := false;
  begin
    perform public.submit_public_interest(jsonb_build_object(
      'student_name', 'Admission No Offering',
      'guardian_name', 'Guardian',
      'mobile', '01710000002',
      'class_id', cl,
      'consent_to_contact', true,
      'intent', 'admission'
    ));
  exception when others then
    raised := true;
  end;
  if not raised then
    raise exception 'Admission without offering must be rejected.';
  end if;

  -- Closed applications must reject offering-linked submits
  raised := false;
  begin
    perform public.submit_public_interest(jsonb_build_object(
      'student_name', 'Closed App Student',
      'guardian_name', 'Guardian',
      'mobile', '01710000003',
      'class_id', cl,
      'consent_to_contact', true,
      'intent', 'interest',
      'offering_id', offering
    ));
  exception when others then
    raised := true;
  end;
  if not raised then
    raise exception 'Submit against non-accepting offering must be rejected.';
  end if;

  -- Open applications and accept an admission
  perform public.update_programme_offering_public_controls(jsonb_build_object(
    'offering_id', offering,
    'showcase_title', 'Public Test Programme',
    'showcase_title_bn', 'পাবলিক টেস্ট প্রোগ্রাম',
    'showcase_description', 'Acceptance fixture description',
    'showcase_description_bn', 'যাচাইকরণ বর্ণনা',
    'showcase_eyebrow', 'Class fixture',
    'showcase_eyebrow_bn', 'ক্লাস',
    'showcase_icon', 'book-open-check',
    'showcase_sort_order', 10,
    'is_website_visible', true,
    'is_accepting_applications', true,
    'applications_open_on', today - 1,
    'applications_close_on', today + 30,
    'subject_ids', '[]'::jsonb,
    'reason', 'Open applications for acceptance fixture'
  ));

  listed := public.list_public_programme_offerings();
  if not exists (
    select 1 from jsonb_array_elements(listed) e
    where (e->>'id')::uuid = offering
      and e->>'academic_year_name' = 'PADM-' || left(u::text, 8)
      and e->>'branch_name' is not null
      and e->>'class_name' is not null
      and e->>'application_state' = 'OPEN'
      and (e->>'is_accepting_applications')::boolean
  ) then
    raise exception 'Public card must show academic context and an effective open state.';
  end if;

  result := public.submit_public_interest(jsonb_build_object(
    'student_name', 'Admission Student',
    'guardian_name', 'Admission Guardian',
    'mobile', '01710000004',
    'class_id', cl,
    'school_name_snapshot', 'Linked Later School',
    'consent_to_contact', true,
    'intent', 'admission',
    'offering_id', offering
  ));
  prospect := (result->>'prospect_id')::uuid;
  if not exists (
    select 1 from public.prospects
    where id = prospect
      and submission_intent = 'admission'
      and interested_offering_id = offering
      and status = 'NEW'
  ) then
    raise exception 'Admission prospect must store intent and offering.';
  end if;

  if not exists (
    select 1 from public.audit_events
    where entity_type = 'PROSPECT'
      and entity_id = prospect::text
      and action = 'CREATE_PUBLIC_INTEREST'
      and after_data->>'submission_intent' = 'admission'
  ) then
    raise exception 'Admission submit must write CREATE_PUBLIC_INTEREST audit.';
  end if;

  -- Outside application window must fail
  perform public.update_programme_offering_public_controls(jsonb_build_object(
    'offering_id', offering,
    'showcase_title', 'Public Test Programme',
    'showcase_title_bn', 'পাবলিক টেস্ট প্রোগ্রাম',
    'showcase_description', 'Acceptance fixture description',
    'showcase_description_bn', 'যাচাইকরণ বর্ণনা',
    'showcase_eyebrow', 'Class fixture',
    'showcase_eyebrow_bn', 'ক্লাস',
    'showcase_icon', 'book-open-check',
    'showcase_sort_order', 10,
    'is_website_visible', true,
    'is_accepting_applications', true,
    'applications_open_on', today + 7,
    'applications_close_on', today + 30,
    'subject_ids', '[]'::jsonb,
    'reason', 'Move open window into the future'
  ));

  listed := public.list_public_programme_offerings();
  if not exists (
    select 1 from jsonb_array_elements(listed) e
    where (e->>'id')::uuid = offering
      and e->>'application_state' = 'UPCOMING'
      and not (e->>'is_accepting_applications')::boolean
  ) then
    raise exception 'Upcoming offering must display without an open application action.';
  end if;

  raised := false;
  begin
    perform public.submit_public_interest(jsonb_build_object(
      'student_name', 'Too Early Student',
      'guardian_name', 'Guardian',
      'mobile', '01710000005',
      'class_id', cl,
      'consent_to_contact', true,
      'intent', 'interest',
      'offering_id', offering
    ));
  exception when others then
    raised := true;
  end;
  if not raised then
    raise exception 'Submit before applications_open_on must be rejected.';
  end if;

  perform public.update_programme_offering_public_controls(jsonb_build_object(
    'offering_id', offering,
    'showcase_title', 'Public Test Programme',
    'showcase_title_bn', 'পাবলিক টেস্ট প্রোগ্রাম',
    'showcase_description', 'Acceptance fixture description',
    'showcase_description_bn', 'যাচাইকরণ বর্ণনা',
    'showcase_eyebrow', 'Class fixture',
    'showcase_eyebrow_bn', 'ক্লাস',
    'showcase_icon', 'book-open-check',
    'showcase_sort_order', 10,
    'is_website_visible', true,
    'is_accepting_applications', true,
    'applications_open_on', today - 30,
    'applications_close_on', today - 1,
    'subject_ids', '[]'::jsonb,
    'reason', 'Close the public application window'
  ));
  listed := public.list_public_programme_offerings();
  if not exists (
    select 1 from jsonb_array_elements(listed) e
    where (e->>'id')::uuid = offering
      and e->>'application_state' = 'CLOSED'
      and not (e->>'is_accepting_applications')::boolean
  ) then
    raise exception 'Expired offering must remain visible but closed.';
  end if;
end;
$$;

select 'PASS' as public_admissions_workflow_status;
rollback;
