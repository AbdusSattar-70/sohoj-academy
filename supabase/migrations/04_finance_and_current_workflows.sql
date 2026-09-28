-- ACTIVE V3 MIGRATION · 04_finance_and_current_workflows.sql
-- Source: supabase/baseline_v3/0004_v3_finance_and_current_workflows.sql
-- Apply only on a clean database (no prior schema_migrations history).

-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 04
-- Generated from the reviewed V2/V3 schema history for a CLEAN database.
-- No data migration is included. Apply after baseline parts 01–03.

-- ============================================================
-- SOURCE: 0042_v2_finance_accounting_gap.sql
-- ============================================================

-- Sohoj Academy ERP v2
-- Finance & Accounting gap closure: ledger, advances/payables, expenses,
-- reconciliation, teacher compensation and settlements.
--
-- The existing billing workflow remains the source of student-charge truth.
-- This migration adds the double-entry accounting layer around those facts.

-- ---------------------------------------------------------------------------
-- Finance permissions
-- ---------------------------------------------------------------------------

insert into public.permissions(code,name,description)
values
  ('accounting.view','View accounting','View ledger, chart of accounts and reconciliations.'),
  ('accounting.manage','Manage accounting','Post controlled accounting journals and mappings.'),
  ('finance.advances.manage','Manage advances','Request, pay and settle staff/vendor/project advances.'),
  ('finance.advances.approve','Approve advances','Approve or reject advance requests.'),
  ('staff.compensation.view','View teacher compensation','View teacher compensation calculations and settlements.'),
  ('staff.compensation.manage','Manage teacher compensation','Prepare compensation runs and settlements.'),
  ('staff.compensation.approve','Approve teacher compensation','Approve compensation runs and adjustments.')
on conflict(code) do update
set name=excluded.name, description=excluded.description;

insert into public.permissions(code,name,description)
values
  ('accounting.expense.manage','Manage expenses','Create and post controlled expense records.'),
  ('accounting.expense.approve','Approve expenses','Approve expense records before posting.'),
  ('accounting.reconcile','Reconcile financial records','Reconcile expenses and cash/bank statements.'),
  ('finance.payments.reconcile','Reconcile payments','Match posted payments to controlled financial statements.')
on conflict(code) do update
set name=excluded.name, description=excluded.description;

-- Bootstrap ADMIN retains recovery authority for every new permission.
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.system_roles r cross join public.permissions p
where r.code='ADMIN'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code in (
  'finance.advances.approve',
  'accounting.expense.manage',
  'accounting.reconcile',
  'finance.payments.reconcile',
  'staff.compensation.manage'
)
where r.code='ACCOUNTANT'
on conflict do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id
from public.system_roles r
join public.permissions p on p.code in (
  'accounting.expense.approve',
  'staff.compensation.approve'
)
where r.code='ACADEMIC_DIRECTOR'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Chart of accounts and cost centres
-- ---------------------------------------------------------------------------

create table public.finance_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  account_type text not null check(
    account_type in (
      'ASSET','LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE','EXPENSE'
    )
  ),
  account_subtype text not null,
  parent_id uuid references public.finance_accounts(id),
  is_control_account boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(organization_id,code)
);

create index finance_accounts_type_idx
on public.finance_accounts(organization_id,account_type,is_active);

create table public.finance_cost_centres (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  branch_id uuid references public.branches(id),
  program_id uuid references public.programs(id),
  batch_id uuid references public.batches(id),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(organization_id,code)
);

-- ---------------------------------------------------------------------------
-- Double-entry general ledger
-- ---------------------------------------------------------------------------

create sequence public.general_ledger_journal_no_seq;

create table public.general_ledger_journals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  journal_no text not null unique default (
    'JRN-'||lpad(nextval('public.general_ledger_journal_no_seq')::text,8,'0')
  ),
  journal_date date not null,
  journal_type text not null check(
    journal_type in(
      'INVOICE','INVOICE_CREDIT','PAYMENT','REFUND',
      'ADVANCE_PAYMENT','ADVANCE_SETTLEMENT','ADVANCE_REFUND',
      'EXPENSE','PAYABLE_SETTLEMENT',
      'COMPENSATION_RUN','COMPENSATION_SETTLEMENT',
      'MANUAL'
    )
  ),
  source_type text not null,
  source_id text not null,
  description text not null,
  status text not null default 'POSTED' check(status in('POSTED','VOIDED')),
  posted_by uuid not null references public.profiles(id),
  posted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(source_type,source_id)
);

create index general_ledger_journals_date_idx
on public.general_ledger_journals(organization_id,journal_date desc);

create table public.general_ledger_lines (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.general_ledger_journals(id),
  line_no integer not null,
  account_id uuid not null references public.finance_accounts(id),
  debit numeric(14,2) not null default 0 check(debit>=0),
  credit numeric(14,2) not null default 0 check(credit>=0),
  memo text,
  cost_centre_id uuid references public.finance_cost_centres(id),
  branch_id uuid references public.branches(id),
  program_id uuid references public.programs(id),
  batch_id uuid references public.batches(id),
  created_at timestamptz not null default now(),
  check((debit=0 and credit>0) or (credit=0 and debit>0)),
  unique(journal_id,line_no)
);

create index general_ledger_lines_account_idx
on public.general_ledger_lines(account_id,journal_id);

create or replace function public.assert_journal_balanced()
returns trigger
language plpgsql
as $$
declare
  v_journal uuid := coalesce(new.journal_id,old.journal_id);
  v_debit numeric;
  v_credit numeric;
begin
  select
    coalesce(sum(debit),0),
    coalesce(sum(credit),0)
  into v_debit,v_credit
  from public.general_ledger_lines
  where journal_id=v_journal;

  if v_debit<>v_credit then
    raise exception 'Journal % is not balanced. Debit %, credit %.',
      v_journal,v_debit,v_credit;
  end if;

  return coalesce(new,old);
end;
$$;

create constraint trigger journal_must_balance
after insert or update or delete on public.general_ledger_lines
deferrable initially deferred
for each row execute function public.assert_journal_balanced();

create or replace function public.finance_account_balance(
  p_account_id uuid,
  p_as_of date default current_date
)
returns numeric
language sql
stable
security definer
set search_path=public
as $$
  select case
    when a.account_type in('ASSET','EXPENSE') then
      coalesce(sum(l.debit-l.credit),0)
    when a.account_type in('LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE') then
      coalesce(sum(l.credit-l.debit),0)
    else 0
  end
  from public.finance_accounts a
  join public.general_ledger_lines l on l.account_id=a.id
  join public.general_ledger_journals j on j.id=l.journal_id
  where a.id=p_account_id
    and j.status='POSTED'
    and j.journal_date<=p_as_of
  group by a.id,a.account_type;
$$;

revoke all on function public.finance_account_balance(uuid,date)
from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Minimal canonical vendor identity used by payables/expenses/advances.
-- Procurement can extend this record later without changing accounting keys.
-- ---------------------------------------------------------------------------

create sequence public.vendor_no_seq;

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  vendor_no text not null unique default(
    'VEN-'||lpad(nextval('public.vendor_no_seq')::text,6,'0')
  ),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  mobile text,
  email text,
  address text,
  service_category text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,name)
);

create trigger vendors_set_updated_at
before update on public.vendors
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Account mappings: payment methods and fee charge types
-- ---------------------------------------------------------------------------

create table public.finance_payment_account_map (
  payment_method_id uuid primary key references public.payment_methods(id),
  account_id uuid not null references public.finance_accounts(id),
  created_at timestamptz not null default now()
);

create table public.finance_fee_revenue_map (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  charge_type text not null,
  account_id uuid not null references public.finance_accounts(id),
  created_at timestamptz not null default now(),
  unique(organization_id,charge_type)
);

-- ---------------------------------------------------------------------------
-- Payables
-- ---------------------------------------------------------------------------

create sequence public.finance_payable_no_seq;

create table public.finance_payables (
  id uuid primary key default gen_random_uuid(),
  payable_no text not null unique default(
    'PAY-'||lpad(nextval('public.finance_payable_no_seq')::text,6,'0')
  ),
  organization_id uuid not null references public.organizations(id),
  payable_type text not null check(
    payable_type in('TEACHER_COMPENSATION','VENDOR','STAFF_REIMBURSEMENT','OTHER')
  ),
  staff_id uuid references public.staff(id),
  vendor_id uuid references public.vendors(id),
  source_type text not null,
  source_id text not null,
  payable_account_id uuid not null references public.finance_accounts(id),
  original_amount numeric(14,2) not null check(original_amount>0),
  due_on date,
  status text not null default 'OPEN' check(
    status in('OPEN','PARTIALLY_SETTLED','SETTLED','VOIDED')
  ),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(source_type,source_id)
);

create index finance_payables_open_idx
on public.finance_payables(organization_id,status,due_on);

create table public.finance_payable_settlements (
  id uuid primary key default gen_random_uuid(),
  payable_id uuid not null references public.finance_payables(id),
  amount numeric(14,2) not null check(amount>0),
  payment_account_id uuid references public.finance_accounts(id),
  external_reference text,
  settled_by uuid not null references public.profiles(id),
  settled_at timestamptz not null default now(),
  reason text not null,
  unique(payable_id,id)
);

-- ---------------------------------------------------------------------------
-- Staff/vendor/project advances
-- ---------------------------------------------------------------------------

create sequence public.finance_advance_no_seq;

create table public.finance_advances (
  id uuid primary key default gen_random_uuid(),
  advance_no text not null unique default(
    'ADV-'||lpad(nextval('public.finance_advance_no_seq')::text,6,'0')
  ),
  organization_id uuid not null references public.organizations(id),
  beneficiary_type text not null check(
    beneficiary_type in('STAFF','VENDOR','PROJECT')
  ),
  staff_id uuid references public.staff(id),
  vendor_id uuid references public.vendors(id),
  project_reference text,
  purpose text not null,
  requested_amount numeric(14,2) not null check(requested_amount>0),
  approved_amount numeric(14,2),
  expected_settlement_date date,
  requested_by uuid not null references public.profiles(id),
  approval_id uuid unique references public.approval_requests(id),
  status text not null default 'REQUESTED' check(
    status in(
      'REQUESTED','APPROVED','PAID','PARTIALLY_SETTLED',
      'SETTLED','REFUNDED','OVERDUE','REJECTED'
    )
  ),
  created_at timestamptz not null default now(),
  check(
    (beneficiary_type='STAFF' and staff_id is not null and vendor_id is null)
    or
    (beneficiary_type='VENDOR' and vendor_id is not null and staff_id is null)
    or
    (beneficiary_type='PROJECT' and staff_id is null and vendor_id is null
      and nullif(btrim(project_reference),'') is not null)
  )
);

create index finance_advances_status_idx
on public.finance_advances(organization_id,status,expected_settlement_date);

create table public.finance_advance_movements (
  id uuid primary key default gen_random_uuid(),
  advance_id uuid not null references public.finance_advances(id),
  movement_type text not null check(
    movement_type in('PAYMENT','SETTLEMENT','REFUND')
  ),
  amount numeric(14,2) not null check(amount>0),
  source_type text,
  source_id text,
  payment_account_id uuid references public.finance_accounts(id),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  reason text not null,
  unique(source_type,source_id)
);

create or replace function public.advance_balance(p_advance_id uuid)
returns numeric
language sql
stable
security definer
set search_path=public
as $$
  select coalesce(sum(
    case movement_type
      when 'PAYMENT' then amount
      when 'SETTLEMENT' then -amount
      when 'REFUND' then -amount
    end
  ),0)
  from public.finance_advance_movements
  where advance_id=p_advance_id;
$$;

revoke all on function public.advance_balance(uuid)
from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Expense categories, expenses and reconciliation evidence
-- ---------------------------------------------------------------------------

create table public.finance_expense_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  expense_account_id uuid not null references public.finance_accounts(id),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(organization_id,code)
);

create sequence public.finance_expense_no_seq;

create table public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  expense_no text not null unique default(
    'EXP-'||lpad(nextval('public.finance_expense_no_seq')::text,6,'0')
  ),
  organization_id uuid not null references public.organizations(id),
  expense_date date not null,
  category_id uuid not null references public.finance_expense_categories(id),
  expense_account_id uuid not null references public.finance_accounts(id),
  payment_mode text not null check(payment_mode in('PAID_NOW','ON_ACCOUNT')),
  payment_account_id uuid references public.finance_accounts(id),
  payable_id uuid references public.finance_payables(id),
  vendor_id uuid references public.vendors(id),
  staff_id uuid references public.staff(id),
  amount numeric(14,2) not null check(amount>0),
  description text not null,
  receipt_reference text,
  status text not null default 'DRAFT' check(
    status in('DRAFT','PENDING_APPROVAL','APPROVED','REJECTED','POSTED','RECONCILED')
  ),
  approval_id uuid unique references public.approval_requests(id),
  submitted_by uuid not null references public.profiles(id),
  posted_by uuid references public.profiles(id),
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  check(
    (payment_mode='PAID_NOW' and payment_account_id is not null)
    or
    (payment_mode='ON_ACCOUNT' and payment_account_id is null)
  )
);

create index finance_expenses_status_idx
on public.finance_expenses(organization_id,status,expense_date desc);

create table public.finance_expense_reconciliations (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.finance_expenses(id),
  matched_amount numeric(14,2) not null check(matched_amount>0),
  statement_reference text not null,
  reconciled_by uuid not null references public.profiles(id),
  reconciled_at timestamptz not null default now(),
  note text not null,
  unique(expense_id)
);

create table public.finance_account_reconciliations (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.finance_accounts(id),
  statement_date date not null,
  statement_reference text not null,
  statement_balance numeric(14,2) not null,
  ledger_balance numeric(14,2) not null,
  difference numeric(14,2) not null,
  status text not null check(status in('OPEN','RECONCILED')),
  reconciled_by uuid references public.profiles(id),
  reconciled_at timestamptz,
  note text not null,
  unique(account_id,statement_date,statement_reference)
);

-- ---------------------------------------------------------------------------
-- Teacher referral and compensation engine
-- ---------------------------------------------------------------------------

create table public.teacher_referrals (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null unique references public.admission_cases(id),
  teacher_id uuid not null references public.staff(id),
  captured_by uuid not null references public.profiles(id),
  captured_at timestamptz not null default now(),
  reason text not null
);

create sequence public.teacher_compensation_run_no_seq;

create table public.teacher_compensation_runs (
  id uuid primary key default gen_random_uuid(),
  run_no text not null unique default(
    'CMP-'||lpad(nextval('public.teacher_compensation_run_no_seq')::text,6,'0')
  ),
  organization_id uuid not null references public.organizations(id),
  period_start date not null,
  period_end date not null,
  policy_version_id uuid not null references public.business_rule_versions(id),
  status text not null default 'DRAFT' check(
    status in('DRAFT','PENDING_APPROVAL','APPROVED','SETTLED','REJECTED')
  ),
  total_amount numeric(14,2) not null default 0 check(total_amount>=0),
  submitted_by uuid not null references public.profiles(id),
  approval_id uuid unique references public.approval_requests(id),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  check(period_end>=period_start)
);

create table public.teacher_compensation_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  teacher_id uuid not null references public.staff(id),
  admission_id uuid references public.admission_cases(id),
  event_type text not null check(
    event_type in('ACQUISITION_BONUS','RETENTION_3_MONTH','RETENTION_6_MONTH')
  ),
  event_period date not null,
  amount numeric(14,2) not null check(amount>=0),
  created_at timestamptz not null default now()
);

create table public.teacher_compensation_adjustments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.staff(id),
  amount numeric(14,2) not null check(amount>0),
  adjustment_type text not null check(adjustment_type in('GROWTH_BONUS','ADJUSTMENT')),
  effective_period date not null,
  reason text not null,
  approval_id uuid unique references public.approval_requests(id),
  status text not null default 'PENDING' check(status in('PENDING','APPROVED','REJECTED')),
  requested_by uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.teacher_compensation_lines (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.teacher_compensation_runs(id),
  teacher_id uuid not null references public.staff(id),
  line_type text not null check(
    line_type in(
      'TEACHING_REMUNERATION','ACQUISITION_BONUS',
      'RETENTION_3_MONTH','RETENTION_6_MONTH',
      'GROWTH_BONUS','ADJUSTMENT'
    )
  ),
  source_type text not null,
  source_id text not null,
  amount numeric(14,2) not null check(amount>0),
  calculation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(run_id,source_type,source_id)
);

create table public.teacher_compensation_settlements (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.teacher_compensation_runs(id),
  teacher_id uuid not null references public.staff(id),
  payable_id uuid not null unique references public.finance_payables(id),
  gross_amount numeric(14,2) not null check(gross_amount>0),
  advance_offset numeric(14,2) not null default 0 check(advance_offset>=0),
  cash_paid numeric(14,2) not null default 0 check(cash_paid>=0),
  payment_account_id uuid references public.finance_accounts(id),
  external_reference text,
  settled_by uuid not null references public.profiles(id),
  settled_at timestamptz not null default now(),
  reason text not null,
  unique(run_id,teacher_id),
  check(cash_paid=0 or payment_account_id is not null)
);

-- ---------------------------------------------------------------------------
-- Seed academy accounts
-- ---------------------------------------------------------------------------

do $$
declare
  org uuid;
begin
  select id into org from public.organizations where code='SOHOJ';
  insert into public.finance_accounts(
    organization_id,code,name,account_type,account_subtype,is_control_account
  )
  values
    (org,'1100','Cash','ASSET','CASH',true),
    (org,'1110','Bank','ASSET','BANK',true),
    (org,'1120','Mobile Banking','ASSET','MOBILE_BANK',true),
    (org,'1200','Student Receivables','ASSET','STUDENT_RECEIVABLE',true),
    (org,'1210','Staff Advances','ASSET','STAFF_ADVANCE',true),
    (org,'1220','Vendor Advances','ASSET','VENDOR_ADVANCE',true),
    (org,'2100','Teacher Compensation Payable','LIABILITY','TEACHER_PAYABLE',true),
    (org,'2110','Vendor Payable','LIABILITY','VENDOR_PAYABLE',true),
    (org,'2120','Staff Reimbursement Payable','LIABILITY','STAFF_PAYABLE',true),
    (org,'3000','Retained Earnings','EQUITY','RETAINED_EARNINGS',true),
    (org,'4000','Tuition Revenue','REVENUE','TUITION_REVENUE',true),
    (org,'4010','Admission Revenue','REVENUE','ADMISSION_REVENUE',true),
    (org,'4020','Other Fee Revenue','REVENUE','OTHER_FEE_REVENUE',true),
    (org,'4090','Discounts & Cancellation Credits','CONTRA_REVENUE','FEE_CREDITS',true),
    (org,'5000','Teaching Compensation Expense','EXPENSE','TEACHING_COMPENSATION',true),
    (org,'5100','General Operating Expense','EXPENSE','OPERATING_EXPENSE',true)
  on conflict(organization_id,code) do nothing;

  insert into public.finance_expense_categories(
    organization_id,code,name,expense_account_id
  )
  values
    (org,'GENERAL','General Operating Expense',
      (select id from public.finance_accounts where organization_id=org and code='5100')),
    (org,'TEACHING','Teaching Compensation',
      (select id from public.finance_accounts where organization_id=org and code='5000'))
  on conflict(organization_id,code) do nothing;

  insert into public.finance_fee_revenue_map(organization_id,charge_type,account_id)
  values
    (org,'TUITION',(select id from public.finance_accounts where organization_id=org and code='4000')),
    (org,'ADMISSION',(select id from public.finance_accounts where organization_id=org and code='4010')),
    (org,'EXAM',(select id from public.finance_accounts where organization_id=org and code='4020')),
    (org,'MATERIALS',(select id from public.finance_accounts where organization_id=org and code='4020')),
    (org,'BOOKS',(select id from public.finance_accounts where organization_id=org and code='4020')),
    (org,'OTHER',(select id from public.finance_accounts where organization_id=org and code='4020'))
  on conflict(organization_id,charge_type) do nothing;

  insert into public.finance_payment_account_map(payment_method_id,account_id)
  select pm.id,
    case pm.code
      when 'CASH' then (select id from public.finance_accounts where organization_id=org and code='1100')
      when 'BANK' then (select id from public.finance_accounts where organization_id=org and code='1110')
      when 'MOBILE_BANKING' then (select id from public.finance_accounts where organization_id=org and code='1120')
      else (select id from public.finance_accounts where organization_id=org and code='1100')
    end
  from public.payment_methods pm
  where pm.organization_id=org
  on conflict(payment_method_id) do nothing;
end
$$;

-- ---------------------------------------------------------------------------
-- Internal journal writer
-- ---------------------------------------------------------------------------

create or replace function public.finance_post_journal(
  p_organization_id uuid,
  p_journal_date date,
  p_journal_type text,
  p_source_type text,
  p_source_id text,
  p_description text,
  p_posted_by uuid,
  p_lines jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  journal_id uuid;
  line jsonb;
  n integer:=0;
  debit_total numeric:=0;
  credit_total numeric:=0;
  account_org uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines)<>'array'
     or jsonb_array_length(p_lines)<2 then
    raise exception 'A journal requires at least two lines.';
  end if;

  if exists(
    select 1 from public.general_ledger_journals
    where source_type=p_source_type and source_id=p_source_id
  ) then
    select id into journal_id
    from public.general_ledger_journals
    where source_type=p_source_type and source_id=p_source_id;
    return journal_id;
  end if;

  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
    if nullif(line->>'account_id','') is null then
      raise exception 'Journal line % has no account.',n;
    end if;

    select organization_id into account_org
    from public.finance_accounts
    where id=(line->>'account_id')::uuid and is_active;

    if account_org is null or account_org<>p_organization_id then
      raise exception 'Journal line % uses an invalid account.',n;
    end if;

    debit_total:=debit_total+coalesce((line->>'debit')::numeric,0);
    credit_total:=credit_total+coalesce((line->>'credit')::numeric,0);

    if coalesce((line->>'debit')::numeric,0)>0
       and coalesce((line->>'credit')::numeric,0)>0 then
      raise exception 'Journal line % cannot contain both debit and credit.',n;
    end if;

    if coalesce((line->>'debit')::numeric,0)<=0
       and coalesce((line->>'credit')::numeric,0)<=0 then
      raise exception 'Journal line % must contain a positive debit or credit.',n;
    end if;
  end loop;

  if round(debit_total,2)<>round(credit_total,2) then
    raise exception 'Journal must balance. Debit %, credit %.',debit_total,credit_total;
  end if;

  insert into public.general_ledger_journals(
    organization_id,journal_date,journal_type,source_type,source_id,
    description,posted_by
  )
  values(
    p_organization_id,p_journal_date,p_journal_type,p_source_type,p_source_id,
    btrim(p_description),p_posted_by
  )
  returning id into journal_id;

  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
  end loop;

  n:=0;
  for line in select value from jsonb_array_elements(p_lines)
  loop
    n:=n+1;
    insert into public.general_ledger_lines(
      journal_id,line_no,account_id,debit,credit,memo,
      cost_centre_id,branch_id,program_id,batch_id
    )
    values(
      journal_id,n,(line->>'account_id')::uuid,
      coalesce((line->>'debit')::numeric,0),
      coalesce((line->>'credit')::numeric,0),
      nullif(btrim(line->>'memo'),''),
      nullif(line->>'cost_centre_id','')::uuid,
      nullif(line->>'branch_id','')::uuid,
      nullif(line->>'program_id','')::uuid,
      nullif(line->>'batch_id','')::uuid
    );
  end loop;

  return journal_id;
