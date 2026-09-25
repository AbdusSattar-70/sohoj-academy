-- Development-only verification for Prospect / Student Bank CRM.
-- Everything created here is rolled back.

begin;

do $$
declare
  v_result jsonb;
  v_prospect_no text;
  v_duplicate_blocked boolean := false;
begin
  if not exists(select 1 from public.lead_sources where code='WALK_IN') then
    raise exception 'FAIL: lead-source seed data missing';
  end if;

  v_result := public.submit_public_interest(
    jsonb_build_object(
      'student_name','ERP Prospect Test',
      'guardian_name','ERP Guardian Test',
      'guardian_relationship','Father',
      'mobile','01999999999',
      'area','Test Area',
      'preferred_schedule','Evening',
      'trial_interest',true,
      'program_ids','[]'::jsonb,
      'subject_ids','[]'::jsonb,
      'consent_to_contact',true
    )
  );

  v_prospect_no := v_result->>'prospect_no';

  if v_prospect_no is null or v_prospect_no not like 'PR-%' then
    raise exception 'FAIL: prospect number was not generated';
  end if;

  if not exists(
    select 1 from public.prospects
    where prospect_no=v_prospect_no
      and status='NEW'
      and submitted_via='PUBLIC_WEB'
  ) then
    raise exception 'FAIL: public interest did not create a NEW prospect';
  end if;

  if not exists(
    select 1 from public.audit_events
    where entity_type='PROSPECT'
      and action='PUBLIC_INTEREST_SUBMITTED'
      and after_data->>'prospect_no'=v_prospect_no
  ) then
    raise exception 'FAIL: public interest audit event missing';
  end if;

  begin
    perform public.submit_public_interest(
      jsonb_build_object(
        'student_name','ERP Prospect Test',
        'guardian_name','ERP Guardian Test',
        'mobile','01999999999',
        'consent_to_contact',true
      )
    );
  exception when others then
    v_duplicate_blocked := true;
  end;

  if not v_duplicate_blocked then
    raise exception 'FAIL: immediate duplicate public submission was accepted';
  end if;

  raise notice 'PASS: Prospect CRM public submission, audit event and duplicate protection verified.';
end $$;

rollback;
