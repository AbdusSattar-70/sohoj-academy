-- V3 direct accounting regression checks.
-- Development-only fixtures; rolled back. Run as database owner.

begin;

do $$
declare
  u uuid:=gen_random_uuid();
  denied uuid:=gen_random_uuid();
  org uuid;
  branch uuid;
  advance_id uuid;
  vendor_id uuid;
  category_id uuid;
  cash_account uuid;
  expense_id uuid;
  adjustment_id uuid;
  result jsonb;
  input jsonb;
  approval_count integer;
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values(
    u,
    'accounting-v3-'||u||'@example.invalid',
    '{"full_name":"Accounting V3 Test"}'
  );

  perform public.bootstrap_admin('accounting-v3-'||u||'@example.invalid','Accounting V3 Test');
  perform set_config('request.jwt.claim.sub',u::text,true);

  select id into org
  from public.organizations
  where code='SOHOJ';

  select id into cash_account
  from public.finance_accounts
  where organization_id=org
    and account_subtype='CASH'
  limit 1;

  select id into category_id
  from public.finance_expense_categories
  where organization_id=org
    and is_active
  limit 1;

  if org is null or cash_account is null or category_id is null then
    raise exception 'Accounting test baseline is incomplete.';
  end if;

  insert into public.vendors(
    organization_id,
    name,
    created_by
  )
  values(
    org,
    'V3 Accounting Vendor '||left(u::text,8),
    u
  )
  returning id into vendor_id;

  select count(*) into approval_count
  from public.approval_requests;

  input:=jsonb_build_object(
    'action','CREATE_ADVANCE',
    'request_id',gen_random_uuid(),
    'reason','Authorize direct accounting test advance',
    'beneficiary_type','VENDOR',
    'vendor_id',vendor_id,
    'purpose','Direct V3 accounting test advance',
    'requested_amount',100
  );

  result:=public.finance_v3_accounting_command(input);

  advance_id:=(result->>'id')::uuid;

  if (select status from public.finance_advances where id=advance_id)<>'APPROVED' then
    raise exception 'Direct advance was not immediately authorized.';
  end if;

  if (select approval_id from public.finance_advances where id=advance_id) is not null then
    raise exception 'Direct advance created a generic approval.';
  end if;

  if (select authorized_by from public.finance_advances where id=advance_id)<>u then
    raise exception 'Direct advance actor was not recorded.';
  end if;

  if public.finance_v3_accounting_command(input)<>result then
    raise exception 'Direct advance retry was not idempotent.';
  end if;

  input:=jsonb_build_object(
    'action','CREATE_EXPENSE_DIRECT',
    'request_id',gen_random_uuid(),
    'reason','Record direct operating expense for V3 test',
    'expense_date',current_date,
    'category_id',category_id,
    'amount',75,
    'description','Direct V3 accounting test expense',
    'payment_mode','PAID_NOW',
    'payment_account_id',cash_account,
    'receipt_reference','V3-TEST-75'
  );

  result:=public.finance_v3_accounting_command(input);
  expense_id:=(result->>'id')::uuid;

  if (select status from public.finance_expenses where id=expense_id)<>'POSTED' then
    raise exception 'Direct expense was not posted.';
  end if;

  if (select approval_id from public.finance_expenses where id=expense_id) is not null then
    raise exception 'Direct expense created a generic approval.';
  end if;

  if not exists(
    select 1 from public.general_ledger_journals
    where source_type='EXPENSE'
      and source_id=expense_id::text
  ) then
    raise exception 'Direct expense did not create a ledger journal.';
  end if;

  if public.finance_v3_accounting_command(input)<>result then
    raise exception 'Direct expense retry was not idempotent.';
  end if;

  input:=jsonb_build_object(
    'action','APPLY_COMP_ADJUSTMENT',
    'request_id',gen_random_uuid(),
    'reason','Record direct teacher compensation adjustment test',
    'teacher_id',(select id from public.staff where status='ACTIVE' limit 1),
    'amount',25,
    'effective_period',date_trunc('month',current_date)::date,
    'adjustment_type','ADJUSTMENT'
  );

  result:=public.finance_v3_accounting_command(input);
  adjustment_id:=(result->>'id')::uuid;

  if (select status from public.teacher_compensation_adjustments where id=adjustment_id)<>'APPROVED' then
    raise exception 'Direct compensation adjustment was not authorized.';
  end if;

  if (select approval_id from public.teacher_compensation_adjustments where id=adjustment_id) is not null then
    raise exception 'Direct compensation adjustment created a generic approval.';
  end if;

  if (select authorized_by from public.teacher_compensation_adjustments where id=adjustment_id)<>u then
    raise exception 'Compensation adjustment actor was not recorded.';
  end if;

  if (select count(*) from public.approval_requests)<>approval_count then
    raise exception 'V3 direct accounting actions created approval rows.';
  end if;

  insert into auth.users(id,email,raw_user_meta_data)
  values(
    denied,
    'accounting-v3-denied-'||denied||'@example.invalid',
    '{"full_name":"Accounting V3 Denied"}'
  );

  perform set_config('request.jwt.claim.sub',denied::text,true);

  begin
    perform public.finance_v3_accounting_command(jsonb_build_object(
      'action','CREATE_EXPENSE_DIRECT',
      'request_id',gen_random_uuid(),
      'reason','Unauthorized accounting test',
      'expense_date',current_date,
      'category_id',category_id,
      'amount',10,
      'description','Unauthorized test expense',
      'payment_mode','PAID_NOW',
      'payment_account_id',cash_account
    ));
    raise exception 'Unauthorized direct accounting command was accepted.';
  exception when others then
    if position('Expense management permission required' in sqlerrm)=0 then
      raise;
    end if;
  end;
end;
$$;

rollback;