end;
$$;

revoke all on function public.finance_post_journal(uuid,date,text,text,text,text,uuid,jsonb)
from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Ledger synchronization for existing and future student finance events
-- ---------------------------------------------------------------------------

create or replace function public.finance_sync_invoice(p_invoice_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  i public.admission_invoices;
  a public.admission_cases;
  org uuid;
  ar uuid;
  line public.admission_invoice_lines;
  revenue_account uuid;
  other_revenue uuid;
  lines jsonb:='[]'::jsonb;
begin
  select * into i from public.admission_invoices where id=p_invoice_id;
  if i.id is null then return null; end if;

  select * into a from public.admission_cases where id=i.admission_id;
  select organization_id into org from public.students where id=i.student_id;

  select id into ar from public.finance_accounts
  where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into other_revenue from public.finance_accounts
  where organization_id=org and account_subtype='OTHER_FEE_REVENUE' and is_active limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'account_id',coalesce(m.account_id,other_revenue),
      'debit',0,
      'credit',l.amount,
      'memo',l.name,
      'branch_id',b.branch_id,
      'program_id',b.program_id,
      'batch_id',b.id
    )
  ),'[]'::jsonb)
  into lines
  from public.admission_invoice_lines l
  left join public.finance_fee_revenue_map m
    on m.organization_id=org and m.charge_type=l.charge_type
  join public.admission_cases ac on ac.id=i.admission_id
  join public.batches b on b.id=ac.batch_id
  where l.invoice_id=i.id;

  lines:=jsonb_build_array(
    jsonb_build_object(
      'account_id',ar,
      'debit',i.total,
      'credit',0,
      'memo','Student receivable'
    )
  ) || lines;

  return public.finance_post_journal(
    org,i.issued_on,
    'INVOICE','ADMISSION_INVOICE',i.id::text,
    'Invoice '||i.invoice_no,
    i.posted_by,lines
  );
end;
$$;

create or replace function public.finance_sync_invoice_line_statement()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  r record;
begin
  for r in select distinct invoice_id from new_table
  loop
    perform public.finance_sync_invoice(r.invoice_id);
  end loop;
  return null;
end;
$$;

create trigger admission_invoice_lines_to_ledger
after insert on public.admission_invoice_lines
referencing new table as new_table
for each statement execute function public.finance_sync_invoice_line_statement();

create or replace function public.finance_sync_invoice_credit(p_credit_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  c public.invoice_credits;
  i public.admission_invoices;
  org uuid;
  ar uuid;
  contra uuid;
begin
  select * into c from public.invoice_credits where id=p_credit_id;
  select * into i from public.admission_invoices where id=c.invoice_id;
  select organization_id into org from public.students where id=i.student_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into contra from public.finance_accounts where organization_id=org and account_subtype='FEE_CREDITS' and is_active limit 1;

  return public.finance_post_journal(
    org,current_date,'INVOICE_CREDIT','INVOICE_CREDIT',c.id::text,
    initcap(lower(c.kind))||' credit for invoice '||i.invoice_no,
    (select posted_by from public.admission_cases a join public.admission_invoices x on x.admission_id=a.id where x.id=i.id limit 1),
    jsonb_build_array(
      jsonb_build_object('account_id',contra,'debit',c.amount,'credit',0,'memo',c.kind),
      jsonb_build_object('account_id',ar,'debit',0,'credit',c.amount,'memo','Reduce student receivable')
    )
  );
end;
$$;

create or replace function public.finance_sync_invoice_credit_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.finance_sync_invoice_credit(new.id);
  return new;
end;
$$;

create trigger invoice_credits_to_ledger
after insert on public.invoice_credits
for each row execute function public.finance_sync_invoice_credit_trigger();

revoke all on function public.finance_sync_invoice_credit_trigger()
from public,anon,authenticated;

create or replace function public.finance_sync_payment(p_payment_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  p public.admission_payments;
  pa public.admission_payment_allocations;
  i public.admission_invoices;
  org uuid;
  cash_account uuid;
  ar uuid;
begin
  select * into p from public.admission_payments where id=p_payment_id;
  select * into pa from public.admission_payment_allocations where payment_id=p.id;
  select * into i from public.admission_invoices where id=pa.invoice_id;
  select organization_id into org from public.students where id=p.student_id;
  select account_id into cash_account from public.finance_payment_account_map where payment_method_id=p.payment_method_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;

  return public.finance_post_journal(
    org,p.posted_at::date,'PAYMENT','ADMISSION_PAYMENT',p.id::text,
    'Payment '||p.receipt_no,p.posted_by,
    jsonb_build_array(
      jsonb_build_object('account_id',cash_account,'debit',p.amount,'credit',0,'memo',p.receipt_no),
      jsonb_build_object('account_id',ar,'debit',0,'credit',p.amount,'memo','Reduce student receivable')
    )
  );
end;
$$;

create or replace function public.finance_sync_payment_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.finance_sync_payment(new.payment_id);
  return new;
end;
$$;

create trigger admission_payment_allocations_to_ledger
after insert on public.admission_payment_allocations
for each row execute function public.finance_sync_payment_trigger();

revoke all on function public.finance_sync_payment_trigger()
from public,anon,authenticated;

create or replace function public.finance_sync_refund(p_payout_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  rp public.refund_payouts;
  ra public.refund_authorizations;
  i public.admission_invoices;
  org uuid;
  cash_account uuid;
  ar uuid;
begin
  select * into rp from public.refund_payouts where id=p_payout_id;
  select * into ra from public.refund_authorizations where id=rp.authorization_id;
  select * into i from public.admission_invoices where id=ra.invoice_id;
  select organization_id into org from public.students where id=i.student_id;
  select account_id into cash_account from public.finance_payment_account_map where payment_method_id=rp.payment_method_id;
  select id into ar from public.finance_accounts where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;

  return public.finance_post_journal(
    org,rp.posted_at::date,'REFUND','REFUND_PAYOUT',rp.id::text,
    'Refund '||rp.refund_no,rp.posted_by,
    jsonb_build_array(
      jsonb_build_object('account_id',ar,'debit',ra.amount,'credit',0,'memo','Reinstate student receivable'),
      jsonb_build_object('account_id',cash_account,'debit',0,'credit',ra.amount,'memo',rp.refund_no)
    )
  );
end;
$$;

create or replace function public.finance_sync_refund_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.finance_sync_refund(new.id);
  return new;
end;
$$;

create trigger refund_payouts_to_ledger
after insert on public.refund_payouts
for each row execute function public.finance_sync_refund_trigger();

revoke all on function public.finance_sync_refund_trigger()
from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Compensation calculation helpers
-- ---------------------------------------------------------------------------

create or replace function public.finance_net_collected_tuition(
  p_from date,
  p_to date
)
returns table(
  admission_id uuid,
  batch_id uuid,
  billing_period date,
  tuition_collected numeric
)
language sql
stable
security definer
set search_path=public
as $$
with invoice_values as (
  select
    i.id,
    i.admission_id,
    a.batch_id,
    i.billing_period,
    greatest(
      coalesce(sum(l.amount) filter(where l.charge_type='TUITION'),0)
      - coalesce((select sum(c.amount) from public.invoice_credits c where c.invoice_id=i.id),0),
      0
    ) as tuition_net,
    greatest(
      i.total - coalesce((select sum(c.amount) from public.invoice_credits c where c.invoice_id=i.id),0),
      0
    ) as net_invoice
  from public.admission_invoices i
  join public.admission_cases a on a.id=i.admission_id
  left join public.admission_invoice_lines l on l.invoice_id=i.id
  where i.billing_period between p_from and p_to
  group by i.id,a.batch_id,i.total
),
payments as (
  select
    iv.admission_id,
    iv.batch_id,
    iv.billing_period,
    greatest(
      pa.amount
      - coalesce((
          select sum(ra.amount)
          from public.refund_authorizations ra
          join public.refund_payouts rp on rp.authorization_id=ra.id
          where ra.payment_id=p.id
            and ra.invoice_id=pa.invoice_id
        ),0),
      0
    ) as effective_payment,
    iv.tuition_net,
    iv.net_invoice
  from invoice_values iv
  join public.admission_payment_allocations pa on pa.invoice_id=iv.id
  join public.admission_payments p on p.id=pa.payment_id
)
select
  admission_id,
  batch_id,
  billing_period,
  round(sum(case when net_invoice>0
    then least(effective_payment,effective_payment*tuition_net/net_invoice)
    else 0 end),2)
from payments
group by admission_id,batch_id,billing_period;
$$;

revoke all on function public.finance_net_collected_tuition(date,date)
from public,anon,authenticated;

create or replace function public.teacher_compensation_preview(
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  policy public.business_rule_versions;
  rows jsonb:='[]'::jsonb;
  teacher_row record;
  batch_row record;
  event_amount numeric;
  pool_percent numeric;
  acquisition_percent numeric;
  retention3_percent numeric;
  retention6_percent numeric;
  first_period date;
  first_collected numeric;
  month3 date;
  month6 date;
  month_paid boolean;
  continuous3 boolean;
  continuous6 boolean;
begin
  if actor is null or not public.has_permission('staff.compensation.view') then
    raise exception 'Compensation access denied.';
  end if;
  if p_from is null or p_to is null or p_to<p_from then
    raise exception 'Choose a valid compensation period.';
  end if;

  select * into policy
  from public.business_rule_versions
  where domain='teacher_compensation'
    and rule_key='default_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if policy.id is null
     or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
    raise exception 'A valid teacher compensation policy is required.';
  end if;

  pool_percent:=(policy.payload->>'teaching_pool_percent')::numeric;
  acquisition_percent:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  retention3_percent:=(policy.payload->>'retention_3_month_percent')::numeric;
  retention6_percent:=(policy.payload->>'retention_6_month_percent')::numeric;

  -- Teaching pool is calculated per batch from Net Collected Tuition and
  -- allocated by approved attendance/session workload within that batch.
  for batch_row in
    with batch_revenue as (
      select batch_id,sum(tuition_collected) net_collected
      from public.finance_net_collected_tuition(p_from,p_to)
      group by batch_id
    ),
    session_weights as (
      select
        cs.batch_id,
        cs.teacher_id,
        count(*) filter(
          where exists(
            select 1 from public.attendance_submissions aa
            where aa.id=(
              select z.id from public.attendance_submissions z
              where z.session_id=cs.id
              order by z.revision desc limit 1
            )
            and aa.status='APPROVED'
          )
        )::numeric as session_count
      from public.class_sessions cs
      where cs.session_date between p_from and p_to
        and cs.status='SCHEDULED'
      group by cs.batch_id,cs.teacher_id
    )
    select
      r.batch_id,
      r.net_collected,
      r.net_collected*pool_percent/100 as pool_amount,
      w.teacher_id,
      w.session_count,
      sum(w.session_count) over(partition by w.batch_id) total_sessions
    from batch_revenue r
    join session_weights w on w.batch_id=r.batch_id
    where r.net_collected>0 and w.session_count>0
  loop
    event_amount:=round(batch_row.pool_amount*batch_row.session_count/nullif(batch_row.total_sessions,0),2);
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',batch_row.teacher_id,
        'lineType','TEACHING_REMUNERATION',
        'amount',event_amount,
        'sourceType','BATCH_PERIOD',
        'sourceId',batch_row.batch_id::text||':'||p_from::text||':'||p_to::text,
        'calculation',jsonb_build_object(
          'batchId',batch_row.batch_id,
          'netCollectedTuition',batch_row.net_collected,
          'poolPercent',pool_percent,
          'poolAmount',batch_row.pool_amount,
          'approvedSessions',batch_row.session_count,
          'batchApprovedSessions',batch_row.total_sessions
        )
      )
    );
  end loop;

  -- Acquisition/retention bonuses require a structured teacher referral.
  for teacher_row in
    select
      tr.teacher_id,
      tr.admission_id,
      min(i.billing_period) first_billing_period
    from public.teacher_referrals tr
    join public.admission_cases a on a.id=tr.admission_id
    join public.admission_invoices i on i.admission_id=a.id
    group by tr.teacher_id,tr.admission_id
  loop
    first_period:=teacher_row.first_billing_period;

    select coalesce(sum(n.tuition_collected),0)
    into first_collected
    from public.finance_net_collected_tuition(first_period,first_period) n
    where n.admission_id=teacher_row.admission_id;

    if first_collected>0 then
      rows:=rows||jsonb_build_array(
        jsonb_build_object(
          'teacherId',teacher_row.teacher_id,
          'admissionId',teacher_row.admission_id,
          'lineType','ACQUISITION_BONUS',
          'amount',round(first_collected*acquisition_percent/100,2),
          'sourceType','ACQUISITION',
          'sourceId',teacher_row.admission_id::text,
          'calculation',jsonb_build_object(
            'firstMonthNetCollectedTuition',first_collected,
            'bonusPercent',acquisition_percent
          )
        )
      );
    end if;

    month3:=(first_period+interval '2 months')::date;
    month6:=(first_period+interval '5 months')::date;

    select bool_and(tuition_collected>0)
    into continuous3
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,m.month_start) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month3,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if continuous3 is true then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month3,month3) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_3_MONTH',
            'amount',round(event_amount*retention3_percent/100,2),
            'sourceType','RETENTION_3',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month3,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention3_percent
            )
          )
        );
      end if;
    end if;

    select bool_and(tuition_collected>0)
    into continuous6
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,m.month_start) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month6,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if continuous6 is true then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month6,month6) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_6_MONTH',
            'amount',round(event_amount*retention6_percent/100,2),
            'sourceType','RETENTION_6',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month6,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention6_percent
            )
          )
        );
      end if;
    end if;
  end loop;

  for teacher_row in
    select teacher_id,adjustment_type,id,amount
    from public.teacher_compensation_adjustments
    where status='APPROVED'
      and effective_period between p_from and p_to
  loop
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',teacher_row.teacher_id,
        'lineType',case when teacher_row.adjustment_type='GROWTH_BONUS'
          then 'GROWTH_BONUS' else 'ADJUSTMENT' end,
        'amount',teacher_row.amount,
        'sourceType','ADJUSTMENT',
        'sourceId',teacher_row.id::text,
        'calculation',jsonb_build_object(
          'adjustmentType',teacher_row.adjustment_type
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'periodStart',p_from,
    'periodEnd',p_to,
    'policyVersion',policy.version,
    'rows',rows,
    'total',coalesce((select sum((x->>'amount')::numeric) from jsonb_array_elements(rows) x),0)
  );
end;
$$;

revoke all on function public.teacher_compensation_preview(date,date)
from public,anon;
grant execute on function public.teacher_compensation_preview(date,date)
to authenticated;

-- ---------------------------------------------------------------------------
-- Compensation and accounting command
-- ---------------------------------------------------------------------------

create or replace function public.finance_accounting_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  key public.admission_command_keys;
  result jsonb;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  org uuid;
  account public.finance_accounts;
  journal_id uuid;
  approval public.approval_requests;
  advance public.finance_advances;
  adv_balance numeric;
  payable public.finance_payables;
  expense public.finance_expenses;
  vendor public.vendors;
  amount numeric;
  expense_account uuid;
  payment_account uuid;
  payment_mode text;
  category public.finance_expense_categories;
  compensation public.teacher_compensation_runs;
  policy public.business_rule_versions;
  preview jsonb;
  line jsonb;
  teacher_id uuid;
  settlement public.teacher_compensation_settlements;
  cash_paid numeric;
  advance_offset numeric;
  advance_row record;
  settlement_id uuid;
  decision text;
  source_type text;
  permission text;
