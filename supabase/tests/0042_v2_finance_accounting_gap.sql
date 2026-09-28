-- Finance/accounting invariants.
-- Run against the migrated test database.

begin;

do $$
declare
  org uuid;
  ar uuid;
  cash uuid;
  revenue uuid;
  journal uuid;
  debit_total numeric;
  credit_total numeric;
  actor uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,raw_user_meta_data)
  values(actor,'finance-test-'||actor||'@example.invalid','{"full_name":"Finance Test"}');
  perform public.bootstrap_admin('finance-test-'||actor||'@example.invalid','Finance Test');
  perform set_config('request.jwt.claim.sub',actor::text,true);
  select id into org from public.organizations where code='SOHOJ' limit 1;
  if org is null then raise exception 'SOHOJ organization seed is required.'; end if;

  select id into ar from public.finance_accounts
  where organization_id=org and code='1200';
  select id into cash from public.finance_accounts
  where organization_id=org and code='1100';
  select id into revenue from public.finance_accounts
  where organization_id=org and code='4000';

  if ar is null or cash is null or revenue is null then
    raise exception 'Seed finance accounts are missing.';
  end if;

  perform public.finance_post_journal(
    org,current_date,'MANUAL','TEST_JOURNAL',gen_random_uuid()::text,
    'Finance invariant test',
    actor,
    jsonb_build_array(
      jsonb_build_object('account_id',ar,'debit',100,'credit',0),
      jsonb_build_object('account_id',revenue,'debit',0,'credit',100)
    )
  );

  select j.id into journal
  from public.general_ledger_journals j
  where j.source_type='TEST_JOURNAL'
  order by j.created_at desc
  limit 1;

  select sum(debit),sum(credit)
  into debit_total,credit_total
  from public.general_ledger_lines
  where journal_id=journal;

  if debit_total<>credit_total or debit_total<>100 then
    raise exception 'Double-entry journal did not balance.';
  end if;

  if public.finance_account_balance(ar,current_date)<100 then
    raise exception 'Receivable account balance is incorrect.';
  end if;

  begin
    perform public.finance_post_journal(
      org,current_date,'MANUAL','TEST_UNBALANCED',gen_random_uuid()::text,
      'Must fail',
      actor,
      jsonb_build_array(
        jsonb_build_object('account_id',ar,'debit',100,'credit',0),
        jsonb_build_object('account_id',cash,'debit',0,'credit',90)
      )
    );
    raise exception 'Unbalanced journal was accepted.';
  exception when others then
    if position('Journal must balance' in sqlerrm)=0 then
      raise;
    end if;
  end;

  if not exists(
    select 1 from public.permissions where code='accounting.view'
  ) then raise exception 'Accounting permission seed missing.'; end if;

  if not exists(
    select 1 from public.permissions where code='staff.compensation.manage'
  ) then raise exception 'Compensation permission seed missing.'; end if;
end;
$$;
rollback;
