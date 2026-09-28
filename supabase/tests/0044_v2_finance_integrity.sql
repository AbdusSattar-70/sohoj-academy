-- Finance regression checks after the integrity migration.
begin;
do $$
declare
  actor uuid := gen_random_uuid();
  org uuid;
  ar uuid;
  payout uuid;
  reviewer uuid := gen_random_uuid();
  v_approval_id uuid;
  advance_id uuid;
  answer jsonb;
begin
  insert into auth.users(id,email,raw_user_meta_data)
    values(actor,'finance-integrity-'||actor||'@example.invalid','{"full_name":"Finance Integrity"}');
  perform public.bootstrap_admin('finance-integrity-'||actor||'@example.invalid','Finance Integrity');
  perform set_config('request.jwt.claim.sub',actor::text,true);
  select id into org from public.organizations where code='SOHOJ';
  select id into ar from public.finance_accounts where organization_id=org and code='1200';
  select id into payout from public.finance_accounts where organization_id=org and account_subtype='CASH';
  if org is null or ar is null or payout is null then raise exception 'Accounting seed incomplete'; end if;
  answer:=public.teacher_compensation_preview(date '2026-01-01',date '2026-01-31');
  if answer->'rows' is null then raise exception 'Preview did not return rows'; end if;
  begin
    perform public.finance_accounting_command(jsonb_build_object('action','SETTLE_ADVANCE',
      'request_id',gen_random_uuid(),'reason','Legacy shortcut is prohibited'));
    raise exception 'Legacy settlement command remained open';
  exception when others then
    if position('Permission denied for this accounting action' in sqlerrm)=0 then raise; end if;
  end;
  answer:=public.finance_accounting_command(jsonb_build_object('action','REQUEST_ADVANCE',
    'request_id',gen_random_uuid(),'reason','Approved project operating float',
    'beneficiary_type','PROJECT','project_reference','OPERATIONS-TEST',
    'purpose','Project advance integrity exercise','requested_amount',100));
  advance_id:=(answer->>'id')::uuid;
  select a.approval_id into v_approval_id from public.finance_advances a where a.id=advance_id;
  if v_approval_id is null then raise exception 'Advance approval was not created'; end if;
  begin
    perform public.finance_accounting_command(jsonb_build_object('action','DECIDE_ADVANCE',
      'request_id',gen_random_uuid(),'reason','Self approval must fail',
      'approval_id',v_approval_id,'decision','APPROVED'));
    raise exception 'Maker approved their own advance';
  exception when others then
    if position('Maker-checker' in sqlerrm)=0 then raise; end if;
  end;
  insert into auth.users(id,email,raw_user_meta_data)
    values(reviewer,'finance-reviewer-'||reviewer||'@example.invalid','{"full_name":"Finance Reviewer"}');
  perform public.bootstrap_admin('finance-reviewer-'||reviewer||'@example.invalid','Finance Reviewer');
  perform set_config('request.jwt.claim.sub',reviewer::text,true);
  perform public.finance_accounting_command(jsonb_build_object('action','DECIDE_ADVANCE',
    'request_id',gen_random_uuid(),'reason','Independent project advance review',
    'approval_id',v_approval_id,'decision','APPROVED'));
  if not exists(select 1 from public.finance_advances where id=advance_id and status='APPROVED') then
    raise exception 'Approved advance did not reach the approved state'; end if;
  perform public.finance_accounting_command(jsonb_build_object('action','PAY_ADVANCE',
    'request_id',gen_random_uuid(),'reason','Disburse project advance',
    'advance_id',advance_id,'amount',100,'payment_account_id',payout));
  if public.advance_balance(advance_id)<>100 then raise exception 'Advance balance incorrect'; end if;
  if not exists(select 1 from public.general_ledger_journals where source_type='ADVANCE_PAYMENT' and source_id is not null) then
    raise exception 'Advance disbursement was not posted'; end if;
  if not exists(select 1 from pg_constraint
    where conrelid='public.teacher_compensation_claims'::regclass and contype='u') then
    raise exception 'Once-only compensation claim uniqueness missing';
  end if;
end $$;
rollback;