begin
  if actor is null then raise exception 'Sign in to continue.'; end if;
  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason of at least five characters are required.';
  end if;

  permission := null;
  -- Action permission is assigned below because compensation/expense/advance
  -- workflows have different authorization boundaries.
  if action in('CREATE_ACCOUNT','POST_JOURNAL') then permission:='accounting.manage';
  elsif action in('CREATE_VENDOR','REQUEST_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('DECIDE_ADVANCE') then permission:='finance.advances.approve';
  elsif action in('PAY_ADVANCE','REFUND_ADVANCE','SETTLE_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('CREATE_EXPENSE','SUBMIT_EXPENSE') then permission:='accounting.expense.manage';
  elsif action='DECIDE_EXPENSE' then permission:='accounting.expense.approve';
  elsif action='POST_EXPENSE' then permission:='accounting.expense.manage';
  elsif action='RECONCILE_EXPENSE' or action='RECONCILE_ACCOUNT' then permission:='accounting.reconcile';
  elsif action='REQUEST_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMPENSATION' then permission:='staff.compensation.approve';
  elsif action='SETTLE_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='REQUEST_COMP_ADJUSTMENT' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMP_ADJUSTMENT' then permission:='staff.compensation.approve';
  elsif action='SET_TEACHER_REFERRAL' then permission:='admissions.create';
  else permission:=null;
  end if;

  if permission is null or not public.has_permission(permission) then
    raise exception 'Permission denied for this accounting action.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,7));
  select * into key from public.admission_command_keys where request_id=req;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select id into org from public.organizations where code='SOHOJ' and is_active limit 1;

  if action='CREATE_ACCOUNT' then
    if length(btrim(coalesce(p_input->>'code','')))<2
       or length(btrim(coalesce(p_input->>'name','')))<2
       or p_input->>'account_type' not in('ASSET','LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE','EXPENSE')
       or length(btrim(coalesce(p_input->>'account_subtype','')))<2 then
      raise exception 'Enter valid account code, name, type and category.';
    end if;

    insert into public.finance_accounts(
      organization_id,code,name,account_type,account_subtype,parent_id,
      is_control_account,created_by
    )
    values(
      org,btrim(p_input->>'code'),btrim(p_input->>'name'),
      p_input->>'account_type',btrim(p_input->>'account_subtype'),
      nullif(p_input->>'parent_id','')::uuid,
      coalesce((p_input->>'is_control_account')::boolean,false),actor
    )
    returning * into account;

    result:=jsonb_build_object('id',account.id,'message','Financial account created.');

  elsif action='POST_JOURNAL' then
    if not public.has_permission('accounting.manage') then raise exception 'Accounting management permission required.'; end if;
    perform public.finance_post_journal(
      org,
      (p_input->>'journal_date')::date,
      'MANUAL',
      'MANUAL_JOURNAL',
      req::text,
      btrim(p_input->>'description'),
      actor,
      p_input->'lines'
    );
    result:=jsonb_build_object('id',req,'message','Balanced journal posted.');

  elsif action='CREATE_VENDOR' then
    if length(btrim(coalesce(p_input->>'name','')))<2 then
      raise exception 'Vendor name is required.';
    end if;
    insert into public.vendors(
      organization_id,name,mobile,email,address,service_category,created_by
    )
    values(
      org,btrim(p_input->>'name'),
      nullif(btrim(p_input->>'mobile'),''),
      nullif(lower(btrim(p_input->>'email')),''),
      nullif(btrim(p_input->>'address'),''),
      nullif(btrim(p_input->>'service_category'),''),
      actor
    )
    returning * into vendor;
    result:=jsonb_build_object('id',vendor.id,'vendorNo',vendor.vendor_no,'message','Vendor created.');

  elsif action='SET_TEACHER_REFERRAL' then
    select * into compensation from public.teacher_compensation_runs where false;
    if not exists(
      select 1 from public.admission_cases
      where id=(p_input->>'admission_id')::uuid and status in('DRAFT','READY')
    ) then
      raise exception 'Teacher referral can only be captured before admission acceptance.';
    end if;
    if not exists(
      select 1 from public.staff s
      where s.id=(p_input->>'teacher_id')::uuid
        and s.status='ACTIVE'
        and exists(
          select 1
          from public.staff_role_assignments sra
          join public.staff_roles sr on sr.id=sra.staff_role_id
          where sra.staff_id=s.id and sr.is_teaching_role
        )
    ) then raise exception 'Choose an active teacher.';
    end if;

    insert into public.teacher_referrals(admission_id,teacher_id,captured_by,reason)
    values((p_input->>'admission_id')::uuid,(p_input->>'teacher_id')::uuid,actor,reason)
    on conflict(admission_id) do update
      set teacher_id=excluded.teacher_id,captured_by=excluded.captured_by,
          captured_at=now(),reason=excluded.reason;

    result:=jsonb_build_object('id',(p_input->>'admission_id'),'message','Teacher referral recorded before acceptance.');

  elsif action='REQUEST_ADVANCE' then
    if p_input->>'beneficiary_type' not in('STAFF','VENDOR','PROJECT') then
      raise exception 'Choose staff, vendor or project as the advance beneficiary.';
    end if;
    amount:=(p_input->>'requested_amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Advance amount must be positive.'; end if;

    insert into public.finance_advances(
      organization_id,beneficiary_type,staff_id,vendor_id,project_reference,
      purpose,requested_amount,expected_settlement_date,requested_by,status
    )
    values(
      org,p_input->>'beneficiary_type',
      nullif(p_input->>'staff_id','')::uuid,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(btrim(p_input->>'project_reference'),''),
      btrim(p_input->>'purpose'),amount,
      nullif(p_input->>'expected_settlement_date','')::date,
      actor,'REQUESTED'
    )
    returning * into advance;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values(
      'ADVANCE','FINANCE_ADVANCE',advance.id::text,action,p_input,reason,actor,req
    )
    returning id into approval;

    update public.finance_advances
    set approval_id=approval.id
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance submitted for independent approval.');

  elsif action='DECIDE_ADVANCE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='ADVANCE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then
      raise exception 'Pending advance approval not found.';
    end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the advance.'; end if;

    select * into advance from public.finance_advances where id=approval.entity_id::uuid for update;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      update public.finance_advances
      set approved_amount=(approval.payload_snapshot->>'requested_amount')::numeric,status='APPROVED'
      where id=advance.id;
    else
      update public.finance_advances set status='REJECTED' where id=advance.id;
    end if;

    result:=jsonb_build_object('id',advance.id,'message','Advance request '||lower(decision)||'.');

  elsif action='PAY_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null or advance.status not in('APPROVED','PAID') then raise exception 'Only approved advances can be paid.'; end if;
    if amount is null or amount<=0 then raise exception 'Advance payment must be positive.'; end if;
    if amount>advance.approved_amount-public.advance_paid(advance.id) then raise exception 'Payment exceeds approved advance balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;

    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(
      advance.id,'PAYMENT',amount,'ADVANCE_PAYMENT',req::text,payment_account,actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_PAYMENT','ADVANCE_PAYMENT',req::text,
      'Advance payment '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='STAFF'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
            when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',amount,'credit',0
        ),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    if public.advance_paid(advance.id)>=advance.approved_amount then
      update public.finance_advances set status='PAID' where id=advance.id;
    end if;
    result:=jsonb_build_object('id',advance.id,'message','Advance payment posted.');

  elsif action='SETTLE_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null then raise exception 'Advance not found.'; end if;
    adv_balance:=public.advance_balance(advance.id);
    if advance.id is null or adv_balance<=0 then raise exception 'Advance has no unsettled balance.'; end if;
    if amount is null or amount<=0 or amount>adv_balance then raise exception 'Settlement exceeds the current advance balance.'; end if;

    if advance.beneficiary_type='VENDOR' and p_input->>'settlement_type' not in('VENDOR_BILL','EXPENSE') then
      raise exception 'A vendor advance can only be settled against a vendor bill or expense.';
    end if;
    if advance.beneficiary_type='STAFF' and p_input->>'settlement_type'='VENDOR_BILL' then
      raise exception 'A staff advance cannot be settled against a vendor bill.';
    end if;

    if p_input->>'settlement_type'='EXPENSE' then
      expense_account:=(p_input->>'expense_account_id')::uuid;
      if not exists(select 1 from public.finance_accounts where id=expense_account and account_type='EXPENSE' and organization_id=org) then
        raise exception 'Choose an active expense account.';
      end if;
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',req::text,
        'Settle advance '||advance.advance_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense_account,'debit',amount,'credit',0),
          jsonb_build_object(
            'account_id',
            case when advance.beneficiary_type='VENDOR'
              then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
              else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
            end,
            'debit',0,'credit',amount
          )
        )
      );
    elsif p_input->>'settlement_type'='VENDOR_BILL' then
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',req::text,
        'Apply advance to vendor payable '||advance.advance_no,actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1),
            'debit',amount,'credit',0
          ),
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1),
            'debit',0,'credit',amount
          )
        )
      );
    elsif p_input->>'settlement_type'='TEACHER_COMPENSATION' then
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',req::text,
        'Apply teacher advance to compensation payable',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=org and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',amount,'credit',0
          ),
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1),
            'debit',0,'credit',amount
          )
        )
      );
    else
      raise exception 'Unsupported advance settlement type.';
    end if;

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,created_by,reason
    )
    values(advance.id,'SETTLEMENT',amount,'ADVANCE_SETTLEMENT',req::text,actor,reason);

    update public.finance_advances
    set status=case
      when public.advance_balance(id)<=0 then 'SETTLED'
      else 'PARTIALLY_SETTLED'
    end
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance settlement posted.');

  elsif action='REFUND_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    adv_balance:=public.advance_balance(advance.id);
    if advance.id is null or adv_balance<=0 or amount is null or amount<=0 or amount>adv_balance then
      raise exception 'Refund exceeds the unsettled advance balance.';
    end if;
    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_REFUND','ADVANCE_REFUND',req::text,
      'Advance refund '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',payment_account,'debit',amount,'credit',0
        ),
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',0,'credit',amount
        )
      )
    );

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(advance.id,'REFUND',amount,'ADVANCE_REFUND',req::text,payment_account,actor,reason);

    update public.finance_advances
    set status=case when public.advance_balance(id)<=0 then 'REFUNDED' else status end
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance refund recorded.');

  elsif action='CREATE_EXPENSE' then
    amount:=(p_input->>'amount')::numeric;
    payment_mode:=p_input->>'payment_mode';
    if amount is null or amount<=0 or payment_mode not in('PAID_NOW','ON_ACCOUNT') then
      raise exception 'Enter a valid expense amount and payment mode.';
    end if;
    select * into category from public.finance_expense_categories
    where id=(p_input->>'category_id')::uuid and organization_id=org and is_active;
    if category.id is null then raise exception 'Choose an active expense category.'; end if;

    insert into public.finance_expenses(
      organization_id,expense_date,category_id,expense_account_id,payment_mode,
      payment_account_id,vendor_id,staff_id,amount,description,receipt_reference,
      status,submitted_by
    )
    values(
      org,(p_input->>'expense_date')::date,category.id,category.expense_account_id,payment_mode,
      case when payment_mode='PAID_NOW' then nullif(p_input->>'payment_account_id','')::uuid else null end,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(p_input->>'staff_id','')::uuid,
      amount,btrim(p_input->>'description'),
      nullif(btrim(p_input->>'receipt_reference'),''),
      'PENDING_APPROVAL',actor
    )
    returning * into expense;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('EXPENSE','FINANCE_EXPENSE',expense.id::text,'CREATE_EXPENSE',p_input,reason,actor,req)
    returning id into approval;

    update public.finance_expenses set approval_id=approval.id where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense submitted for independent approval.');

  elsif action='DECIDE_EXPENSE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='EXPENSE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending expense approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the expense.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.finance_expenses
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Expense '||lower(decision)||'.');

  elsif action='POST_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    if expense.id is null or expense.status<>'APPROVED' then raise exception 'Only approved expenses can be posted.'; end if;
    if expense.payment_mode='PAID_NOW'
       and not exists(select 1 from public.finance_accounts where id=expense.payment_account_id and organization_id=org and account_subtype in('CASH','BANK','MOBILE_BANK') and is_active) then
      raise exception 'Choose an active cash or bank account for this expense.';
    end if;
    if expense.payment_mode='ON_ACCOUNT' and expense.vendor_id is null and expense.staff_id is null then
      raise exception 'An on-account expense must identify a vendor or staff claimant.';
    end if;

    if expense.payment_mode='PAID_NOW' then
      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',expense.payment_account_id,'debit',0,'credit',expense.amount)
        )
      );
    else
      insert into public.finance_payables(
        organization_id,payable_type,vendor_id,staff_id,source_type,source_id,
        payable_account_id,original_amount,due_on,created_by
      )
      values(
        org,
        case when expense.vendor_id is not null then 'VENDOR'
             when expense.staff_id is not null then 'STAFF_REIMBURSEMENT'
             else 'OTHER' end,
        expense.vendor_id,expense.staff_id,'EXPENSE',expense.id::text,
        case when expense.vendor_id is not null
          then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1)
          else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYABLE' limit 1)
        end,
        expense.amount,
        expense.expense_date + 30,
        actor
      )
      returning * into payable;

      update public.finance_expenses set payable_id=payable.id where id=expense.id;

      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense payable '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',expense.amount)
        )
      );
    end if;

    update public.finance_expenses
    set status='POSTED',posted_by=actor,posted_at=now()
    where id=expense.id;

    result:=jsonb_build_object('id',expense.id,'message','Expense posted to the ledger.');

  elsif action='SETTLE_PAYABLE' then
    select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if payable.id is null or payable.status not in('OPEN','PARTIALLY_SETTLED') then raise exception 'Payable is not open.'; end if;
    if amount is null or amount<=0 or amount > payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0) then raise exception 'Settlement exceeds payable balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_payable_settlements(
      payable_id,amount,payment_account_id,external_reference,settled_by,reason
    )
    values(
      payable.id,amount,payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'PAYABLE_SETTLEMENT','PAYABLE_SETTLEMENT',req::text,
      'Payable settlement '||payable.payable_no,actor,
      jsonb_build_array(
        jsonb_build_object('account_id',payable.payable_account_id,'debit',amount,'credit',0),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
        then 'SETTLED'
      else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    result:=jsonb_build_object('id',payable.id,'message','Payable settlement posted.');

  elsif action='RECONCILE_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    amount:=(p_input->>'matched_amount')::numeric;
    if expense.id is null or expense.status<>'POSTED' then raise exception 'Post the expense before reconciliation.'; end if;
    if amount is null or amount<>expense.amount then raise exception 'Reconciled amount must equal the posted expense amount.'; end if;

    insert into public.finance_expense_reconciliations(
      expense_id,matched_amount,statement_reference,reconciled_by,note
    )
    values(
      expense.id,amount,btrim(p_input->>'statement_reference'),actor,reason
    )
    on conflict(expense_id) do nothing;

    if not found then raise exception 'Expense is already reconciled.'; end if;
    update public.finance_expenses set status='RECONCILED' where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense reconciled to the statement reference.');

  elsif action='RECONCILE_ACCOUNT' then
    select * into account from public.finance_accounts
    where id=(p_input->>'account_id')::uuid
      and organization_id=org and is_active;
    if account.id is null then raise exception 'Choose an active account.'; end if;

    select public.finance_account_balance(account.id,(p_input->>'statement_date')::date)
    into amount;

    if amount is null then amount:=0; end if;
    insert into public.finance_account_reconciliations(
      account_id,statement_date,statement_reference,statement_balance,
      ledger_balance,difference,status,note,reconciled_by,reconciled_at
    )
    values(
      account.id,(p_input->>'statement_date')::date,
      btrim(p_input->>'statement_reference'),
      (p_input->>'statement_balance')::numeric,
      amount,
      round((p_input->>'statement_balance')::numeric-amount,2),
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then 'RECONCILED' else 'OPEN' end,
      reason,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then actor else null end,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then now() else null end
    )
    on conflict(account_id,statement_date,statement_reference) do update
      set statement_balance=excluded.statement_balance,
          ledger_balance=excluded.ledger_balance,
          difference=excluded.difference,
          status=excluded.status,
          reconciled_by=excluded.reconciled_by,
          reconciled_at=excluded.reconciled_at,
          note=excluded.note;

    result:=jsonb_build_object('id',req,'message',
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0
        then 'Account reconciled.'
        else 'Reconciliation saved as open; investigate the difference before closing it.' end);

  elsif action='REQUEST_COMPENSATION' then
    preview:=public.teacher_compensation_preview(
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date
    );
    if jsonb_array_length(preview->'rows')=0 then
      raise exception 'No eligible compensation lines for this period.';
    end if;

    select * into policy
    from public.business_rule_versions
    where domain='teacher_compensation'
      and rule_key='default_policy'
      and status='ACTIVE'
    order by version desc
    limit 1;

    insert into public.teacher_compensation_runs(
      organization_id,period_start,period_end,policy_version_id,
      status,total_amount,submitted_by
    )
    values(
      org,(p_input->>'period_start')::date,(p_input->>'period_end')::date,
      policy.id,'PENDING_APPROVAL',(preview->>'total')::numeric,actor
    )
    returning * into compensation;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION','TEACHER_COMPENSATION_RUN',compensation.id::text,
      action,preview,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_runs
    set approval_id=approval.id
    where id=compensation.id;

    for line in select value from jsonb_array_elements(preview->'rows')
    loop
      insert into public.teacher_compensation_lines(
        run_id,teacher_id,admission_id,line_type,source_type,source_id,amount,calculation
      )
      values(
        compensation.id,(line->>'teacherId')::uuid,
        nullif(line->>'admissionId','')::uuid,
        line->>'lineType',line->>'sourceType',line->>'sourceId',
        (line->>'amount')::numeric,coalesce(line->'calculation','{}'::jsonb)
      )
      on conflict(run_id,source_type,source_id) do nothing;
    end loop;

    result:=jsonb_build_object(
      'id',compensation.id,
      'runNo',compensation.run_no,
      'message','Teacher compensation run prepared and submitted for independent approval.',
      'total',compensation.total_amount
    );

  elsif action='DECIDE_COMPENSATION' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide compensation.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    select * into compensation from public.teacher_compensation_runs
    where id=approval.entity_id::uuid for update;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      -- Freeze earnings into teacher-specific payables only after independent approval.
      for teacher_id in
        select distinct teacher_id from public.teacher_compensation_lines
        where run_id=compensation.id
      loop
        select coalesce(sum(amount),0) into amount
        from public.teacher_compensation_lines
        where run_id=compensation.id and teacher_id=teacher_id;

        if amount>0 then
          insert into public.finance_payables(
            organization_id,payable_type,staff_id,source_type,source_id,
            payable_account_id,original_amount,due_on,created_by
          )
          values(
            compensation.organization_id,'TEACHER_COMPENSATION',teacher_id,
            'COMPENSATION_RUN',compensation.id::text||':'||teacher_id::text,
            (select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            amount,compensation.period_end,actor
          )
          on conflict(source_type,source_id) do nothing;
        end if;
      end loop;

      perform public.finance_post_journal(
        compensation.organization_id,compensation.period_end,
        'COMPENSATION_RUN','COMPENSATION_RUN',compensation.id::text,
        'Teacher compensation run '||compensation.run_no,actor,
        (
          select jsonb_build_array(
            jsonb_build_object(
              'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHING_COMPENSATION' limit 1),
              'debit',compensation.total_amount,'credit',0,
              'memo','Teaching compensation expense'
            )
          ) ||
          coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
                'debit',0,'credit',sum(l.amount),
                'memo','Payable for teacher '||l.teacher_id::text
              )
            )
            from public.teacher_compensation_lines l
            where l.run_id=compensation.id
            group by l.teacher_id
          ),'[]'::jsonb)
        )
      );
      update public.teacher_compensation_runs
      set status='APPROVED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    else
      update public.teacher_compensation_runs
      set status='REJECTED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',compensation.id,'message','Compensation run '||lower(decision)||'.');

  elsif action='SETTLE_COMPENSATION' then
    select * into compensation from public.teacher_compensation_runs
    where id=(p_input->>'run_id')::uuid and status='APPROVED' for update;
    if compensation.id is null then raise exception 'Only an approved compensation run can be settled.'; end if;

    teacher_id:=(p_input->>'teacher_id')::uuid;
    select * into payable from public.finance_payables
    where source_type='COMPENSATION_RUN'
      and source_id=compensation.id::text||':'||teacher_id::text
      and staff_id=teacher_id
    for update;
    if payable.id is null then raise exception 'Teacher payable not found.'; end if;

    amount:=payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0);
    if amount<=0 then raise exception 'Teacher payable is already settled.'; end if;

    advance_offset:=coalesce((p_input->>'advance_offset')::numeric,0);
    if advance_offset<0 or advance_offset>amount then raise exception 'Advance offset is outside the payable balance.'; end if;

    if advance_offset>0 then
      select * into advance_row
      from (
        select adv.*,public.advance_balance(adv.id) balance
        from public.finance_advances adv
        where adv.staff_id=teacher_id
          and adv.beneficiary_type='STAFF'
          and public.advance_balance(adv.id)>0
          and adv.status in('PAID','PARTIALLY_SETTLED','OVERDUE')
        order by adv.expected_settlement_date nulls last,adv.created_at
      ) q
      limit 1;

      if advance_row.id is null or advance_row.balance<advance_offset then
        raise exception 'Requested advance offset exceeds available teacher advance balance.';
      end if;
    end if;

    cash_paid:=amount-advance_offset;
    if cash_paid>0 then
      select id into payment_account
      from public.finance_accounts
      where id=(p_input->>'payment_account_id')::uuid
        and organization_id=compensation.organization_id
        and account_subtype in('CASH','BANK','MOBILE_BANK')
        and is_active;
      if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;
    end if;

    insert into public.teacher_compensation_settlements(
      run_id,teacher_id,payable_id,gross_amount,advance_offset,cash_paid,
      payment_account_id,external_reference,settled_by,reason
    )
    values(
      compensation.id,teacher_id,payable.id,amount,advance_offset,cash_paid,
      payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    )
    returning id into settlement;

    if advance_offset>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_SETTLEMENT',settlement.id::text,
        'Teacher compensation advance offset',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',advance_offset,'credit',0
          ),
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='STAFF_ADVANCE' limit 1),
            'debit',0,'credit',advance_offset
          )
        )
      );
      insert into public.finance_advance_movements(
        advance_id,movement_type,amount,source_type,source_id,created_by,reason
      )
      values(
        advance_row.id,'SETTLEMENT',advance_offset,
        'COMPENSATION_SETTLEMENT',settlement.id::text,actor,reason
      );
    end if;

    if cash_paid>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_CASH_SETTLEMENT',settlement.id::text,
        'Teacher compensation cash settlement',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',cash_paid,'credit',0
          ),
          jsonb_build_object(
            'account_id',payment_account,'debit',0,'credit',cash_paid
          )
        )
      );
    end if;

    insert into public.finance_payable_settlements(
      payable_id,amount,payment_account_id,external_reference,settled_by,reason
    )
    values(
      payable.id,amount,
      coalesce(payment_account,(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='CASH' limit 1)),
      nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    );

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
      then 'SETTLED' else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    if not exists(
      select 1 from public.finance_payables
      where source_type='COMPENSATION_RUN'
        and source_id like compensation.id::text||':%'
        and status<>'SETTLED'
    ) then
      update public.teacher_compensation_runs set status='SETTLED' where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',settlement.id,'message','Teacher compensation settlement posted.');
  
  elsif action='REQUEST_COMP_ADJUSTMENT' then
    if not exists(select 1 from public.staff where id=(p_input->>'teacher_id')::uuid and status='ACTIVE') then
      raise exception 'Choose an active teacher.';
    end if;
    amount:=(p_input->>'amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Adjustment amount must be positive.'; end if;

    insert into public.teacher_compensation_adjustments(
      teacher_id,amount,adjustment_type,effective_period,reason,requested_by
    )
    values(
      (p_input->>'teacher_id')::uuid,amount,
      coalesce(p_input->>'adjustment_type','ADJUSTMENT'),
      (p_input->>'effective_period')::date,reason,actor
    )
    returning id into settlement_id;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION_ADJUSTMENT','TEACHER_COMPENSATION_ADJUSTMENT',settlement_id::text,
      action,p_input,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_adjustments
    set approval_id=approval.id
    where id=settlement_id;

    result:=jsonb_build_object('id',settlement_id,'message','Compensation adjustment submitted for approval.');

  elsif action='DECIDE_COMP_ADJUSTMENT' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION_ADJUSTMENT'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation adjustment not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the adjustment.'; end if;

    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.teacher_compensation_adjustments
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end,
        approved_by=actor,approved_at=now()
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Compensation adjustment '||lower(decision)||'.');

  else
    raise exception 'Unsupported accounting action.';
  end if;

  insert into public.audit_events(
    correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,action,reason,after_data,metadata
  )
  values(
    req,actor,(select id from public.staff where profile_id=actor limit 1),
    'FINANCE_ACCOUNTING',coalesce(result->>'id',req::text),action,reason,result,p_input
  );

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(req,actor,p_input,result);

  return result;
end;
$$;

revoke all on function public.finance_accounting_command(jsonb)
from public,anon;
grant execute on function public.finance_accounting_command(jsonb)
to authenticated;

-- ---------------------------------------------------------------------------
-- Security: all financial tables are read-only through RLS; mutations go RPC.
-- ---------------------------------------------------------------------------

alter table public.finance_accounts enable row level security;
alter table public.finance_cost_centres enable row level security;
alter table public.general_ledger_journals enable row level security;
alter table public.general_ledger_lines enable row level security;
alter table public.vendors enable row level security;
alter table public.finance_payment_account_map enable row level security;
alter table public.finance_fee_revenue_map enable row level security;
alter table public.finance_payables enable row level security;
alter table public.finance_payable_settlements enable row level security;
alter table public.finance_advances enable row level security;
alter table public.finance_advance_movements enable row level security;
alter table public.finance_expense_categories enable row level security;
alter table public.finance_expenses enable row level security;
alter table public.finance_expense_reconciliations enable row level security;
alter table public.finance_account_reconciliations enable row level security;
alter table public.teacher_referrals enable row level security;
alter table public.teacher_compensation_runs enable row level security;
alter table public.teacher_compensation_events enable row level security;
alter table public.teacher_compensation_adjustments enable row level security;
alter table public.teacher_compensation_lines enable row level security;
alter table public.teacher_compensation_settlements enable row level security;

grant select on
  public.finance_accounts,
  public.finance_cost_centres,
  public.general_ledger_journals,
  public.general_ledger_lines,
  public.vendors,
  public.finance_payment_account_map,
  public.finance_fee_revenue_map,
  public.finance_payables,
  public.finance_payable_settlements,
  public.finance_advances,
  public.finance_advance_movements,
  public.finance_expense_categories,
  public.finance_expenses,
  public.finance_expense_reconciliations,
  public.finance_account_reconciliations,
  public.teacher_referrals,
  public.teacher_compensation_runs,
  public.teacher_compensation_events,
  public.teacher_compensation_adjustments,
  public.teacher_compensation_lines,
  public.teacher_compensation_settlements
to authenticated;

create policy finance_accounts_read
on public.finance_accounts for select to authenticated
using(public.has_permission('accounting.view') or public.has_permission('finance.view'));

create policy finance_cost_centres_read
on public.finance_cost_centres for select to authenticated
using(public.has_permission('accounting.view') or public.has_permission('finance.view'));

create policy ledger_read
on public.general_ledger_journals for select to authenticated
using(public.has_permission('accounting.view'));

create policy ledger_lines_read
on public.general_ledger_lines for select to authenticated
using(public.has_permission('accounting.view'));

create policy vendors_read
on public.vendors for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('accounting.view'));

create policy payment_map_read
on public.finance_payment_account_map for select to authenticated
using(public.has_permission('accounting.view'));

create policy fee_map_read
on public.finance_fee_revenue_map for select to authenticated
using(public.has_permission('accounting.view'));

create policy payables_read
on public.finance_payables for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('accounting.view'));

