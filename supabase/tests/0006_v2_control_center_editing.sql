-- ERP v2 editable Control Center verification.

do $$
begin
  if to_regprocedure('public.validate_business_rule_payload(text,text,jsonb)') is null
     or to_regprocedure('public.publish_business_rule_version(text,text,jsonb,text)') is null
     or to_regprocedure('public.set_role_permissions(text,text[],text)') is null then
    raise exception 'Editable Control Center functions are incomplete.';
  end if;
end;
$$;

do $$
begin
  if not public.validate_business_rule_payload(
    'academics',
    'batch_capacity_policy',
    '{"max_students":12}'::jsonb
  ) then
    raise exception 'Valid batch-capacity policy was rejected.';
  end if;

  if public.validate_business_rule_payload(
    'academics',
    'batch_capacity_policy',
    '{"max_students":0}'::jsonb
  ) then
    raise exception 'Invalid batch-capacity policy was accepted.';
  end if;

  if not public.validate_business_rule_payload(
    'teacher_compensation',
    'default_policy',
    '{
      "teaching_pool_percent":30,
      "teaching_pool_review_max_percent":40,
      "acquisition_bonus_percent":50,
      "retention_3_month_percent":15,
      "retention_6_month_percent":20
    }'::jsonb
  ) then
    raise exception 'Valid teacher compensation policy was rejected.';
  end if;

  if public.validate_business_rule_payload(
    'teacher_compensation',
    'default_policy',
    '{
      "teaching_pool_percent":50,
      "teaching_pool_review_max_percent":40,
      "acquisition_bonus_percent":50,
      "retention_3_month_percent":15,
      "retention_6_month_percent":20
    }'::jsonb
  ) then
    raise exception 'Teacher pool greater than review maximum was accepted.';
  end if;

  if not public.validate_business_rule_payload(
    'admissions',
    'activation_policy',
    '{
      "requires_admission_acceptance":true,
      "requires_initial_billing_posted":true,
      "payment_requirement":"MINIMUM_PERCENT",
      "minimum_payment_percent":25,
      "allow_credit_enrollment":true,
      "count_student_active_only_when_enrollment_active":true
    }'::jsonb
  ) then
    raise exception 'Valid admission activation policy was rejected.';
  end if;

  if public.validate_business_rule_payload(
    'admissions',
    'activation_policy',
    '{
      "requires_admission_acceptance":true,
      "requires_initial_billing_posted":true,
      "payment_requirement":"FULL",
      "minimum_payment_percent":25,
      "allow_credit_enrollment":false,
      "count_student_active_only_when_enrollment_active":true
    }'::jsonb
  ) then
    raise exception 'Invalid FULL-payment admission policy was accepted.';
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('authenticated','public.business_rule_versions','INSERT')
     or has_table_privilege('authenticated','public.business_rule_versions','UPDATE')
     or has_table_privilege('authenticated','public.role_permissions','INSERT')
     or has_table_privilege('authenticated','public.role_permissions','UPDATE')
     or has_table_privilege('authenticated','public.role_permissions','DELETE') then
    raise exception 'Authenticated API can bypass controlled policy/permission workflows.';
  end if;
end;
$$;

select
  'PASS' as v2_control_center_editing_status,
  (select count(*) from public.business_rule_versions where status='ACTIVE') as active_policies,
  (select count(*) from public.permissions) as permissions;
