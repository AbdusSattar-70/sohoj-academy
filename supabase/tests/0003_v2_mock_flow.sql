-- ERP v2 public CRM mock flow.
-- Runs inside a transaction and rolls back all mock records.

begin;

do $$
declare
  v_class_id uuid;
  v_result jsonb;
  v_prospect_id uuid;
begin
  select id into v_class_id
  from public.classes
  where code='CLASS_8' and is_active
  limit 1;

  v_result := public.submit_public_interest(
    jsonb_build_object(
      'student_name','Mock Student',
      'student_name_bn','',
      'guardian_name','Mock Guardian',
      'guardian_relationship','FATHER',
      'mobile','01700000999',
      'alternate_mobile','',
      'class_id',v_class_id,
      'school_id','',
      'school_name_snapshot','Mock Verification School',
      'area','Mock Area',
      'preferred_schedule','EVENING',
      'preferred_days','SAT,MON,WED',
      'trial_interest',true,
      'program_ids','[]'::jsonb,
      'subject_ids','[]'::jsonb,
      'source_code','WALK_IN',
      'referral_note','',
      'notes','Verification-only record',
      'consent_to_contact',true
    )
  );

  v_prospect_id := (v_result->>'prospect_id')::uuid;

  if v_prospect_id is null then
    raise exception 'Public interest RPC did not return a Prospect identity.';
  end if;

  if not exists (
    select 1
    from public.prospects
    where id=v_prospect_id
      and prospect_no like 'PR-%'
      and student_name='Mock Student'
      and status='NEW'
  ) then
    raise exception 'Mock Prospect was not created correctly.';
  end if;

  if not exists (
    select 1
    from public.audit_events
    where entity_type='PROSPECT'
      and entity_id=v_prospect_id::text
      and action='CREATE_PUBLIC_INTEREST'
  ) then
    raise exception 'Public interest creation did not create an audit event.';
  end if;
end;
$$;

select
  'PASS' as v2_mock_flow_status,
  (select count(*) from public.prospects where student_name='Mock Student') as mock_prospects;

rollback;