create policy payable_settlements_read
on public.finance_payable_settlements for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('accounting.view'));

create policy advances_read
on public.finance_advances for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('finance.advances.manage'));

create policy advance_movements_read
on public.finance_advance_movements for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('finance.advances.manage'));

create policy expense_categories_read
on public.finance_expense_categories for select to authenticated
using(public.has_permission('accounting.view') or public.has_permission('accounting.expense.manage'));

create policy expenses_read
on public.finance_expenses for select to authenticated
using(public.has_permission('finance.view') or public.has_permission('accounting.expense.manage'));

create policy expense_reconciliation_read
on public.finance_expense_reconciliations for select to authenticated
using(public.has_permission('accounting.reconcile'));

create policy account_reconciliation_read
on public.finance_account_reconciliations for select to authenticated
using(public.has_permission('accounting.reconcile'));

create policy teacher_referrals_read
on public.teacher_referrals for select to authenticated
using(public.has_permission('staff.compensation.view') or public.has_permission('admissions.view'));

create policy compensation_runs_read
on public.teacher_compensation_runs for select to authenticated
using(public.has_permission('staff.compensation.view'));

create policy compensation_lines_read
on public.teacher_compensation_lines for select to authenticated
using(public.has_permission('staff.compensation.view'));

create policy compensation_settlements_read
on public.teacher_compensation_settlements for select to authenticated
using(public.has_permission('staff.compensation.view'));

create policy compensation_events_read
on public.teacher_compensation_events for select to authenticated
using(public.has_permission('staff.compensation.view'));

create policy compensation_adjustments_read
on public.teacher_compensation_adjustments for select to authenticated
using(public.has_permission('staff.compensation.view'));

revoke insert,update,delete on
  public.finance_accounts,
  public.finance_cost_centres,
  public.general_ledger_journals,
  public.general_ledger_lines,
  public.vendors,
  public.finance_payment_account_map,
  public.finance_fee_revenue_map,
  public.finance_payables,
  public.finance_payable_settlements,
  public.finance_advances,
  public.finance_advance_movements,
  public.finance_expense_categories,
  public.finance_expenses,
  public.finance_expense_reconciliations,
  public.finance_account_reconciliations,
  public.teacher_referrals,
  public.teacher_compensation_runs,
  public.teacher_compensation_events,
  public.teacher_compensation_adjustments,
  public.teacher_compensation_lines,
  public.teacher_compensation_settlements
from anon,authenticated;

-- ---------------------------------------------------------------------------
-- Historical accounting backfill.
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select i.id
    from public.admission_invoices i
    where not exists(
      select 1 from public.general_ledger_journals j
      where j.source_type='ADMISSION_INVOICE' and j.source_id=i.id::text
    )
  loop
    perform public.finance_sync_invoice(r.id);
  end loop;

  for r in
    select c.id
    from public.invoice_credits c
    where not exists(
      select 1 from public.general_ledger_journals j
      where j.source_type='INVOICE_CREDIT' and j.source_id=c.id::text
    )
  loop
    perform public.finance_sync_invoice_credit(r.id);
  end loop;

  for r in
    select p.id
    from public.admission_payments p
    where not exists(
      select 1 from public.general_ledger_journals j
      where j.source_type='ADMISSION_PAYMENT' and j.source_id=p.id::text
    )
  loop
    perform public.finance_sync_payment(r.id);
  end loop;

  for r in
    select rp.id
    from public.refund_payouts rp
    where not exists(
      select 1 from public.general_ledger_journals j
      where j.source_type='REFUND_PAYOUT' and j.source_id=rp.id::text
    )
  loop
    perform public.finance_sync_refund(r.id);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Extend compensation-policy validation with the optional allocation method.
-- The original five percentage keys remain compatible with earlier versions.
-- ---------------------------------------------------------------------------

create or replace function public.validate_business_rule_payload(
  p_domain text,
  p_rule_key text,
  p_payload jsonb
)
returns boolean
language plpgsql
immutable
as $$
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
$$;

-- Helper for advance paid total.
create or replace function public.advance_paid(p_advance_id uuid)
returns numeric
language sql
stable
security definer
set search_path=public
as $$
  select coalesce(sum(amount),0)
  from public.finance_advance_movements
  where advance_id=p_advance_id and movement_type='PAYMENT';
$$;
revoke all on function public.advance_paid(uuid) from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Final grants after helper creation
-- ---------------------------------------------------------------------------

grant usage on schema public to authenticated;



-- ============================================================
-- SOURCE: 0043_v2_finance_account_balance_read.sql
-- ============================================================

-- Expose read-only account balances without granting clients the internal
-- posting/settlement helper directly.
create or replace function public.finance_read_account_balance(
  p_account_id uuid,
  p_as_of date default current_date
)
returns numeric
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null or not public.has_permission('accounting.view') then
    raise exception 'Accounting view permission required.';
  end if;
  if p_account_id is null or p_as_of is null or not exists(
    select 1 from public.finance_accounts where id=p_account_id and is_active
  ) then raise exception 'Choose an active financial account and date.'; end if;
  return coalesce(public.finance_account_balance(p_account_id,p_as_of),0);
end $$;
revoke all on function public.finance_read_account_balance(uuid,date) from public,anon;
grant execute on function public.finance_read_account_balance(uuid,date) to authenticated;



-- ============================================================
-- SOURCE: 0044_v2_finance_integrity.sql
-- ============================================================

-- Repair finance operations without rewriting migration 0042 after deployment.
alter table public.teacher_compensation_lines
 add column admission_id uuid references public.admission_cases(id);

-- A source can be earned only once across approved runs. Rejected requests do
-- not consume the source; approval is serialized by this unique key.
create table public.teacher_compensation_claims (
 id uuid primary key default gen_random_uuid(),
 teacher_id uuid not null references public.staff(id),
 source_type text not null, source_id text not null,
 line_id uuid not null unique references public.teacher_compensation_lines(id),
 run_id uuid not null references public.teacher_compensation_runs(id),
 claimed_at timestamptz not null default now(),
 unique(teacher_id,source_type,source_id)
);
alter table public.teacher_compensation_claims enable row level security;
grant select on public.teacher_compensation_claims to authenticated;
revoke insert,update,delete on public.teacher_compensation_claims from anon,authenticated;
create policy teacher_compensation_claims_read on public.teacher_compensation_claims
 for select to authenticated using(public.has_permission('staff.compensation.view'));
create trigger immutable_compensation_claim before update or delete on public.teacher_compensation_claims
 for each row execute function public.protect_admission_invoice();

alter table public.finance_advance_movements
  add column payable_id uuid references public.finance_payables(id);

alter table public.finance_payable_settlements
  add column advance_id uuid references public.finance_advances(id);

revoke execute on function public.finance_sync_invoice(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_invoice_credit(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_payment(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_refund(uuid) from public, anon, authenticated;
revoke execute on function public.finance_sync_invoice_line_statement() from public, anon, authenticated;

-- This helper describes actual cash movement by the academy's local posting
-- date, not the month written on an invoice. Refunds are negative movements.
create or replace function public.finance_net_collected_tuition(p_from date,p_to date)
returns table(admission_id uuid,batch_id uuid,billing_period date,tuition_collected numeric)
language sql stable security definer set search_path=public as $$
with cash_events as (
 select i.id invoice_id,i.admission_id,a.batch_id,
  timezone(o.timezone,p.posted_at)::date event_date,
  pa.amount signed_amount,
  (select coalesce(sum(l.amount),0) from public.admission_invoice_lines l
    where l.invoice_id=i.id and l.charge_type='TUITION') tuition_gross
 from public.admission_payment_allocations pa
 join public.admission_payments p on p.id=pa.payment_id
 join public.admission_invoices i on i.id=pa.invoice_id
 join public.admission_cases a on a.id=i.admission_id
 join public.students s on s.id=p.student_id
 join public.organizations o on o.id=s.organization_id
 where timezone(o.timezone,p.posted_at)::date between p_from and p_to
 union all
 select i.id,i.admission_id,a.batch_id,
  timezone(o.timezone,rp.posted_at)::date,-r.amount,
  (select coalesce(sum(l.amount),0) from public.admission_invoice_lines l
    where l.invoice_id=i.id and l.charge_type='TUITION')
 from public.refund_payouts rp
 join public.refund_authorizations r on r.id=rp.authorization_id
 join public.admission_invoices i on i.id=r.invoice_id
 join public.admission_cases a on a.id=i.admission_id
 join public.students s on s.id=i.student_id
 join public.organizations o on o.id=s.organization_id
 where timezone(o.timezone,rp.posted_at)::date between p_from and p_to
), attributed as (
 select e.*, greatest(i.total-coalesce((select sum(c.amount) from public.invoice_credits c
   where c.invoice_id=e.invoice_id and c.created_at::date<=e.event_date),0),0) net_invoice,
  greatest(e.tuition_gross-coalesce((select sum(c.amount) from public.invoice_credits c
   where c.invoice_id=e.invoice_id and c.kind='DISCOUNT' and c.created_at::date<=e.event_date),0),0) net_tuition
 from cash_events e join public.admission_invoices i on i.id=e.invoice_id
)
select admission_id,batch_id,date_trunc('month',event_date)::date,
 round(sum(case when net_invoice>0 then signed_amount*least(net_tuition,net_invoice)/net_invoice else 0 end),2)
from attributed group by admission_id,batch_id,date_trunc('month',event_date)::date;
$$;
revoke all on function public.finance_net_collected_tuition(date,date) from public,anon,authenticated;

-- Period-scoped, once-only compensation preview.
create or replace function public.teacher_compensation_preview(
  p_from date,
  p_to date
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  policy public.business_rule_versions;
  rows jsonb:='[]'::jsonb;
  teacher_row record;
  batch_row record;
  event_amount numeric;
  pool_percent numeric;
  acquisition_percent numeric;
  retention3_percent numeric;
  retention6_percent numeric;
  first_period date;
  first_collected numeric;
  month3 date;
  month6 date;
  month_paid boolean;
  continuous3 boolean;
  continuous6 boolean;
begin
  if actor is null or not public.has_permission('staff.compensation.view') then
    raise exception 'Compensation access denied.';
  end if;
  if p_from is null or p_to is null or p_to<p_from then
    raise exception 'Choose a valid compensation period.';
  end if;

  select * into policy
  from public.business_rule_versions
  where domain='teacher_compensation'
    and rule_key='default_policy'
    and status='ACTIVE'
  order by version desc
  limit 1;

  if policy.id is null
     or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
    raise exception 'A valid teacher compensation policy is required.';
  end if;

  pool_percent:=(policy.payload->>'teaching_pool_percent')::numeric;
  acquisition_percent:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  retention3_percent:=(policy.payload->>'retention_3_month_percent')::numeric;
  retention6_percent:=(policy.payload->>'retention_6_month_percent')::numeric;

  -- Teaching pool is calculated per batch from Net Collected Tuition and
  -- allocated by approved attendance/session workload within that batch.
  for batch_row in
    with batch_revenue as (
      select batch_id,sum(tuition_collected) net_collected
      from public.finance_net_collected_tuition(p_from,p_to)
      group by batch_id
    ),
    session_weights as (
      select
        cs.batch_id,
        cs.teacher_id,
        count(*) filter(
          where exists(
            select 1 from public.attendance_submissions aa
            where aa.id=(
              select z.id from public.attendance_submissions z
              where z.session_id=cs.id
              order by z.revision desc limit 1
            )
            and aa.status='APPROVED'
          )
        )::numeric as session_count
      from public.class_sessions cs
      where cs.session_date between p_from and p_to
        and cs.status='SCHEDULED'
      group by cs.batch_id,cs.teacher_id
    )
    select
      r.batch_id,
      r.net_collected,
      r.net_collected*pool_percent/100 as pool_amount,
      w.teacher_id,
      w.session_count,
      sum(w.session_count) over(partition by w.batch_id) total_sessions
    from batch_revenue r
    join session_weights w on w.batch_id=r.batch_id
    where r.net_collected>0 and w.session_count>0
  loop
    event_amount:=round(batch_row.pool_amount*batch_row.session_count/nullif(batch_row.total_sessions,0),2);
    if event_amount>0 and not exists (select 1 from public.teacher_compensation_claims c
      where c.teacher_id=batch_row.teacher_id and c.source_type='BATCH_PERIOD'
        and c.source_id=batch_row.batch_id::text||':'||p_from::text||':'||p_to::text) then
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',batch_row.teacher_id,
        'lineType','TEACHING_REMUNERATION',
        'amount',event_amount,
        'sourceType','BATCH_PERIOD',
        'sourceId',batch_row.batch_id::text||':'||p_from::text||':'||p_to::text,
        'calculation',jsonb_build_object(
          'batchId',batch_row.batch_id,
          'netCollectedTuition',batch_row.net_collected,
          'poolPercent',pool_percent,
          'poolAmount',batch_row.pool_amount,
          'approvedSessions',batch_row.session_count,
          'batchApprovedSessions',batch_row.total_sessions
        )
      )
    );
    end if;
  end loop;

  -- Acquisition/retention bonuses require a structured teacher referral.
  for teacher_row in
    select
      tr.teacher_id,
      tr.admission_id,
      min(n.billing_period) first_billing_period
    from public.teacher_referrals tr
    join public.admission_cases a on a.id=tr.admission_id and a.status='ACTIVE_ENROLLMENT'
    join public.finance_net_collected_tuition(date '2000-01-01',p_to) n
      on n.admission_id=tr.admission_id and n.tuition_collected>0
    group by tr.teacher_id,tr.admission_id
  loop
    first_period:=teacher_row.first_billing_period;

    select coalesce(sum(n.tuition_collected),0)
    into first_collected
    from public.finance_net_collected_tuition(first_period,(first_period+interval '1 month - 1 day')::date) n
    where n.admission_id=teacher_row.admission_id;

    if first_period between p_from and p_to and first_collected>0
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='ACQUISITION'
          and c.source_id=teacher_row.admission_id::text) then
      rows:=rows||jsonb_build_array(
        jsonb_build_object(
          'teacherId',teacher_row.teacher_id,
          'admissionId',teacher_row.admission_id,
          'lineType','ACQUISITION_BONUS',
          'amount',round(first_collected*acquisition_percent/100,2),
          'sourceType','ACQUISITION',
          'sourceId',teacher_row.admission_id::text,
          'calculation',jsonb_build_object(
            'firstMonthNetCollectedTuition',first_collected,
            'bonusPercent',acquisition_percent
          )
        )
      );
    end if;

    month3:=(first_period+interval '2 months')::date;
    month6:=(first_period+interval '5 months')::date;

    select bool_and(tuition_collected>0)
    into continuous3
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month3,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month3 between p_from and p_to and continuous3 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_3'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month3,(month3+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_3_MONTH',
            'amount',round(event_amount*retention3_percent/100,2),
            'sourceType','RETENTION_3',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month3,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention3_percent
            )
          )
        );
      end if;
    end if;

    select bool_and(tuition_collected>0)
    into continuous6
    from (
      select
        m.month_start,
        coalesce((
          select sum(n.tuition_collected)
          from public.finance_net_collected_tuition(m.month_start,(m.month_start+interval '1 month - 1 day')::date) n
          where n.admission_id=teacher_row.admission_id
        ),0) tuition_collected
      from generate_series(first_period,month6,interval '1 month') g
      cross join lateral(select g::date month_start) m
    ) x;

    if month6 between p_from and p_to and continuous6 is true
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_row.teacher_id and c.source_type='RETENTION_6'
          and c.source_id=teacher_row.admission_id::text) then
      select coalesce(sum(n.tuition_collected),0)
      into event_amount
      from public.finance_net_collected_tuition(month6,(month6+interval '1 month - 1 day')::date) n
      where n.admission_id=teacher_row.admission_id;

      if event_amount>0 then
        rows:=rows||jsonb_build_array(
          jsonb_build_object(
            'teacherId',teacher_row.teacher_id,
            'admissionId',teacher_row.admission_id,
            'lineType','RETENTION_6_MONTH',
            'amount',round(event_amount*retention6_percent/100,2),
            'sourceType','RETENTION_6',
            'sourceId',teacher_row.admission_id::text,
            'calculation',jsonb_build_object(
              'milestoneMonth',month6,
              'monthNetCollectedTuition',event_amount,
              'bonusPercent',retention6_percent
            )
          )
        );
      end if;
    end if;
  end loop;

  for teacher_row in
    select teacher_id,adjustment_type,id,amount
    from public.teacher_compensation_adjustments
    where status='APPROVED'
      and effective_period between p_from and p_to
      and not exists(select 1 from public.teacher_compensation_claims c
        where c.teacher_id=teacher_compensation_adjustments.teacher_id
          and c.source_type='ADJUSTMENT' and c.source_id=teacher_compensation_adjustments.id::text)
  loop
    rows:=rows||jsonb_build_array(
      jsonb_build_object(
        'teacherId',teacher_row.teacher_id,
        'lineType',case when teacher_row.adjustment_type='GROWTH_BONUS'
          then 'GROWTH_BONUS' else 'ADJUSTMENT' end,
        'amount',teacher_row.amount,
        'sourceType','ADJUSTMENT',
        'sourceId',teacher_row.id::text,
        'calculation',jsonb_build_object(
          'adjustmentType',teacher_row.adjustment_type
        )
      )
    );
  end loop;

  return jsonb_build_object(
    'periodStart',p_from,
    'periodEnd',p_to,
    'policyVersion',policy.version,
    'rows',rows,
    'total',coalesce((select sum((x->>'amount')::numeric) from jsonb_array_elements(rows) x),0)
  );
end;
$$;



-- Transactional finance command with compensation and payable corrections.
create or replace function public.finance_accounting_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  key public.admission_command_keys;
  result jsonb;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  org uuid;
  account public.finance_accounts;
  journal_id uuid;
  approval public.approval_requests;
  advance public.finance_advances;
  adv_balance numeric;
  payable public.finance_payables;
  expense public.finance_expenses;
  vendor public.vendors;
  amount numeric;
  expense_account uuid;
  payment_account uuid;
  payment_mode text;
  category public.finance_expense_categories;
  compensation public.teacher_compensation_runs;
  policy public.business_rule_versions;
  preview jsonb;
  line jsonb;
  teacher_id uuid;
  v_teacher uuid;
  settlement public.teacher_compensation_settlements;
  cash_paid numeric;
  advance_offset numeric;
  advance_row record;
  settlement_id uuid;
  decision text;
  source_type text;
  permission text;
