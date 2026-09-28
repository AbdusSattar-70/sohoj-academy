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
  ('accounting.expense.manage','Manage expenses','Create and post controlled expense records.'),
  ('accounting.expense.approve','Approve expenses','Approve expense records before posting.'),
  ('accounting.reconcile','Reconcile financial records','Reconcile expenses and cash/bank statements.'),
  ('finance.payments.reconcile','Reconcile payments','Match posted payments to controlled financial statements.')
on conflict(code) do update
set name=excluded.name, description=excluded.description;

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

create trigger invoice_credits_to_ledger
after insert on public.invoice_credits
for each row execute function public.finance_sync_invoice_credit(new.id);

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

create trigger admission_payment_allocations_to_ledger
after insert on public.admission_payment_allocations
for each row execute function public.finance_sync_payment(new.payment_id);

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

create trigger refund_payouts_to_ledger
after insert on public.refund_payouts
for each row execute function public.finance_sync_refund(new.id);

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

revoke insert,update,delete on all
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