begin
  if actor is null then raise exception 'Sign in to continue.'; end if;
  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason of at least five characters are required.';
  end if;

  permission := null;
  -- Action permission is assigned below because compensation/expense/advance
  -- workflows have different authorization boundaries.
  if action in('CREATE_ACCOUNT','POST_JOURNAL') then permission:='accounting.manage';
  elsif action in('CREATE_VENDOR','REQUEST_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('DECIDE_ADVANCE') then permission:='finance.advances.approve';
  elsif action in('PAY_ADVANCE','REFUND_ADVANCE') then permission:='finance.advances.manage';
  elsif action in('CREATE_EXPENSE','SUBMIT_EXPENSE') then permission:='accounting.expense.manage';
  elsif action='DECIDE_EXPENSE' then permission:='accounting.expense.approve';
  elsif action='POST_EXPENSE' then permission:='accounting.expense.manage';
  elsif action='SETTLE_PAYABLE' then permission:='finance.payments.post';
  elsif action='REQUEST_ADVANCE_SETTLEMENT' then permission:='finance.advances.manage';
  elsif action='DECIDE_ADVANCE_SETTLEMENT' then permission:='finance.advances.approve';
  elsif action='RECONCILE_EXPENSE' or action='RECONCILE_ACCOUNT' then permission:='accounting.reconcile';
  elsif action='REQUEST_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMPENSATION' then permission:='staff.compensation.approve';
  elsif action='SETTLE_COMPENSATION' then permission:='staff.compensation.manage';
  elsif action='REQUEST_COMP_ADJUSTMENT' then permission:='staff.compensation.manage';
  elsif action='DECIDE_COMP_ADJUSTMENT' then permission:='staff.compensation.approve';
  elsif action='SET_TEACHER_REFERRAL' then permission:='admissions.create';
  else permission:=null;
  end if;

  if permission is null or not public.has_permission(permission) then
    raise exception 'Permission denied for this accounting action.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,7));
  select * into key from public.admission_command_keys where request_id=req;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select id into org from public.organizations where code='SOHOJ' and is_active limit 1;

  if action='CREATE_ACCOUNT' then
    if length(btrim(coalesce(p_input->>'code','')))<2
       or length(btrim(coalesce(p_input->>'name','')))<2
       or p_input->>'account_type' not in('ASSET','LIABILITY','EQUITY','REVENUE','CONTRA_REVENUE','EXPENSE')
       or length(btrim(coalesce(p_input->>'account_subtype','')))<2 then
      raise exception 'Enter valid account code, name, type and category.';
    end if;

    insert into public.finance_accounts(
      organization_id,code,name,account_type,account_subtype,parent_id,
      is_control_account,created_by
    )
    values(
      org,btrim(p_input->>'code'),btrim(p_input->>'name'),
      p_input->>'account_type',btrim(p_input->>'account_subtype'),
      nullif(p_input->>'parent_id','')::uuid,
      coalesce((p_input->>'is_control_account')::boolean,false),actor
    )
    returning * into account;

    result:=jsonb_build_object('id',account.id,'message','Financial account created.');

  elsif action='POST_JOURNAL' then
    if not public.has_permission('accounting.manage') then raise exception 'Accounting management permission required.'; end if;
    perform public.finance_post_journal(
      org,
      (p_input->>'journal_date')::date,
      'MANUAL',
      'MANUAL_JOURNAL',
      req::text,
      btrim(p_input->>'description'),
      actor,
      p_input->'lines'
    );
    result:=jsonb_build_object('id',req,'message','Balanced journal posted.');

  elsif action='CREATE_VENDOR' then
    if length(btrim(coalesce(p_input->>'name','')))<2 then
      raise exception 'Vendor name is required.';
    end if;
    insert into public.vendors(
      organization_id,name,mobile,email,address,service_category,created_by
    )
    values(
      org,btrim(p_input->>'name'),
      nullif(btrim(p_input->>'mobile'),''),
      nullif(lower(btrim(p_input->>'email')),''),
      nullif(btrim(p_input->>'address'),''),
      nullif(btrim(p_input->>'service_category'),''),
      actor
    )
    returning * into vendor;
    result:=jsonb_build_object('id',vendor.id,'vendorNo',vendor.vendor_no,'message','Vendor created.');

  elsif action='SET_TEACHER_REFERRAL' then
    select * into compensation from public.teacher_compensation_runs where false;
    if not exists(
      select 1 from public.admission_cases
      where id=(p_input->>'admission_id')::uuid and status in('DRAFT','READY')
    ) then
      raise exception 'Teacher referral can only be captured before admission acceptance.';
    end if;
    if not exists(
      select 1 from public.staff s
      where s.id=(p_input->>'teacher_id')::uuid
        and s.status='ACTIVE'
        and exists(
          select 1
          from public.staff_role_assignments sra
          join public.staff_roles sr on sr.id=sra.staff_role_id
          where sra.staff_id=s.id and sr.is_teaching_role
        )
    ) then raise exception 'Choose an active teacher.';
    end if;

    insert into public.teacher_referrals(admission_id,teacher_id,captured_by,reason)
    values((p_input->>'admission_id')::uuid,(p_input->>'teacher_id')::uuid,actor,reason)
    on conflict(admission_id) do update
      set teacher_id=excluded.teacher_id,captured_by=excluded.captured_by,
          captured_at=now(),reason=excluded.reason;

    result:=jsonb_build_object('id',(p_input->>'admission_id'),'message','Teacher referral recorded before acceptance.');

  elsif action='REQUEST_ADVANCE' then
    if p_input->>'beneficiary_type' not in('STAFF','VENDOR','PROJECT') then
      raise exception 'Choose staff, vendor or project as the advance beneficiary.';
    end if;
    amount:=(p_input->>'requested_amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Advance amount must be positive.'; end if;

    insert into public.finance_advances(
      organization_id,beneficiary_type,staff_id,vendor_id,project_reference,
      purpose,requested_amount,expected_settlement_date,requested_by,status
    )
    values(
      org,p_input->>'beneficiary_type',
      nullif(p_input->>'staff_id','')::uuid,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(btrim(p_input->>'project_reference'),''),
      btrim(p_input->>'purpose'),amount,
      nullif(p_input->>'expected_settlement_date','')::date,
      actor,'REQUESTED'
    )
    returning * into advance;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values(
      'ADVANCE','FINANCE_ADVANCE',advance.id::text,action,p_input,reason,actor,req
    )
    returning id into approval;

    update public.finance_advances
    set approval_id=approval.id
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance submitted for independent approval.');

  elsif action='DECIDE_ADVANCE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='ADVANCE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then
      raise exception 'Pending advance approval not found.';
    end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the advance.'; end if;

    select * into advance from public.finance_advances where id=approval.entity_id::uuid for update;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      update public.finance_advances
      set approved_amount=(approval.payload_snapshot->>'requested_amount')::numeric,status='APPROVED'
      where id=advance.id;
    else
      update public.finance_advances set status='REJECTED' where id=advance.id;
    end if;

    result:=jsonb_build_object('id',advance.id,'message','Advance request '||lower(decision)||'.');

  elsif action='PAY_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null or advance.status not in('APPROVED','PAID') then raise exception 'Only approved advances can be paid.'; end if;
    if amount is null or amount<=0 then raise exception 'Advance payment must be positive.'; end if;
    if amount>advance.approved_amount-public.advance_paid(advance.id) then raise exception 'Payment exceeds approved advance balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;

    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(
      advance.id,'PAYMENT',amount,'ADVANCE_PAYMENT',req::text,payment_account,actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_PAYMENT','ADVANCE_PAYMENT',req::text,
      'Advance payment '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='STAFF'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
            when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',amount,'credit',0
        ),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    if public.advance_paid(advance.id)>=advance.approved_amount then
      update public.finance_advances set status='PAID' where id=advance.id;
    end if;
    result:=jsonb_build_object('id',advance.id,'message','Advance payment posted.');

  elsif action='REQUEST_ADVANCE_SETTLEMENT' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if advance.id is null or advance.status not in('PAID','PARTIALLY_SETTLED','OVERDUE')
      or payable.id is null or payable.status not in('OPEN','PARTIALLY_SETTLED')
      or payable.organization_id<>advance.organization_id
      or not ((advance.beneficiary_type='VENDOR' and payable.vendor_id=advance.vendor_id)
        or (advance.beneficiary_type='STAFF' and payable.staff_id=advance.staff_id))
      or amount is null or amount<=0 or amount<>round(amount,2)
      or amount>public.advance_balance(advance.id)
      or amount>payable.original_amount-coalesce((select sum(s.amount)
        from public.finance_payable_settlements s where s.payable_id=payable.id),0) then
      raise exception 'Choose a matching approved payable and outstanding advance balance.';
    end if;
    insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,
      payload_snapshot,request_note,requested_by,correlation_id)
    values('ADVANCE_SETTLEMENT','ADVANCE',advance.id::text,action,p_input,reason,actor,req)
    returning id into approval;
    result:=jsonb_build_object('id',approval.id,'message','Advance application submitted for independent approval.');

  elsif action='DECIDE_ADVANCE_SETTLEMENT' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='ADVANCE_SETTLEMENT' for update;
    if approval.id is null or approval.status<>'PENDING' or approval.requested_by=actor then
      raise exception 'Choose a pending advance application submitted by another staff member.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
    if decision='APPROVED' then
      select * into advance from public.finance_advances
        where id=(approval.payload_snapshot->>'advance_id')::uuid for update;
      select * into payable from public.finance_payables
        where id=(approval.payload_snapshot->>'payable_id')::uuid for update;
      amount:=(approval.payload_snapshot->>'amount')::numeric;
      if advance.id is null or payable.id is null or payable.organization_id<>advance.organization_id
        or payable.status not in('OPEN','PARTIALLY_SETTLED')
        or not ((advance.beneficiary_type='VENDOR' and payable.vendor_id=advance.vendor_id)
          or (advance.beneficiary_type='STAFF' and payable.staff_id=advance.staff_id))
        or amount>public.advance_balance(advance.id)
        or amount>payable.original_amount-coalesce((select sum(s.amount)
          from public.finance_payable_settlements s where s.payable_id=payable.id),0) then
        raise exception 'Advance or payable changed; review the application again.';
      end if;
      perform public.finance_post_journal(
        org,current_date,'ADVANCE_SETTLEMENT','ADVANCE_SETTLEMENT',approval.id::text,
        'Approved advance against payable '||payable.payable_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',payable.payable_account_id,'debit',amount,'credit',0),
          jsonb_build_object('account_id',(select id from public.finance_accounts
            where organization_id=org and account_subtype=case when advance.beneficiary_type='VENDOR'
              then 'VENDOR_ADVANCE' else 'STAFF_ADVANCE' end limit 1),
            'debit',0,'credit',amount)
        )
      );
      insert into public.finance_advance_movements(advance_id,movement_type,amount,
        source_type,source_id,payable_id,created_by,reason)
      values(advance.id,'SETTLEMENT',amount,'ADVANCE_SETTLEMENT',approval.id::text,payable.id,actor,reason);
      insert into public.finance_payable_settlements(payable_id,amount,advance_id,settled_by,reason)
      values(payable.id,amount,advance.id,actor,'Advance application: '||reason);
      update public.finance_advances set status=case when public.advance_balance(id)=0
        then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=advance.id;
      update public.finance_payables p set status=case when
        coalesce((select sum(s.amount) from public.finance_payable_settlements s
          where s.payable_id=p.id),0)>=p.original_amount then 'SETTLED' else 'PARTIALLY_SETTLED' end
      where p.id=payable.id;
    end if;
    update public.approval_requests set status=decision::public.approval_status,
      decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
    result:=jsonb_build_object('id',approval.id,'message','Advance application '||lower(decision)||'.');

  elsif action='REFUND_ADVANCE' then
    select * into advance from public.finance_advances where id=(p_input->>'advance_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    adv_balance:=public.advance_balance(advance.id);
    if advance.id is null or adv_balance<=0 or amount is null or amount<=0 or amount>adv_balance then
      raise exception 'Refund exceeds the unsettled advance balance.';
    end if;
    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    perform public.finance_post_journal(
      org,current_date,'ADVANCE_REFUND','ADVANCE_REFUND',req::text,
      'Advance refund '||advance.advance_no,actor,
      jsonb_build_array(
        jsonb_build_object(
          'account_id',payment_account,'debit',amount,'credit',0
        ),
        jsonb_build_object(
          'account_id',
          case when advance.beneficiary_type='VENDOR'
            then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_ADVANCE' limit 1)
            else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_ADVANCE' limit 1)
          end,
          'debit',0,'credit',amount
        )
      )
    );

    insert into public.finance_advance_movements(
      advance_id,movement_type,amount,source_type,source_id,payment_account_id,created_by,reason
    )
    values(advance.id,'REFUND',amount,'ADVANCE_REFUND',req::text,payment_account,actor,reason);

    update public.finance_advances
    set status=case when public.advance_balance(id)<=0 then 'REFUNDED' else status end
    where id=advance.id;

    result:=jsonb_build_object('id',advance.id,'message','Advance refund recorded.');

  elsif action='CREATE_EXPENSE' then
    amount:=(p_input->>'amount')::numeric;
    payment_mode:=p_input->>'payment_mode';
    if amount is null or amount<=0 or payment_mode not in('PAID_NOW','ON_ACCOUNT') then
      raise exception 'Enter a valid expense amount and payment mode.';
    end if;
    select * into category from public.finance_expense_categories
    where id=(p_input->>'category_id')::uuid and organization_id=org and is_active;
    if category.id is null then raise exception 'Choose an active expense category.'; end if;

    insert into public.finance_expenses(
      organization_id,expense_date,category_id,expense_account_id,payment_mode,
      payment_account_id,vendor_id,staff_id,amount,description,receipt_reference,
      status,submitted_by
    )
    values(
      org,(p_input->>'expense_date')::date,category.id,category.expense_account_id,payment_mode,
      case when payment_mode='PAID_NOW' then nullif(p_input->>'payment_account_id','')::uuid else null end,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(p_input->>'staff_id','')::uuid,
      amount,btrim(p_input->>'description'),
      nullif(btrim(p_input->>'receipt_reference'),''),
      'PENDING_APPROVAL',actor
    )
    returning * into expense;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('EXPENSE','FINANCE_EXPENSE',expense.id::text,'CREATE_EXPENSE',p_input,reason,actor,req)
    returning id into approval;

    update public.finance_expenses set approval_id=approval.id where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense submitted for independent approval.');

  elsif action='DECIDE_EXPENSE' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='EXPENSE'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending expense approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the expense.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.finance_expenses
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Expense '||lower(decision)||'.');

  elsif action='POST_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    if expense.id is null or expense.status<>'APPROVED' then raise exception 'Only approved expenses can be posted.'; end if;
    if expense.payment_mode='PAID_NOW'
       and not exists(select 1 from public.finance_accounts where id=expense.payment_account_id and organization_id=org and account_subtype in('CASH','BANK','MOBILE_BANK') and is_active) then
      raise exception 'Choose an active cash or bank account for this expense.';
    end if;
    if expense.payment_mode='ON_ACCOUNT' and expense.vendor_id is null and expense.staff_id is null then
      raise exception 'An on-account expense must identify a vendor or staff claimant.';
    end if;

    if expense.payment_mode='PAID_NOW' then
      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',expense.payment_account_id,'debit',0,'credit',expense.amount)
        )
      );
    else
      insert into public.finance_payables(
        organization_id,payable_type,vendor_id,staff_id,source_type,source_id,
        payable_account_id,original_amount,due_on,created_by
      )
      values(
        org,
        case when expense.vendor_id is not null then 'VENDOR'
             when expense.staff_id is not null then 'STAFF_REIMBURSEMENT'
             else 'OTHER' end,
        expense.vendor_id,expense.staff_id,'EXPENSE',expense.id::text,
        case when expense.vendor_id is not null
          then (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1)
          else (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYABLE' limit 1)
        end,
        expense.amount,
        expense.expense_date + 30,
        actor
      )
      returning * into payable;

      update public.finance_expenses set payable_id=payable.id where id=expense.id;

      perform public.finance_post_journal(
        org,expense.expense_date,'EXPENSE','EXPENSE',expense.id::text,
        'Expense payable '||expense.expense_no,actor,
        jsonb_build_array(
          jsonb_build_object('account_id',expense.expense_account_id,'debit',expense.amount,'credit',0),
          jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',expense.amount)
        )
      );
    end if;

    update public.finance_expenses
    set status='POSTED',posted_by=actor,posted_at=now()
    where id=expense.id;

    result:=jsonb_build_object('id',expense.id,'message','Expense posted to the ledger.');

  elsif action='SETTLE_PAYABLE' then
    select * into payable from public.finance_payables where id=(p_input->>'payable_id')::uuid for update;
    amount:=(p_input->>'amount')::numeric;
    if payable.id is null or payable.status not in('OPEN','PARTIALLY_SETTLED') then raise exception 'Payable is not open.'; end if;
    if payable.payable_type='TEACHER_COMPENSATION' then raise exception 'Use the compensation settlement to preserve advance offsets.'; end if;
    if amount is null or amount<=0 or amount > payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0) then raise exception 'Settlement exceeds payable balance.'; end if;

    select id into payment_account
    from public.finance_accounts
    where id=(p_input->>'payment_account_id')::uuid
      and organization_id=org
      and account_subtype in('CASH','BANK','MOBILE_BANK')
      and is_active;
    if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;

    insert into public.finance_payable_settlements(
      payable_id,amount,payment_account_id,external_reference,settled_by,reason
    )
    values(
      payable.id,amount,payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    );

    perform public.finance_post_journal(
      org,current_date,'PAYABLE_SETTLEMENT','PAYABLE_SETTLEMENT',req::text,
      'Payable settlement '||payable.payable_no,actor,
      jsonb_build_array(
        jsonb_build_object('account_id',payable.payable_account_id,'debit',amount,'credit',0),
        jsonb_build_object('account_id',payment_account,'debit',0,'credit',amount)
      )
    );

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
        then 'SETTLED'
      else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    result:=jsonb_build_object('id',payable.id,'message','Payable settlement posted.');

  elsif action='RECONCILE_EXPENSE' then
    select * into expense from public.finance_expenses
    where id=(p_input->>'expense_id')::uuid for update;
    amount:=(p_input->>'matched_amount')::numeric;
    if expense.id is null or expense.status<>'POSTED' then raise exception 'Post the expense before reconciliation.'; end if;
    if amount is null or amount<>expense.amount then raise exception 'Reconciled amount must equal the posted expense amount.'; end if;

    insert into public.finance_expense_reconciliations(
      expense_id,matched_amount,statement_reference,reconciled_by,note
    )
    values(
      expense.id,amount,btrim(p_input->>'statement_reference'),actor,reason
    )
    on conflict(expense_id) do nothing;

    if not found then raise exception 'Expense is already reconciled.'; end if;
    update public.finance_expenses set status='RECONCILED' where id=expense.id;
    result:=jsonb_build_object('id',expense.id,'message','Expense reconciled to the statement reference.');

  elsif action='RECONCILE_ACCOUNT' then
    select * into account from public.finance_accounts
    where id=(p_input->>'account_id')::uuid
      and organization_id=org and is_active;
    if account.id is null then raise exception 'Choose an active account.'; end if;

    select public.finance_account_balance(account.id,(p_input->>'statement_date')::date)
    into amount;

    if amount is null then amount:=0; end if;
    insert into public.finance_account_reconciliations(
      account_id,statement_date,statement_reference,statement_balance,
      ledger_balance,difference,status,note,reconciled_by,reconciled_at
    )
    values(
      account.id,(p_input->>'statement_date')::date,
      btrim(p_input->>'statement_reference'),
      (p_input->>'statement_balance')::numeric,
      amount,
      round((p_input->>'statement_balance')::numeric-amount,2),
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then 'RECONCILED' else 'OPEN' end,
      reason,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then actor else null end,
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0 then now() else null end
    )
    on conflict(account_id,statement_date,statement_reference) do update
      set statement_balance=excluded.statement_balance,
          ledger_balance=excluded.ledger_balance,
          difference=excluded.difference,
          status=excluded.status,
          reconciled_by=excluded.reconciled_by,
          reconciled_at=excluded.reconciled_at,
          note=excluded.note;

    result:=jsonb_build_object('id',req,'message',
      case when round((p_input->>'statement_balance')::numeric-amount,2)=0
        then 'Account reconciled.'
        else 'Reconciliation saved as open; investigate the difference before closing it.' end);

  elsif action='REQUEST_COMPENSATION' then
    preview:=public.teacher_compensation_preview(
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date
    );
    if jsonb_array_length(preview->'rows')=0 then
      raise exception 'No eligible compensation lines for this period.';
    end if;
    if (p_input->>'period_start')::date<>date_trunc('month',(p_input->>'period_start')::date)::date
       or (p_input->>'period_end')::date<>((p_input->>'period_start')::date+interval '1 month - 1 day')::date then
      raise exception 'Compensation runs must cover one complete calendar month.';
    end if;

    select * into policy
    from public.business_rule_versions
    where domain='teacher_compensation'
      and rule_key='default_policy'
      and status='ACTIVE'
    order by version desc
    limit 1;

    insert into public.teacher_compensation_runs(
      organization_id,period_start,period_end,policy_version_id,
      status,total_amount,submitted_by
    )
    values(
      org,(p_input->>'period_start')::date,(p_input->>'period_end')::date,
      policy.id,'PENDING_APPROVAL',(preview->>'total')::numeric,actor
    )
    returning * into compensation;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION','TEACHER_COMPENSATION_RUN',compensation.id::text,
      action,preview,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_runs
    set approval_id=approval.id
    where id=compensation.id;

    for line in select value from jsonb_array_elements(preview->'rows')
    loop
      insert into public.teacher_compensation_lines(
        run_id,teacher_id,admission_id,line_type,source_type,source_id,amount,calculation
      )
      values(
        compensation.id,(line->>'teacherId')::uuid,
        nullif(line->>'admissionId','')::uuid,
        line->>'lineType',line->>'sourceType',line->>'sourceId',
        (line->>'amount')::numeric,coalesce(line->'calculation','{}'::jsonb)
      )
      on conflict(run_id,source_type,source_id) do nothing;
    end loop;

    result:=jsonb_build_object(
      'id',compensation.id,
      'runNo',compensation.run_no,
      'message','Teacher compensation run prepared and submitted for independent approval.',
      'total',compensation.total_amount
    );

  elsif action='DECIDE_COMPENSATION' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation approval not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide compensation.'; end if;
    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    select * into compensation from public.teacher_compensation_runs
    where id=approval.entity_id::uuid for update;
    if decision='APPROVED' and exists(select 1 from public.teacher_compensation_runs prior
      where prior.organization_id=compensation.organization_id and prior.id<>compensation.id
        and prior.status in ('APPROVED','SETTLED')
        and daterange(prior.period_start,prior.period_end,'[]') &&
            daterange(compensation.period_start,compensation.period_end,'[]')) then
      raise exception 'A compensation run already covers this period.';
    end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    if decision='APPROVED' then
      -- Claim every earning source atomically before making obligations.
      insert into public.teacher_compensation_claims(teacher_id,source_type,source_id,line_id,run_id)
      select l.teacher_id,l.source_type,l.source_id,l.id,l.run_id
      from public.teacher_compensation_lines l where l.run_id=compensation.id;
      for v_teacher in
        select distinct l.teacher_id from public.teacher_compensation_lines l
        where l.run_id=compensation.id
      loop
        select coalesce(sum(l.amount),0) into amount
        from public.teacher_compensation_lines l
        where l.run_id=compensation.id and l.teacher_id=v_teacher;
        if amount>0 then
          insert into public.finance_payables(
            organization_id,payable_type,staff_id,source_type,source_id,
            payable_account_id,original_amount,due_on,created_by
          ) values(
            compensation.organization_id,'TEACHER_COMPENSATION',v_teacher,
            'COMPENSATION_RUN',compensation.id::text||':'||v_teacher::text,
            (select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            amount,compensation.period_end,actor
          );
        end if;
      end loop;

      perform public.finance_post_journal(
        compensation.organization_id,compensation.period_end,
        'COMPENSATION_RUN','COMPENSATION_RUN',compensation.id::text,
        'Teacher compensation run '||compensation.run_no,actor,
        (
          select jsonb_build_array(
            jsonb_build_object(
              'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHING_COMPENSATION' limit 1),
              'debit',compensation.total_amount,'credit',0,
              'memo','Teaching compensation expense'
            )
          ) ||
          coalesce((
            select jsonb_agg(jsonb_build_object(
              'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
              'debit',0,'credit',totals.amount,
              'memo','Payable for teacher '||totals.teacher_id::text
            ))
            from (select l.teacher_id,sum(l.amount) amount
              from public.teacher_compensation_lines l
              where l.run_id=compensation.id group by l.teacher_id) totals
          ),'[]'::jsonb)
        )
      );
      update public.teacher_compensation_runs
      set status='APPROVED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    else
      update public.teacher_compensation_runs
      set status='REJECTED',approved_by=actor,approved_at=now()
      where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',compensation.id,'message','Compensation run '||lower(decision)||'.');

  elsif action='SETTLE_COMPENSATION' then
    select * into compensation from public.teacher_compensation_runs
    where id=(p_input->>'run_id')::uuid and status='APPROVED' for update;
    if compensation.id is null then raise exception 'Only an approved compensation run can be settled.'; end if;

    teacher_id:=(p_input->>'teacher_id')::uuid;
    select * into payable from public.finance_payables
    where source_type='COMPENSATION_RUN'
      and source_id=compensation.id::text||':'||teacher_id::text
      and staff_id=teacher_id
    for update;
    if payable.id is null then raise exception 'Teacher payable not found.'; end if;

    amount:=payable.original_amount-coalesce((
      select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=payable.id
    ),0);
    if amount<=0 then raise exception 'Teacher payable is already settled.'; end if;

    advance_offset:=coalesce((p_input->>'advance_offset')::numeric,0);
    if advance_offset<0 or advance_offset>amount then raise exception 'Advance offset is outside the payable balance.'; end if;

    if advance_offset>0 then
      select * into advance_row
      from (
        select adv.*,public.advance_balance(adv.id) balance
        from public.finance_advances adv
        where adv.staff_id=teacher_id
          and adv.beneficiary_type='STAFF'
          and public.advance_balance(adv.id)>0
          and adv.status in('PAID','PARTIALLY_SETTLED','OVERDUE')
        order by adv.expected_settlement_date nulls last,adv.created_at
      ) q
      limit 1 for update;

      if advance_row.id is null or advance_row.balance<advance_offset then
        raise exception 'Requested advance offset exceeds available teacher advance balance.';
      end if;
    end if;

    cash_paid:=amount-advance_offset;
    if cash_paid>0 then
      select id into payment_account
      from public.finance_accounts
      where id=(p_input->>'payment_account_id')::uuid
        and organization_id=compensation.organization_id
        and account_subtype in('CASH','BANK','MOBILE_BANK')
        and is_active;
      if payment_account is null then raise exception 'Choose an active cash or bank account.'; end if;
    end if;

    insert into public.teacher_compensation_settlements(
      run_id,teacher_id,payable_id,gross_amount,advance_offset,cash_paid,
      payment_account_id,external_reference,settled_by,reason
    )
    values(
      compensation.id,teacher_id,payable.id,amount,advance_offset,cash_paid,
      payment_account,nullif(btrim(p_input->>'external_reference'),''),
      actor,reason
    )
    returning id into settlement;

    if advance_offset>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_SETTLEMENT',settlement.id::text,
        'Teacher compensation advance offset',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',advance_offset,'credit',0
          ),
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='STAFF_ADVANCE' limit 1),
            'debit',0,'credit',advance_offset
          )
        )
      );
      insert into public.finance_advance_movements(
        advance_id,movement_type,amount,source_type,source_id,payable_id,created_by,reason
      )
      values(
        advance_row.id,'SETTLEMENT',advance_offset,
        'COMPENSATION_SETTLEMENT',settlement.id::text,payable.id,actor,reason
      );
    end if;

    if cash_paid>0 then
      perform public.finance_post_journal(
        compensation.organization_id,current_date,'COMPENSATION_SETTLEMENT',
        'COMPENSATION_CASH_SETTLEMENT',settlement.id::text,
        'Teacher compensation cash settlement',actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',(select id from public.finance_accounts where organization_id=compensation.organization_id and account_subtype='TEACHER_PAYABLE' limit 1),
            'debit',cash_paid,'credit',0
          ),
          jsonb_build_object(
            'account_id',payment_account,'debit',0,'credit',cash_paid
          )
        )
      );
    end if;

    if advance_offset>0 then
      insert into public.finance_payable_settlements(
        payable_id,amount,advance_id,settled_by,reason
      ) values(payable.id,advance_offset,advance_row.id,actor,reason);
    end if;
    if cash_paid>0 then
      insert into public.finance_payable_settlements(
        payable_id,amount,payment_account_id,external_reference,settled_by,reason
      ) values(payable.id,cash_paid,payment_account,
        nullif(btrim(p_input->>'external_reference'),''),actor,reason);
    end if;

    update public.finance_payables p
    set status=case
      when coalesce((select sum(s.amount) from public.finance_payable_settlements s where s.payable_id=p.id),0)>=p.original_amount
      then 'SETTLED' else 'PARTIALLY_SETTLED' end
    where p.id=payable.id;

    if not exists(
      select 1 from public.finance_payables
      where source_type='COMPENSATION_RUN'
        and source_id like compensation.id::text||':%'
        and status<>'SETTLED'
    ) then
      update public.teacher_compensation_runs set status='SETTLED' where id=compensation.id;
    end if;

    result:=jsonb_build_object('id',settlement.id,'message','Teacher compensation settlement posted.');
  
  elsif action='REQUEST_COMP_ADJUSTMENT' then
    if not exists(select 1 from public.staff where id=(p_input->>'teacher_id')::uuid and status='ACTIVE') then
      raise exception 'Choose an active teacher.';
    end if;
    amount:=(p_input->>'amount')::numeric;
    if amount is null or amount<=0 then raise exception 'Adjustment amount must be positive.'; end if;

    insert into public.teacher_compensation_adjustments(
      teacher_id,amount,adjustment_type,effective_period,reason,requested_by
    )
    values(
      (p_input->>'teacher_id')::uuid,amount,
      coalesce(p_input->>'adjustment_type','ADJUSTMENT'),
      (p_input->>'effective_period')::date,reason,actor
    )
    returning id into settlement_id;

    insert into public.approval_requests(
      workflow_type,entity_type,entity_id,requested_action,payload_snapshot,
      request_note,requested_by,correlation_id
    )
    values('COMPENSATION_ADJUSTMENT','TEACHER_COMPENSATION_ADJUSTMENT',settlement_id::text,
      action,p_input,reason,actor,req)
    returning id into approval;

    update public.teacher_compensation_adjustments
    set approval_id=approval.id
    where id=settlement_id;

    result:=jsonb_build_object('id',settlement_id,'message','Compensation adjustment submitted for approval.');

  elsif action='DECIDE_COMP_ADJUSTMENT' then
    select * into approval from public.approval_requests
    where id=(p_input->>'approval_id')::uuid and workflow_type='COMPENSATION_ADJUSTMENT'
    for update;
    if approval.id is null or approval.status<>'PENDING' then raise exception 'Pending compensation adjustment not found.'; end if;
    if approval.requested_by=actor then raise exception 'Maker-checker: another authorized person must decide the adjustment.'; end if;

    decision:=p_input->>'decision';
    if decision not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;

    update public.approval_requests
    set status=decision::public.approval_status,decided_by=actor,decided_at=now(),decision_note=reason
    where id=approval.id;

    update public.teacher_compensation_adjustments
    set status=case when decision='APPROVED' then 'APPROVED' else 'REJECTED' end,
        approved_by=actor,approved_at=now()
    where id=approval.entity_id::uuid;

    result:=jsonb_build_object('id',approval.entity_id,'message','Compensation adjustment '||lower(decision)||'.');

  else
    raise exception 'Unsupported accounting action.';
  end if;

  insert into public.audit_events(
    correlation_id,actor_profile_id,actor_staff_id,entity_type,entity_id,action,reason,after_data,metadata
  )
  values(
    req,actor,(select id from public.staff where profile_id=actor limit 1),
    'FINANCE_ACCOUNTING',coalesce(result->>'id',req::text),action,reason,result,p_input
  );

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(req,actor,p_input,result);

  return result;
end;
$$;




-- ============================================================
-- SOURCE: 0045_v2_admission_referral_compensation.sql
-- ============================================================

-- Admission referral capture and independently approved external acquisition reward.
create table public.referral_people (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  staff_id uuid unique references public.staff(id),
  full_name text not null check(length(btrim(full_name))>=2),
  mobile text,
  relationship_note text,
  contact_note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check(staff_id is not null or mobile ~ '^01[3-9][0-9]{8}$'),
  unique(organization_id,mobile)
);
create table public.admission_referrals (
  admission_id uuid primary key references public.admission_cases(id),
  source text not null check(source in('ORGANIC','REFERRED')),
  referrer_id uuid references public.referral_people(id),
  captured_by uuid not null references public.profiles(id),
  captured_at timestamptz not null default now(),
  reason text not null,
  check((source='ORGANIC' and referrer_id is null) or
        (source='REFERRED' and referrer_id is not null))
);
create table public.referral_bonus_awards (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admission_cases(id),
  referrer_id uuid not null references public.referral_people(id),
  period_start date not null,
  net_collected numeric(14,2) not null check(net_collected>0),
  policy_version_id uuid not null references public.business_rule_versions(id),
  bonus_percent numeric(7,3) not null check(bonus_percent>=0),
  amount numeric(14,2) not null check(amount>0),
  status text not null default 'PENDING' check(status in('PENDING','APPROVED','REJECTED')),
  approval_id uuid not null unique references public.approval_requests(id),
  payable_id uuid unique references public.finance_payables(id),
  requested_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create unique index referral_bonus_one_live_award on public.referral_bonus_awards(admission_id)
  where status in('PENDING','APPROVED');
alter table public.finance_payables add column referrer_id uuid references public.referral_people(id);
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'2130','Referral Reward Payable','LIABILITY','REFERRER_PAYABLE',true from public.organizations
on conflict(organization_id,code) do nothing;
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account)
select id,'5200','Student Acquisition Expense','EXPENSE','ACQUISITION_EXPENSE',true from public.organizations
on conflict(organization_id,code) do nothing;

alter table public.referral_people enable row level security;
alter table public.admission_referrals enable row level security;
alter table public.referral_bonus_awards enable row level security;
grant select on public.referral_people,public.admission_referrals,public.referral_bonus_awards to authenticated;
revoke insert,update,delete on public.referral_people,public.admission_referrals,public.referral_bonus_awards from anon,authenticated;
create policy referral_people_read on public.referral_people for select to authenticated
  using(public.has_permission('admissions.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));
create policy admission_referrals_read on public.admission_referrals for select to authenticated
  using(public.has_permission('admissions.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));
create policy referral_bonus_awards_read on public.referral_bonus_awards for select to authenticated
  using(public.has_permission('staff.compensation.view') or public.has_permission('finance.view') or public.has_permission('accounting.view'));

-- Preserve previously recorded teacher referrals and mark all historical
-- admissions without one as Organic. Existing financial history is untouched.
insert into public.referral_people(organization_id,staff_id,full_name,mobile,created_by)
select o.id,s.id,s.full_name,null,tr.captured_by
from public.teacher_referrals tr join public.staff s on s.id=tr.teacher_id
cross join lateral (select id from public.organizations where code='SOHOJ' limit 1) o
on conflict(staff_id) do nothing;
insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
select a.id,case when tr.id is null then 'ORGANIC' else 'REFERRED' end,
 rp.id,coalesce(tr.captured_by,a.created_by),'Historical referral classification'
from public.admission_cases a left join public.teacher_referrals tr on tr.admission_id=a.id
left join public.referral_people rp on rp.staff_id=tr.teacher_id
where a.status not in('DRAFT','READY') and coalesce(tr.captured_by,a.created_by) is not null
on conflict(admission_id) do nothing;

-- Keep the referral decision explicit before an admission is accepted.
create function public.require_admission_referral_choice() returns trigger language plpgsql
set search_path=public as $$
begin
 if new.status='ACCEPTED' and old.status is distinct from new.status and
    not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
   raise exception 'Record a referrer or select Organic before accepting this admission.';
 end if;
 return new;
end $$;
create trigger admission_referral_choice_gate before update of status on public.admission_cases
 for each row execute function public.require_admission_referral_choice();
revoke execute on function public.require_admission_referral_choice() from public,anon,authenticated;

create function public.teacher_referral_matches_admission() returns trigger language plpgsql
set search_path=public as $$
begin
 if not exists(select 1 from public.admission_referrals ar
   join public.referral_people rp on rp.id=ar.referrer_id
   where ar.admission_id=new.admission_id and ar.source='REFERRED' and rp.staff_id=new.teacher_id) then
  raise exception 'Teacher referral must match the verified admission referral.';
 end if;
 return new;
end $$;
create trigger teacher_referral_match before insert or update on public.teacher_referrals
 for each row execute function public.teacher_referral_matches_admission();
revoke execute on function public.teacher_referral_matches_admission() from public,anon,authenticated;

create function public.referral_command(p_input jsonb) returns jsonb language plpgsql security definer
set search_path=public as $$
declare
 actor uuid:=auth.uid();
 action text:=p_input->>'action';
 req uuid:=nullif(p_input->>'request_id','')::uuid;
 reason text:=btrim(coalesce(p_input->>'reason',''));
 k public.admission_command_keys;
 a public.admission_cases;
 person public.referral_people;
 referral public.admission_referrals;
 award public.referral_bonus_awards;
 approval public.approval_requests;
 policy public.business_rule_versions;
 org uuid;
 first_month date;
 collected numeric;
 rate numeric;
 amount numeric;
 payable public.finance_payables;
 result jsonb;
begin
 if actor is null or req is null or length(reason)<5 then raise exception 'Sign in and provide a request ID and reason.'; end if;
 if action='CAPTURE' and not public.has_permission('admissions.create') or
    action='REQUEST_BONUS' and not public.has_permission('staff.compensation.manage') or
    action='DECIDE_BONUS' and not public.has_permission('staff.compensation.approve') or
    action not in('CAPTURE','REQUEST_BONUS','DECIDE_BONUS') then
   raise exception 'Permission denied for this referral action.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,7));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>actor or k.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
  return k.result;
 end if;
 if action='CAPTURE' then
  select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  if a.id is null or a.status not in('DRAFT','READY') then
   raise exception 'Referral choice must be recorded before admission acceptance.'; end if;
  select id into org from public.organizations where code='SOHOJ' and is_active;
  if p_input->>'source'='ORGANIC' then
   insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
   values(a.id,'ORGANIC',null,actor,reason)
   on conflict(admission_id) do update set source='ORGANIC',referrer_id=null,captured_by=actor,captured_at=now(),reason=excluded.reason;
   delete from public.teacher_referrals where admission_id=a.id;
  elsif p_input->>'source'='REFERRED' then
   if nullif(p_input->>'staff_id','') is not null then
    if not exists(select 1 from public.staff where id=(p_input->>'staff_id')::uuid and status='ACTIVE') then
      raise exception 'Choose an active staff member.'; end if;
    insert into public.referral_people(organization_id,staff_id,full_name,mobile,created_by)
      select org,id,full_name,null,actor from public.staff where id=(p_input->>'staff_id')::uuid
    on conflict(staff_id) do update set full_name=excluded.full_name
    returning * into person;
   elsif nullif(p_input->>'referrer_id','') is not null then
    select * into person from public.referral_people
     where id=(p_input->>'referrer_id')::uuid and organization_id=org;
    if person.id is null then raise exception 'Choose an existing referrer.'; end if;
   else
    if length(btrim(coalesce(p_input->>'full_name','')))<2 or
       coalesce(p_input->>'mobile','') !~ '^01[3-9][0-9]{8}$' then
      raise exception 'Enter the new referrer name and an 11-digit Bangladesh mobile.';
    end if;
    insert into public.referral_people(organization_id,staff_id,full_name,mobile,relationship_note,contact_note,created_by)
    values(org,null,btrim(p_input->>'full_name'),p_input->>'mobile',
      nullif(btrim(p_input->>'relationship_note'),''),nullif(btrim(p_input->>'contact_note'),''),actor)
    on conflict(organization_id,mobile) do update set
      full_name=public.referral_people.full_name
    returning * into person;
    if lower(btrim(person.full_name))<>lower(btrim(p_input->>'full_name')) then
      raise exception 'A different referrer already uses this mobile. Select the existing record or verify identity.';
    end if;
   end if;
   insert into public.admission_referrals(admission_id,source,referrer_id,captured_by,reason)
   values(a.id,'REFERRED',person.id,actor,reason)
   on conflict(admission_id) do update set source='REFERRED',referrer_id=excluded.referrer_id,
      captured_by=actor,captured_at=now(),reason=excluded.reason;
   if person.staff_id is not null and exists(select 1 from public.staff_role_assignments sra
      join public.staff_roles sr on sr.id=sra.staff_role_id
      where sra.staff_id=person.staff_id and sr.is_teaching_role) then
     insert into public.teacher_referrals(admission_id,teacher_id,captured_by,reason)
     values(a.id,person.staff_id,actor,reason)
     on conflict(admission_id) do update set teacher_id=excluded.teacher_id,captured_by=actor,captured_at=now(),reason=excluded.reason;
   else
     delete from public.teacher_referrals where admission_id=a.id;
   end if;
  else raise exception 'Select an existing or new referrer, or Organic.'; end if;
  result:=jsonb_build_object('id',a.id,'message','Admission referral choice saved.');
 elsif action='REQUEST_BONUS' then
  select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  select * into referral from public.admission_referrals where admission_id=a.id;
  select * into person from public.referral_people where id=referral.referrer_id;
  if a.id is null or a.status<>'ACTIVE_ENROLLMENT' or referral.source<>'REFERRED'
    or person.id is null or person.staff_id is not null then
    raise exception 'Choose an active admission with an external referrer.'; end if;
  if exists(select 1 from public.referral_bonus_awards where admission_id=a.id and status in('PENDING','APPROVED')) then
   raise exception 'The referral reward is already requested or approved.'; end if;
  select min(n.billing_period) into first_month from public.finance_net_collected_tuition(date '2000-01-01',current_date) n
   where n.admission_id=a.id and n.tuition_collected>0;
  if first_month is null then raise exception 'No posted tuition collection qualifies for an acquisition reward.'; end if;
  select coalesce(sum(n.tuition_collected),0) into collected from public.finance_net_collected_tuition(first_month,(first_month+interval '1 month - 1 day')::date) n
   where n.admission_id=a.id;
  if collected<=0 then raise exception 'First-month net collected tuition is not positive.'; end if;
  select * into policy from public.business_rule_versions where domain='teacher_compensation'
   and rule_key='default_policy' and status='ACTIVE' order by version desc limit 1;
  if policy.id is null or not public.validate_business_rule_payload('teacher_compensation','default_policy',policy.payload) then
   raise exception 'Configure a valid acquisition compensation policy first.'; end if;
  rate:=(policy.payload->>'acquisition_bonus_percent')::numeric;
  amount:=round(collected*rate/100,2);
  if amount<=0 then raise exception 'The reward would be zero under the current policy.'; end if;
  select id into org from public.organizations where code='SOHOJ' and is_active;
  insert into public.approval_requests(workflow_type,entity_type,entity_id,requested_action,payload_snapshot,request_note,requested_by,correlation_id)
   values('REFERRAL_BONUS','ADMISSION',a.id::text,'REQUEST_BONUS',
      jsonb_build_object('admission_id',a.id,'referrer_id',person.id,'period_start',first_month,'net_collected',collected,'policy_version_id',policy.id,'bonus_percent',rate,'amount',amount),
      reason,actor,req) returning * into approval;
  insert into public.referral_bonus_awards(admission_id,referrer_id,period_start,net_collected,policy_version_id,
      bonus_percent,amount,approval_id,requested_by)
   values(a.id,person.id,first_month,collected,policy.id,rate,amount,approval.id,actor)
   returning * into award;
  result:=jsonb_build_object('id',award.id,'message','Referral reward submitted for independent approval.');
 else
  select * into approval from public.approval_requests where id=(p_input->>'approval_id')::uuid
    and workflow_type='REFERRAL_BONUS' and status='PENDING' for update;
  if approval.id is null or approval.requested_by=actor then
    raise exception 'A different authorized staff member must review the pending reward.'; end if;
  select * into award from public.referral_bonus_awards where approval_id=approval.id for update;
  if p_input->>'decision' not in('APPROVED','REJECTED') then raise exception 'Choose Approve or Reject.'; end if;
  if p_input->>'decision'='APPROVED' then
   select * into a from public.admission_cases where id=award.admission_id for update;
   select * into referral from public.admission_referrals where admission_id=a.id;
   if a.status<>'ACTIVE_ENROLLMENT' or referral.referrer_id<>award.referrer_id or
      exists(select 1 from public.finance_payables where source_type='REFERRAL_BONUS' and source_id=a.id::text) then
      raise exception 'Admission or referral changed; review this reward again.'; end if;
   select coalesce(sum(n.tuition_collected),0) into collected
    from public.finance_net_collected_tuition(award.period_start,(award.period_start+interval '1 month - 1 day')::date) n
    where n.admission_id=a.id;
   if collected<award.net_collected then
     raise exception 'Net collected tuition decreased after the request; reject and recalculate the reward.';
   end if;
   select id into org from public.organizations where code='SOHOJ' and is_active;
   insert into public.finance_payables(organization_id,payable_type,referrer_id,source_type,source_id,payable_account_id,
     original_amount,due_on,created_by)
   values(org,'OTHER',award.referrer_id,'REFERRAL_BONUS',a.id::text,
     (select id from public.finance_accounts where organization_id=org and code='2130'),award.amount,current_date,actor)
   returning * into payable;
   perform public.finance_post_journal(org,current_date,'COMPENSATION_RUN','REFERRAL_BONUS',award.id::text,
      'Approved referral acquisition reward',actor,jsonb_build_array(
       jsonb_build_object('account_id',(select id from public.finance_accounts where organization_id=org and code='5200'),'debit',award.amount,'credit',0),
       jsonb_build_object('account_id',payable.payable_account_id,'debit',0,'credit',award.amount)));
   update public.referral_bonus_awards set status='APPROVED',payable_id=payable.id,
     reviewed_by=actor,reviewed_at=now() where id=award.id;
  else
   update public.referral_bonus_awards set status='REJECTED',reviewed_by=actor,
      reviewed_at=now() where id=award.id;
  end if;
  update public.approval_requests set status=(p_input->>'decision')::public.approval_status,
    decided_by=actor,decided_at=now(),decision_note=reason where id=approval.id;
  result:=jsonb_build_object('id',award.id,'message','Referral reward reviewed.');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(req,actor,'ADMISSION_REFERRAL',result->>'id',action,reason,result,jsonb_build_object('module','referrals'));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end $$;
revoke execute on function public.referral_command(jsonb) from public,anon;
grant execute on function public.referral_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0046_v2_parallel_academic_years.sql
-- ============================================================

-- Academic years are explicit context, not a single global current-year switch.
-- An upcoming year can be prepared while the present year remains operational.
drop index if exists public.one_active_academic_year_per_org;

do $migration$
declare
  definition text;
  create_values text := 'values (v_org, v_name, v_starts, v_ends, false)';
  exclusive_update text := $block$      if v_is_active then
        update public.academic_years set is_active = false
        where organization_id = v_org and id <> v_id and is_active;
      end if;
$block$;
begin
  select pg_get_functiondef('public.manage_crm_master_record(jsonb)'::regprocedure)
    into definition;
  if position(create_values in definition)=0 or position(exclusive_update in definition)=0 then
    raise exception 'Cannot revise academic year management: expected function structure changed.';
  end if;
  definition:=replace(definition,create_values,
    'values (v_org, v_name, v_starts, v_ends, v_is_active)');
  definition:=replace(definition,exclusive_update,'');
  execute definition;
end;
$migration$;



-- ============================================================
-- SOURCE: 0047_v2_batch_register_management.sql
-- ============================================================

-- Batch register read model and audited create/edit workflow.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,'classId',b.class_id,'capacity',b.capacity,'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE'))) from public.batches b where b.is_active and b.offering_id is not null),'[]'::jsonb),$old$;
  new_block := $new$'batches',coalesce((select jsonb_agg(jsonb_build_object(
    'id',b.id,'name',b.name,'code',b.code,'offeringId',b.offering_id,
    'offeringName',o.name,'classId',b.class_id,'className',c.name,
    'yearName',y.name,'branchName',br.name,'capacity',b.capacity,
    'isActive',b.is_active,
    'occupied',(select count(*) from public.enrollments e where e.batch_id=b.id and e.status='ACTIVE')
  ) order by y.starts_on desc,o.name,b.name)
    from public.batches b
    join public.programme_offerings o on o.id=b.offering_id
    join public.classes c on c.id=b.class_id
    join public.academic_years y on y.id=b.academic_year_id
    left join public.branches br on br.id=b.branch_id
  ),'[]'::jsonb),$new$;
  if position(old_block in definition)=0 then
    raise exception 'Cannot update batch register read model; expected definition changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

create or replace function public.batch_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid(); req uuid:=nullif(p_input->>'request_id','')::uuid;
 action text:=p_input->>'action'; reason text:=btrim(coalesce(p_input->>'reason',''));
 key public.admission_command_keys; org uuid; batch public.batches;
 offering public.programme_offerings; policy public.business_rule_versions;
 v_requested_capacity integer; occupied integer; before_data jsonb; result jsonb;
begin
 if actor is null or not public.has_permission('academics.manage') then
  raise exception 'Batch management permission required.';
 end if;
 if req is null or length(reason)<5 then raise exception 'Request identity and a reason of at least five characters are required.'; end if;
 if action not in('CREATE_BATCH','EDIT_BATCH') then raise exception 'Unsupported batch action.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;
 if found then
  if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
  return key.result;
 end if;
 select id into org from public.organizations where code='SOHOJ' and is_active limit 1;
 select * into policy from public.business_rule_versions where domain='academics'
   and rule_key='batch_capacity_policy' and status='ACTIVE' order by version desc limit 1;
 if org is null or policy.id is null then raise exception 'Organization or active capacity policy is unavailable.'; end if;
 v_requested_capacity:=nullif(p_input->>'capacity','')::integer;
 if v_requested_capacity is null or v_requested_capacity<1 or v_requested_capacity>(policy.payload->>'max_students')::integer then
   raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',policy.payload->>'max_students';
 end if;
 if length(btrim(coalesce(p_input->>'name','')))<2 or length(btrim(coalesce(p_input->>'code','')))<2 then
   raise exception 'Enter a batch code and a recognizable batch name.';
 end if;
 if action='CREATE_BATCH' then
  select * into offering from public.programme_offerings
   where id=(p_input->>'offering_id')::uuid and organization_id=org and status='ACTIVE' for update;
  if offering.id is null then raise exception 'Choose an active offering with a published Fee Plan.'; end if;
  insert into public.batches(organization_id,branch_id,academic_year_id,class_id,program_id,
   code,name,capacity,created_by,offering_id,capacity_policy_version_id)
  values(org,offering.branch_id,offering.academic_year_id,offering.class_id,offering.program_id,
   upper(btrim(p_input->>'code')),btrim(p_input->>'name'),v_requested_capacity,actor,offering.id,policy.id)
  returning * into batch;
  result:=jsonb_build_object('id',batch.id,'status','CREATED');
 else
  select * into batch from public.batches where id=(p_input->>'batch_id')::uuid
    and organization_id=org and offering_id is not null for update;
  if batch.id is null then raise exception 'Batch not found.'; end if;
  before_data:=to_jsonb(batch);
  select count(*) into occupied from public.enrollments where batch_id=batch.id and status='ACTIVE';
  if v_requested_capacity<occupied then raise exception 'Capacity cannot be lower than the % students already enrolled.',occupied; end if;
  update public.batches b set code=upper(btrim(p_input->>'code')),
    name=btrim(p_input->>'name'),capacity=v_requested_capacity,
    capacity_policy_version_id=policy.id,updated_at=now()
  where b.id=batch.id returning b.* into batch;
  result:=jsonb_build_object('id',batch.id,'status','UPDATED');
 end if;
 insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
   entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(req,actor,(select id from public.staff where profile_id=actor limit 1),
   'BATCH',batch.id::text,action,reason,
   before_data,
   to_jsonb(batch),jsonb_build_object('module','batch_register','offering_id',batch.offering_id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result)
 values(req,actor,p_input,result);
 return result;
end $$;
revoke all on function public.batch_command(jsonb) from public,anon;
grant execute on function public.batch_command(jsonb) to authenticated;

do $migration$
declare definition text; anchor text; guard text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  anchor := $anchor$if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;$anchor$;
  guard := $guard$if v_capacity.id is null then raise exception 'Capacity policy is missing.'; end if;
   if coalesce((p_input->>'capacity')::integer,0)<1
      or (p_input->>'capacity')::integer>(v_capacity.payload->>'max_students')::integer then
     raise exception 'Batch capacity must be between 1 and the active policy maximum (%).',v_capacity.payload->>'max_students';
   end if;$guard$;
  if position(anchor in definition)=0 then raise exception 'Cannot enforce batch capacity in admission command; expected guard changed.'; end if;
  execute replace(definition,anchor,guard);
end;
$migration$;



-- ============================================================
-- SOURCE: 0048_v2_offering_edit_workflow.sql
-- ============================================================

-- Audited, lifecycle-aware Programme Offering updates.
create or replace function public.update_programme_offering(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
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
  if v_row.status='RETIRED' then raise exception 'Retired offerings are read-only.'; end if;
  v_before:=to_jsonb(v_row);
  if v_row.status='ACTIVE' and (
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
end $$;
revoke all on function public.update_programme_offering(jsonb) from public,anon;
grant execute on function public.update_programme_offering(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0049_v2_admission_intake_and_batch_eligibility.sql
-- ============================================================

-- Clear staff-assisted intake, preserve full application particulars, and make
-- a Prospect's recorded offering the source of batch eligibility.
alter table public.prospects
  add column if not exists date_of_birth date,
  add column if not exists gender text,
  add column if not exists school_roll text,
  add column if not exists guardian_address text;

comment on column public.prospects.guardian_address is
  'Guardian address collected during staff-assisted or public admission intake.';

create table if not exists public.staff_admission_intake_requests (
  request_id uuid primary key,
  actor_id uuid not null references public.profiles(id),
  payload jsonb not null,
  prospect_id uuid not null references public.prospects(id),
  admission_id uuid not null references public.admission_cases(id),
  created_at timestamptz not null default now()
);
alter table public.staff_admission_intake_requests enable row level security;
revoke all on public.staff_admission_intake_requests from public, anon, authenticated;

-- Add the recorded offering to the admission workspace contract.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,$old$;
  new_block := $new$'prospects',case when v_view then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.student_name,'number',p.prospect_no,'classId',p.current_class_id,'interestedOfferingId',p.interested_offering_id,'guardian',p.guardian_name,'mobile',p.mobile)) from public.prospects p where p.status not in ('CONVERTED','LOST') and not exists(select 1 from public.admission_cases a where a.prospect_id=p.id and a.status<>'CANCELLED')),'[]'::jsonb) else '[]'::jsonb end,$new$;
  if position(old_block in definition)=0 then
    if position('interestedOfferingId' in definition)>0 then return; end if;
    raise exception 'Cannot add Prospect offering to admission workspace; expected contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Offer only choices for which a currently effective published Fee Plan exists.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'classId',o.class_id,'className',c.name)) from public.programme_offerings o join public.classes c on c.id=o.class_id where o.status='ACTIVE'),'[]'::jsonb),$old$;
  new_block := $new$'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name,'code',o.code,
      'classId',o.class_id,'className',c.name,'yearName',ay.name,'branchName',br.name))
    from public.programme_offerings o join public.classes c on c.id=o.class_id
    join public.academic_years ay on ay.id=o.academic_year_id left join public.branches br on br.id=o.branch_id
    join public.organizations org on org.id=o.organization_id
    where o.status='ACTIVE' and exists(select 1 from public.fee_plan_versions f
      where f.offering_id=o.id and f.status='ACTIVE'
        and f.effective_from<=timezone(org.timezone,now())::date)),'[]'::jsonb),$new$;
  if position(old_block in definition)=0 then
    if position('f.effective_from<=timezone(org.timezone,now())::date' in definition)>0 then return; end if;
    raise exception 'Cannot scope admission offerings to effective Fee Plans; expected workspace contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Expose the complete consent/application particulars in the permission-scoped
-- case read model so the case-specific printable form reflects the intake.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_workspace()'::regprocedure) into definition;
  old_block := $old$'name',a.identity_snapshot->>'student_name','guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',$old$;
  new_block := $new$'name',a.identity_snapshot->>'student_name','nameBn',a.identity_snapshot->>'student_name_bn',
      'gender',a.identity_snapshot->>'gender','dateOfBirth',a.identity_snapshot->>'date_of_birth',
      'schoolName',a.identity_snapshot->>'school_name','schoolRoll',a.identity_snapshot->>'school_roll',
      'guardianAddress',a.identity_snapshot->>'guardian_address','alternateMobile',a.identity_snapshot->>'alternate_mobile',
      'guardianRelationship',a.identity_snapshot->>'guardian_relationship',
      'guardian',a.identity_snapshot->>'guardian_name','mobile',a.identity_snapshot->>'mobile',$new$;
  if position(old_block in definition)=0 then
    if position('guardianAddress' in definition)>0 then return; end if;
    raise exception 'Cannot add application details to the admission read model; expected case contract changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Pin the captured application details in every newly created admission case,
-- including public applications already held in the CRM review queue.
do $migration$
declare definition text; old_block text; new_block text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  old_block := $old$'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot),v_actor)$old$;
  new_block := $new$'school_id',v_prospect.school_id,'school_name',v_prospect.school_name_snapshot,
     'student_name_bn',v_prospect.student_name_bn,'gender',v_prospect.gender,
     'date_of_birth',v_prospect.date_of_birth,'school_roll',v_prospect.school_roll,
     'alternate_mobile',v_prospect.alternate_mobile,
     'guardian_address',coalesce(v_prospect.guardian_address,
       (select pa.guardian_address from public.public_admission_applications pa where pa.prospect_id=v_prospect.id)),
     'guardian_relationship',coalesce(v_prospect.guardian_relationship_snapshot,'Guardian')),v_actor)$new$;
  if position(old_block in definition)=0 then
    if position('public_admission_applications pa where pa.prospect_id=v_prospect.id' in definition)>0 then return; end if;
    raise exception 'Cannot preserve applicant details in the admission snapshot; expected creation block changed.';
  end if;
  execute replace(definition,old_block,new_block);
end;
$migration$;

-- Existing Prospects without an assigned class can be admitted only when the
-- staff member explicitly chooses the Prospect's recorded active offering.
do $migration$
declare definition text; old_check text; new_check text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  old_check := $old$if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id or v_prospect.current_class_id is distinct from v_offering.class_id then
     raise exception 'Batch must match the Prospect class and an active offering.';
   end if;$old$;
  new_check := $new$if v_offering.id is null or v_prospect.organization_id<>v_offering.organization_id
     or v_batch.offering_id is distinct from nullif(p_input->>'offering_id','')::uuid
     or (v_prospect.current_class_id is not null and v_prospect.current_class_id is distinct from v_offering.class_id)
     or (v_prospect.current_class_id is null and v_prospect.interested_offering_id is not null
         and v_prospect.interested_offering_id is distinct from v_offering.id) then
     raise exception 'Choose an active offering and a batch that match this Prospect.';
   end if;
   if v_prospect.current_class_id is null then
     update public.prospects set current_class_id=v_offering.class_id where id=v_prospect.id;
     v_prospect.current_class_id:=v_offering.class_id;
     insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
       entity_type,entity_id,action,reason,before_data,after_data,metadata)
     values(v_request,v_actor,(select id from public.staff where profile_id=v_actor limit 1),
       'PROSPECT',v_prospect.id::text,'ASSIGN_CLASS_FROM_OFFERING',v_reason,
       jsonb_build_object('current_class_id',null,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('current_class_id',v_offering.class_id,'interested_offering_id',v_prospect.interested_offering_id),
       jsonb_build_object('offering_id',v_offering.id,'batch_id',v_batch.id));
   end if;$new$;
  if position(old_check in definition)=0 then
    if position('interested_offering_id is distinct from v_offering.id' in definition)>0 then return; end if;
    raise exception 'Cannot update Prospect batch eligibility; expected admission guard changed.';
  end if;
  execute replace(definition,old_check,new_check);
end;
$migration$;

-- Copy the detailed applicant record into the permanent Student row at the
-- acceptance transition. The admission case snapshot remains the audit source.
create or replace function public.sync_admission_student_details()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.student_id is not null and old.student_id is null then
    update public.students s set
      name_bn = p.student_name_bn,
      gender = p.gender,
      date_of_birth = p.date_of_birth,
      school_roll = p.school_roll
    from public.prospects p
    where p.id = new.prospect_id and s.id = new.student_id;
    update public.guardians g set
      alternate_mobile = coalesce(g.alternate_mobile,p.alternate_mobile),
      address = coalesce(g.address,p.guardian_address,
        (select pa.guardian_address from public.public_admission_applications pa where pa.prospect_id=p.id))
    from public.student_guardians sg, public.prospects p
    where sg.student_id=new.student_id and sg.guardian_id=g.id
      and p.id=new.prospect_id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_admission_student_details() from public, anon, authenticated;
drop trigger if exists admission_student_details_sync on public.admission_cases;
create trigger admission_student_details_sync
after update of student_id on public.admission_cases
for each row execute function public.sync_admission_student_details();

create or replace function public.create_staff_admission_intake(p_input jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  req uuid := nullif(p_input->>'request_id','')::uuid;
  reason text := btrim(coalesce(p_input->>'reason',''));
  existing public.staff_admission_intake_requests;
  offering public.programme_offerings;
  batch public.batches;
  organization public.organizations;
  prospect public.prospects;
  result jsonb;
  command_result jsonb;
  open_seats integer;
  local_today date;
  v_student_name text := btrim(coalesce(p_input->>'student_name',''));
  guardian_name text := btrim(coalesce(p_input->>'guardian_name',''));
  v_mobile text := regexp_replace(coalesce(p_input->>'mobile',''), '\D', '', 'g');
  birth_date date := nullif(p_input->>'date_of_birth','')::date;
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if req is null or length(reason)<5 then
    raise exception 'Request identity and an audit reason of at least five characters are required.';
  end if;
  if length(v_student_name)<2 or length(v_student_name)>160 or length(guardian_name)<2 or length(guardian_name)>160
    or v_mobile !~ '^01[3-9][0-9]{8}$' or length(btrim(coalesce(p_input->>'guardian_address','')))<5
    or coalesce((p_input->>'consent_to_contact')::boolean,false) is not true then
    raise exception 'Enter the student, guardian, valid mobile, address, and confirm permission to contact.';
  end if;
  if coalesce(p_input->>'gender','') not in ('','Female','Male','Other','Prefer not to say') then
    raise exception 'Choose a valid gender option or leave it blank.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,0));
  select * into existing from public.staff_admission_intake_requests where request_id=req;
  if found then
    if existing.actor_id<>actor or existing.payload<>p_input then
      raise exception 'Request identity was already used for different intake details.';
    end if;
    return jsonb_build_object('prospect_no',(select prospect_no from public.prospects where id=existing.prospect_id),
      'prospect_id',existing.prospect_id,'admission_id',existing.admission_id);
  end if;

  select * into offering from public.programme_offerings
    where id=nullif(p_input->>'offering_id','')::uuid and status='ACTIVE' for share;
  if offering.id is null then raise exception 'Choose an active programme offering.'; end if;
  select * into batch from public.batches
    where id=nullif(p_input->>'batch_id','')::uuid and is_active for update;
  if batch.id is null or batch.offering_id is distinct from offering.id then
    raise exception 'Choose an active batch belonging to the selected programme offering.';
  end if;
  select * into organization from public.organizations where id=offering.organization_id;
  select timezone(organization.timezone,now())::date into local_today;
  if not exists(select 1 from public.fee_plan_versions f where f.offering_id=offering.id
    and f.status='ACTIVE' and f.effective_from<=local_today) then
    raise exception 'Publish an effective Fee Plan for this offering before starting admission.';
  end if;
  select count(*) into open_seats from public.enrollments where batch_id=batch.id and status='ACTIVE';
  if open_seats>=least(batch.capacity,coalesce((select (payload->>'max_students')::integer
    from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE'
    order by version desc limit 1),batch.capacity)) then
    raise exception 'The selected batch is full. Choose another available batch.';
  end if;
  if exists(select 1 from public.prospects p where p.organization_id=offering.organization_id
    and regexp_replace(p.mobile,'\D','','g')=v_mobile and lower(btrim(p.student_name))=lower(v_student_name)
    and p.status not in ('CONVERTED','LOST')) then
    raise exception 'A matching open Prospect already exists. Open Prospects and continue that record instead of creating a duplicate.';
  end if;

  insert into public.prospects (
    organization_id,branch_id,student_name,student_name_bn,guardian_name,
    guardian_relationship_snapshot,mobile,alternate_mobile,current_class_id,
    school_name_snapshot,school_roll,date_of_birth,gender,guardian_address,
    interested_offering_id,referral_note,consent_to_contact,status,submitted_via
  ) values (
    offering.organization_id,offering.branch_id,v_student_name,
    nullif(btrim(coalesce(p_input->>'student_name_bn','')),''),guardian_name,
    nullif(btrim(coalesce(p_input->>'guardian_relationship','')),''),v_mobile,
    nullif(regexp_replace(coalesce(p_input->>'alternate_mobile',''),'\D','','g'),''),
    offering.class_id,nullif(btrim(coalesce(p_input->>'school_name','')),''),
    nullif(btrim(coalesce(p_input->>'school_roll','')),''),birth_date,
    nullif(p_input->>'gender',''),btrim(p_input->>'guardian_address'),offering.id,
    nullif(btrim(coalesce(p_input->>'referral_note','')),''),true,'NEW','ERP'
  ) returning * into prospect;

  command_result := public.admission_command(jsonb_build_object(
    'action','CREATE','request_id',gen_random_uuid(),'reason',reason,
    'prospect_id',prospect.id,'offering_id',offering.id,'batch_id',batch.id
  ));
  update public.admission_cases set identity_snapshot=identity_snapshot||jsonb_strip_nulls(jsonb_build_object(
    'student_name_bn',prospect.student_name_bn,'gender',prospect.gender,
    'date_of_birth',prospect.date_of_birth,'school_roll',prospect.school_roll,
    'guardian_address',prospect.guardian_address,'alternate_mobile',prospect.alternate_mobile,
    'guardian_relationship',prospect.guardian_relationship_snapshot
  )) where id=(command_result->>'id')::uuid;

  result := jsonb_build_object('prospect_no',prospect.prospect_no,'prospect_id',prospect.id,
    'admission_id',command_result->>'id');
  insert into public.audit_events(correlation_id,actor_profile_id,actor_staff_id,
    entity_type,entity_id,action,reason,before_data,after_data,metadata)
  values(req,actor,(select id from public.staff where profile_id=actor limit 1),
    'PROSPECT',prospect.id::text,'CREATE_STAFF_ADMISSION_INTAKE',reason,null,to_jsonb(prospect),
    jsonb_build_object('admission_id',command_result->>'id','offering_id',offering.id,'batch_id',batch.id));
  insert into public.staff_admission_intake_requests(request_id,actor_id,payload,prospect_id,admission_id)
  values(req,actor,p_input,prospect.id,(command_result->>'id')::uuid);
  return result;
end;
$$;
revoke all on function public.create_staff_admission_intake(jsonb) from public, anon;
grant execute on function public.create_staff_admission_intake(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0050_v2_physical_admission_consent.sql
-- ============================================================

-- Record paper consent receipt metadata without storing a scan or photograph.
create table public.admission_physical_consent_receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  request_payload jsonb not null,
  admission_id uuid not null references public.admission_cases(id),
  version integer not null check (version > 0),
  guardian_signed_on date not null,
  student_signed boolean not null default false,
  physical_copy_reference text,
  received_by uuid not null references public.profiles(id),
  received_at timestamptz not null default now(),
  reason text not null,
  unique (admission_id, version),
  check (physical_copy_reference is null or length(physical_copy_reference) <= 160),
  check (length(trim(reason)) >= 5)
);
create index admission_physical_consent_case_idx
  on public.admission_physical_consent_receipts(admission_id, version desc);
alter table public.admission_physical_consent_receipts enable row level security;
grant select on public.admission_physical_consent_receipts to authenticated;
revoke insert, update, delete on public.admission_physical_consent_receipts from public, anon, authenticated;
create policy admission_physical_consent_staff_read
  on public.admission_physical_consent_receipts for select to authenticated
  using (public.has_permission('admissions.view'));

create or replace function public.record_physical_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  actor uuid := auth.uid();
  c public.admission_cases;
  receipt public.admission_physical_consent_receipts;
  request_key uuid := (p_input->>'request_id')::uuid;
  admission_key uuid := (p_input->>'admission_id')::uuid;
  signed_on date := (p_input->>'guardian_signed_on')::date;
  local_today date;
  student_signed boolean := coalesce((p_input->>'student_signed')::boolean, false);
  reference text := nullif(trim(p_input->>'physical_copy_reference'), '');
  reason_text text := trim(coalesce(p_input->>'reason', ''));
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if request_key is null or admission_key is null then raise exception 'Invalid consent receipt request.'; end if;
  if signed_on is null then raise exception 'Enter a valid guardian signing date.'; end if;
  if length(reason_text) < 5 or length(reason_text) > 500 then raise exception 'Enter a staff note of 5 to 500 characters.'; end if;
  if reference is not null and length(reference) > 160 then raise exception 'Paper file location must be 160 characters or fewer.'; end if;

  perform pg_advisory_xact_lock(hashtextextended(request_key::text, 0));
  select * into receipt from public.admission_physical_consent_receipts where request_id=request_key;
  if receipt.id is not null then
    if receipt.received_by<>actor or receipt.request_payload<>p_input then
      raise exception 'This request ID was already used for another consent receipt.';
    end if;
    return jsonb_build_object('id',receipt.id,'version',receipt.version);
  end if;

  select * into c from public.admission_cases where id=admission_key for update;
  if c.id is null or c.status not in ('DRAFT','READY') then
    raise exception 'Paper consent can be received only before acceptance.';
  end if;
  select (now() at time zone o.timezone)::date into local_today
  from public.organizations o where o.id=c.organization_id;
  if signed_on > local_today then raise exception 'Guardian signing date cannot be in the future.'; end if;
  insert into public.admission_physical_consent_receipts(
    request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,
    physical_copy_reference,received_by,reason
  )
  values(
    request_key,p_input,c.id,
    (select coalesce(max(r.version),0)+1 from public.admission_physical_consent_receipts r where r.admission_id=c.id),
    signed_on,student_signed,reference,actor,reason_text
  ) returning * into receipt;

  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',receipt.id::text,'RECEIVE_PHYSICAL_SIGNED_FORM',to_jsonb(receipt));
  return jsonb_build_object('id',receipt.id,'version',receipt.version);
end $$;
revoke all on function public.record_physical_admission_consent(jsonb) from public, anon;
grant execute on function public.record_physical_admission_consent(jsonb) to authenticated;

-- Make a staff-recorded paper receipt satisfy the same transactional acceptance gate.
do $migration$
declare definition text; old_gate text; new_gate text;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure) into definition;
  if position('admission_physical_consent_receipts' in definition)>0 then return; end if;
  old_gate := $old$
      if v_case.consent_required and not exists (
        select 1 from public.admission_consent_documents d
        where d.admission_id = v_case.id
      ) then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;$old$;
  new_gate := $new$
      if v_case.consent_required
        and not exists (select 1 from public.admission_consent_documents d where d.admission_id = v_case.id)
        and not exists (select 1 from public.admission_physical_consent_receipts r where r.admission_id = v_case.id)
      then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;$new$;
  if position(old_gate in definition)=0 then
    raise exception 'Could not extend the admission consent gate; inspect admission_command before migrating.';
  end if;
  execute replace(definition,old_gate,new_gate);
end;
$migration$;



-- ============================================================
-- SOURCE: 0051_v2_admission_sequence_and_zero_value_ledger.sql
-- ============================================================

-- Keep the staff workflow sequential, allow late filing of physical consent,
-- and omit zero-value fee components from double-entry journals.

create or replace function public.finance_sync_invoice(p_invoice_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  i public.admission_invoices;
  a public.admission_cases;
  org uuid;
  ar uuid;
  other_revenue uuid;
  lines jsonb:='[]'::jsonb;
begin
  select * into i from public.admission_invoices where id=p_invoice_id;
  if i.id is null or i.total <= 0 then return null; end if;

  select * into a from public.admission_cases where id=i.admission_id;
  select organization_id into org from public.students where id=i.student_id;

  select id into ar from public.finance_accounts
  where organization_id=org and account_subtype='STUDENT_RECEIVABLE' and is_active limit 1;
  select id into other_revenue from public.finance_accounts
  where organization_id=org and account_subtype='OTHER_FEE_REVENUE' and is_active limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'account_id',coalesce(m.account_id,other_revenue),
      'debit',0,
      'credit',l.amount,
      'memo',l.name,
      'branch_id',b.branch_id,
      'program_id',b.program_id,
      'batch_id',b.id
    )
  ),'[]'::jsonb)
  into lines
  from public.admission_invoice_lines l
  left join public.finance_fee_revenue_map m
    on m.organization_id=org and m.charge_type=l.charge_type
  join public.admission_cases ac on ac.id=i.admission_id
  join public.batches b on b.id=ac.batch_id
  where l.invoice_id=i.id and l.amount>0;

  if jsonb_array_length(lines)=0 then
    raise exception 'A positive invoice has no positive charge lines.';
  end if;

  lines:=jsonb_build_array(
    jsonb_build_object(
      'account_id',ar,
      'debit',i.total,
      'credit',0,
      'memo','Student receivable'
    )
  ) || lines;

  return public.finance_post_journal(
    org,i.issued_on,
    'INVOICE','ADMISSION_INVOICE',i.id::text,
    'Invoice '||i.invoice_no,
    i.posted_by,lines
  );
end;
$$;

-- Old accepted cases may predate the physical receipt screen. Let staff append
-- the paper-receipt evidence later so those cases can rejoin the normal process.
create or replace function public.record_physical_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  actor uuid := auth.uid();
  c public.admission_cases;
  receipt public.admission_physical_consent_receipts;
  request_key uuid := (p_input->>'request_id')::uuid;
  admission_key uuid := (p_input->>'admission_id')::uuid;
  signed_on date := (p_input->>'guardian_signed_on')::date;
  local_today date;
  student_signed boolean := coalesce((p_input->>'student_signed')::boolean, false);
  reference text := nullif(trim(p_input->>'physical_copy_reference'), '');
  reason_text text := trim(coalesce(p_input->>'reason', ''));
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if request_key is null or admission_key is null then raise exception 'Invalid consent receipt request.'; end if;
  if signed_on is null then raise exception 'Enter a valid guardian signing date.'; end if;
  if length(reason_text) < 5 or length(reason_text) > 500 then raise exception 'Enter a staff note of 5 to 500 characters.'; end if;
  if reference is not null and length(reference) > 160 then raise exception 'Paper file location must be 160 characters or fewer.'; end if;

  perform pg_advisory_xact_lock(hashtextextended(request_key::text, 0));
  select * into receipt from public.admission_physical_consent_receipts where request_id=request_key;
  if receipt.id is not null then
    if receipt.received_by<>actor or receipt.request_payload<>p_input then
      raise exception 'This request ID was already used for another consent receipt.';
    end if;
    return jsonb_build_object('id',receipt.id,'version',receipt.version);
  end if;

  select * into c from public.admission_cases where id=admission_key for update;
  if c.id is null or c.status='CANCELLED' then
    raise exception 'Paper consent can be recorded only for an open admission case.';
  end if;
  if c.status='DRAFT' then
    raise exception 'Complete application verification before recording paper consent.';
  end if;
  if not exists(select 1 from public.admission_referrals r where r.admission_id=c.id) then
    raise exception 'Record the admission source before recording signed paper consent.';
  end if;
  select (now() at time zone o.timezone)::date into local_today
  from public.organizations o where o.id=c.organization_id;
  if signed_on > local_today then raise exception 'Guardian signing date cannot be in the future.'; end if;
  if exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=c.id) then
    raise exception 'A paper-consent receipt is already recorded for this case.';
  end if;

  insert into public.admission_physical_consent_receipts(
    request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,
    physical_copy_reference,received_by,reason
  )
  values(
    request_key,p_input,c.id,
    (select coalesce(max(r.version),0)+1 from public.admission_physical_consent_receipts r where r.admission_id=c.id),
    signed_on,student_signed,reference,actor,reason_text
  ) returning * into receipt;

  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',receipt.id::text,'RECEIVE_PHYSICAL_SIGNED_FORM',to_jsonb(receipt));
  return jsonb_build_object('id',receipt.id,'version',receipt.version);
end $$;
revoke all on function public.record_physical_admission_consent(jsonb) from public, anon;
grant execute on function public.record_physical_admission_consent(jsonb) to authenticated;

-- A missing referral can also be reconciled on a legacy accepted case, but a
-- captured source cannot be changed after acceptance or reward processing.
do $migration$
declare
  definition text;
  old_guard text := $$a.id is null or a.status not in('DRAFT','READY')$$;
  new_guard text := $$a.id is null or a.status='CANCELLED'
    or (a.status not in('DRAFT','READY') and exists(
      select 1 from public.admission_referrals prior where prior.admission_id=a.id
    ))$$;
begin
  select pg_get_functiondef('public.referral_command(jsonb)'::regprocedure) into definition;
  if position('public.admission_referrals prior where prior.admission_id=a.id' in definition)>0 then return; end if;
  if position(old_guard in definition)=0 then
    raise exception 'Could not enable referral reconciliation for legacy admissions.';
  end if;
  definition:=replace(definition,old_guard,new_guard);
  definition:=replace(definition,
    'Referral choice must be recorded before admission acceptance.',
    'A referral can be added to an accepted case only when no source is already on file.');
  execute definition;
end;
$migration$;

-- A case cannot reach billing or enrollment while the referral and signed
-- consent checklist is incomplete. This also covers direct RPC/database calls.
create or replace function public.require_admission_workflow_evidence()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status is distinct from old.status
    and new.status in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT') then
    if not exists(select 1 from public.admission_referrals r where r.admission_id=new.id) then
      raise exception 'Record the admission source before continuing to billing or enrollment.';
    end if;
    if not exists(select 1 from public.admission_consent_documents d where d.admission_id=new.id)
      and not exists(select 1 from public.admission_physical_consent_receipts p where p.admission_id=new.id) then
      raise exception 'Record the signed paper consent before continuing to billing or enrollment.';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists admission_workflow_evidence_gate on public.admission_cases;
create trigger admission_workflow_evidence_gate
before update of status on public.admission_cases
for each row execute function public.require_admission_workflow_evidence();
revoke execute on function public.require_admission_workflow_evidence() from public, anon, authenticated;



-- ============================================================
-- SOURCE: 0052_v2_physical_consent_timezone.sql
-- ============================================================

-- Resolve the organization-local consent date through the admission's batch.
-- admission_cases intentionally has no organization_id column.
create or replace function public.record_physical_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  actor uuid := auth.uid();
  c public.admission_cases;
  receipt public.admission_physical_consent_receipts;
  request_key uuid := (p_input->>'request_id')::uuid;
  admission_key uuid := (p_input->>'admission_id')::uuid;
  signed_on date := (p_input->>'guardian_signed_on')::date;
  local_today date;
  student_signed boolean := coalesce((p_input->>'student_signed')::boolean, false);
  reference text := nullif(trim(p_input->>'physical_copy_reference'), '');
  reason_text text := trim(coalesce(p_input->>'reason', ''));
begin
  if actor is null or not public.has_permission('admissions.create') then
    raise exception 'Admission permission required.';
  end if;
  if request_key is null or admission_key is null then raise exception 'Invalid consent receipt request.'; end if;
  if signed_on is null then raise exception 'Enter a valid guardian signing date.'; end if;
  if length(reason_text) < 5 or length(reason_text) > 500 then raise exception 'Enter a staff note of 5 to 500 characters.'; end if;
  if reference is not null and length(reference) > 160 then raise exception 'Paper file location must be 160 characters or fewer.'; end if;

  perform pg_advisory_xact_lock(hashtextextended(request_key::text, 0));
  select * into receipt from public.admission_physical_consent_receipts where request_id=request_key;
  if receipt.id is not null then
    if receipt.received_by<>actor or receipt.request_payload<>p_input then
      raise exception 'This request ID was already used for another consent receipt.';
    end if;
    return jsonb_build_object('id',receipt.id,'version',receipt.version);
  end if;

  select * into c from public.admission_cases where id=admission_key for update;
  if c.id is null or c.status='CANCELLED' then
    raise exception 'Paper consent can be recorded only for an open admission case.';
  end if;
  if c.status='DRAFT' then
    raise exception 'Complete application verification before recording paper consent.';
  end if;
  if not exists(select 1 from public.admission_referrals r where r.admission_id=c.id) then
    raise exception 'Record the admission source before recording signed paper consent.';
  end if;

  select (now() at time zone o.timezone)::date into local_today
  from public.batches b
  join public.organizations o on o.id=b.organization_id
  where b.id=c.batch_id;
  if local_today is null then
    raise exception 'The admission batch organization timezone is unavailable.';
  end if;
  if signed_on > local_today then raise exception 'Guardian signing date cannot be in the future.'; end if;
  if exists(select 1 from public.admission_physical_consent_receipts r where r.admission_id=c.id) then
    raise exception 'A paper-consent receipt is already recorded for this case.';
  end if;

  insert into public.admission_physical_consent_receipts(
    request_id,request_payload,admission_id,version,guardian_signed_on,student_signed,
    physical_copy_reference,received_by,reason
  )
  values(
    request_key,p_input,c.id,
    (select coalesce(max(r.version),0)+1 from public.admission_physical_consent_receipts r where r.admission_id=c.id),
    signed_on,student_signed,reference,actor,reason_text
  ) returning * into receipt;

  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',receipt.id::text,'RECEIVE_PHYSICAL_SIGNED_FORM',to_jsonb(receipt));
  return jsonb_build_object('id',receipt.id,'version',receipt.version);
end $$;

revoke all on function public.record_physical_admission_consent(jsonb) from public, anon;
grant execute on function public.record_physical_admission_consent(jsonb) to authenticated;



-- ============================================================
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
-- SOURCE: 0055_v3_class_log_review.sql
-- ============================================================

-- V3 teacher review: class logs use the same draft/submitted/reviewed
-- lifecycle as attendance, assessments and questions.

alter table public.class_logs
  add column if not exists reviewer_id uuid references public.profiles(id),
  add column if not exists review_note text,
  add column if not exists reviewed_at timestamptz;

alter table public.class_logs
  drop constraint if exists class_logs_status_check;

alter table public.class_logs
  add constraint class_logs_status_check
  check(status in ('DRAFT','SUBMITTED','APPROVED','REJECTED'));

alter table public.class_logs
  drop constraint if exists class_logs_review_fields_check;

alter table public.class_logs
  add constraint class_logs_review_fields_check
  check (
    (status in ('APPROVED','REJECTED') and reviewer_id is not null and reviewed_at is not null)
    or status in ('DRAFT','SUBMITTED')
  );

create unique index if not exists class_logs_one_pending_per_session
  on public.class_logs(session_id)
  where status = 'SUBMITTED';

create or replace function public.guard_submitted_class_log()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Class-log history cannot be deleted.';
  end if;

  if old.status = 'DRAFT' then
    if new.status = 'DRAFT' then
      return new;
    end if;

    if new.status = 'SUBMITTED'
      and (to_jsonb(new) - array['status','submitted_at','reviewer_id','review_note','reviewed_at'])
          is distinct from
          (to_jsonb(old) - array['status','submitted_at','reviewer_id','review_note','reviewed_at']) then
      raise exception 'Submit the saved class-log draft without changing its contents.';
    end if;

    if new.status not in ('DRAFT','SUBMITTED') then
      raise exception 'A class-log draft must be submitted before review.';
    end if;

    return new;
  end if;

  if old.status = 'SUBMITTED' then
    if new.status not in ('APPROVED','REJECTED') then
      raise exception 'Submitted class-log evidence must be approved or rejected.';
    end if;

    if (to_jsonb(new) - array['status','reviewer_id','review_note','reviewed_at'])
       is distinct from
       (to_jsonb(old) - array['status','reviewer_id','review_note','reviewed_at']) then
      raise exception 'Submitted class-log evidence is immutable; create a new revision after rejection or approval.';
    end if;

    if new.reviewer_id is null or new.reviewed_at is null or length(btrim(coalesce(new.review_note,''))) < 5 then
      raise exception 'A class-log review requires a reviewer, time and review note.';
    end if;

    return new;
  end if;

  raise exception 'Finalized class-log evidence is immutable; create a new revision.';
end;
$$;

create or replace function public.class_log_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid := auth.uid();
  rid uuid := nullif(p_input->>'request_id','')::uuid;
  sid uuid := nullif(p_input->>'session_id','')::uuid;
  act text := p_input->>'action';
  why text := trim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  cs public.class_sessions;
  latest public.class_logs;
  draft public.class_logs;
  review public.class_logs;
  progress jsonb := coalesce(p_input->'unit_progress','[]'::jsonb);
  unit_count integer;
  summary text := trim(coalesce(p_input->>'class_summary',''));
  unfinished text := trim(coalesce(p_input->>'unfinished_reason',''));
  homework_value text := trim(coalesce(p_input->>'homework',''));
  next_value text := trim(coalesce(p_input->>'next_session_plan',''));
  result jsonb;
  new_revision integer;
  branch uuid;
begin
  if actor is null or not public.has_permission('academics.view') then
    raise exception 'Academic access required.';
  end if;

  if rid is null or sid is null or length(why) < 5 or length(why) > 500 then
    raise exception 'Session, request identity and reason (5–500 characters) are required.';
  end if;

  if act = 'DECIDE' then
    if not public.has_permission('academics.attendance.approve') then
      raise exception 'Academic review permission required.';
    end if;
  elsif not (
    public.has_permission('academics.attendance.record')
    or public.has_permission('academics.sessions.manage')
  ) then
    raise exception 'Attendance recording permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into key from public.admission_command_keys where request_id=rid;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(sid::text,21));

  select * into cs
  from public.class_sessions
  where id=sid
  for update;

  if cs.id is null then
    raise exception 'Class session not found.';
  end if;

  select branch_id
  into branch
  from public.batches
  where id=cs.batch_id;

  if act='DECIDE' then
    select *
    into review
    from public.class_logs
    where id=nullif(p_input->>'class_log_id','')::uuid
      and session_id=sid
      and status='SUBMITTED'
    for update;

    if review.id is null then
      raise exception 'No submitted class log is awaiting review.';
    end if;

    if review.authored_by=actor then
      raise exception 'The class-log author cannot approve or reject their own submission.';
    end if;

    if p_input->>'decision' not in ('APPROVED','REJECTED') then
      raise exception 'Choose Approve or Reject.';
    end if;

    if length(trim(coalesce(p_input->>'review_note',''))) < 5
      or length(trim(coalesce(p_input->>'review_note',''))) > 1000 then
      raise exception 'Enter a review note of 5–1000 characters.';
    end if;

    update public.class_logs
    set status=p_input->>'decision',
        reviewer_id=actor,
        review_note=trim(p_input->>'review_note'),
        reviewed_at=now()
    where id=review.id
    returning * into review;

    result:=jsonb_build_object(
      'id',review.id,
      'revision',review.revision,
      'status',review.status,
      'message',case when review.status='APPROVED'
        then 'Class log approved.'
        else 'Class log rejected. The teacher can prepare a corrected revision.'
      end
    );

  else
    if not public.can_access_class_session(sid) then
      raise exception 'This class is outside your assigned scope.';
    end if;

    if cs.status<>'SCHEDULED' then
      raise exception 'A cancelled class cannot receive a class log.';
    end if;

    if cs.starts_at>now() then
      raise exception 'Class log opens after the scheduled class starts.';
    end if;

    if not public.has_permission('academics.sessions.manage')
      and not exists(
        select 1
        from public.staff st
        where st.profile_id=actor and st.id=cs.teacher_id
      ) then
      raise exception 'Only the assigned teacher may record this class.';
    end if;

    select * into latest
    from public.class_logs
    where session_id=sid
    order by revision desc
    limit 1;

    select * into draft
    from public.class_logs
    where session_id=sid
      and status='DRAFT'
    for update;

    if act='SAVE_DRAFT' then
      if latest.status='SUBMITTED' then
        raise exception 'This class log is awaiting admin review. Correct it only after a review decision.';
      end if;

      if jsonb_typeof(progress)<>'array' or jsonb_array_length(progress)>200 then
        raise exception 'Check curriculum progress entries.';
      end if;

      select coalesce(jsonb_array_length(cv.units),0)
      into unit_count
      from public.class_sessions x
      left join public.curriculum_versions cv on cv.id=x.curriculum_version_id
      where x.id=sid;

      if jsonb_array_length(progress)>unit_count then
        raise exception 'Progress must refer only to the curriculum pinned to this class.';
      end if;

      if exists(
        select 1
        from jsonb_array_elements(progress) e
        where (e->>'unit_index')::integer<0
          or (e->>'unit_index')::integer>=unit_count
          or e->>'status' not in ('COVERED','PARTIAL','NOT_COVERED')
          or length(coalesce(e->>'note',''))>500
      ) then
        raise exception 'Invalid curriculum progress entry.';
      end if;

      if summary='' or length(summary)>4000
        or length(unfinished)>2000
        or length(homework_value)>2000
        or length(next_value)>2000 then
        raise exception 'Class summary is required; keep each field within its limit.';
      end if;

      if exists(
        select 1 from jsonb_array_elements(progress) e
        where e->>'status' in ('PARTIAL','NOT_COVERED')
      ) and unfinished='' then
        raise exception 'Explain any planned curriculum left incomplete.';
      end if;

      if draft.id is not null and draft.authored_by<>actor then
        raise exception 'Another staff member owns the current draft.';
      end if;

      if draft.id is null then
        select coalesce(max(revision),0)+1
        into new_revision
        from public.class_logs
        where session_id=sid;

        insert into public.class_logs(
          session_id,revision,previous_log_id,status,unit_progress,
          class_summary,unfinished_reason,homework,next_session_plan,
          reason,authored_by
        )
        values(
          sid,new_revision,latest.id,'DRAFT',progress,summary,
          unfinished,homework_value,next_value,why,actor
        )
        returning * into draft;
      else
        update public.class_logs
        set unit_progress=progress,
            class_summary=summary,
            unfinished_reason=unfinished,
            homework=homework_value,
            next_session_plan=next_value,
            reason=why
        where id=draft.id
        returning * into draft;
      end if;

      result:=jsonb_build_object(
        'id',draft.id,
        'revision',draft.revision,
        'status',draft.status,
        'message','Class-log draft saved.'
      );

    elsif act='SUBMIT' then
      if draft.id is null or draft.authored_by<>actor then
        raise exception 'Save your class-log draft before submitting it.';
      end if;

      update public.class_logs
      set status='SUBMITTED',
          submitted_at=now()
      where id=draft.id
      returning * into draft;

      result:=jsonb_build_object(
        'id',draft.id,
        'revision',draft.revision,
        'status',draft.status,
        'message','Class log submitted for admin review.'
      );

    else
      raise exception 'Unsupported class-log action.';
    end if;
  end if;

  insert into public.audit_events(
    actor_profile_id,
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
    actor,
    branch,
    'CLASS_LOG',
    coalesce(draft.id,review.id)::text,
    act,
    why,
    null,
    case when review.id is not null then to_jsonb(review) else to_jsonb(draft) end,
    jsonb_build_object('session_id',sid,'revision',coalesce(draft.revision,review.revision))
  );

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(rid,actor,p_input,result);

  return result;
end;
$$;

revoke all on function public.class_log_workspace(uuid),public.class_log_command(jsonb)
from public,anon;

grant execute on function public.class_log_workspace(uuid),public.class_log_command(jsonb)
to authenticated;



-- ============================================================
-- SOURCE: 0056_v3_admin_review_queue.sql
-- ============================================================

-- V3 unified Admin Review Queue.
-- Teacher submissions are visible here by type and can be opened at their
-- owning academic workspace. The underlying command remains the source of
-- authorization and finalization.

create or replace function public.admin_review_queue()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
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
$$;

revoke all on function public.admin_review_queue()
from public, anon;

grant execute on function public.admin_review_queue()
to authenticated;

