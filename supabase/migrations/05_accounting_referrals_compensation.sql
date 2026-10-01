-- Sohoj Academy fresh database baseline: accounting referrals compensation.
-- Install on an empty application schema. Each object is defined once.

create table public.finance_accounts (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  account_type text not null,
  account_subtype text not null,
  parent_id uuid,
  is_control_account boolean default false not null,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.finance_cost_centres (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  branch_id uuid,
  program_id uuid,
  batch_id uuid,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.general_ledger_journals (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  journal_no text default ('JRN-'::text || lpad((nextval('general_ledger_journal_no_seq'::regclass))::text, 8, '0'::text)) not null,
  journal_date date not null,
  journal_type text not null,
  source_type text not null,
  source_id text not null,
  description text not null,
  status text default 'POSTED'::text not null,
  posted_by uuid not null,
  posted_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);

create table public.general_ledger_lines (
  id uuid default gen_random_uuid() not null,
  journal_id uuid not null,
  line_no integer not null,
  account_id uuid not null,
  debit numeric(14,2) default 0 not null,
  credit numeric(14,2) default 0 not null,
  memo text,
  cost_centre_id uuid,
  branch_id uuid,
  program_id uuid,
  batch_id uuid,
  created_at timestamp with time zone default now() not null
);

create table public.vendors (
  id uuid default gen_random_uuid() not null,
  vendor_no text default ('VEN-'::text || lpad((nextval('vendor_no_seq'::regclass))::text, 6, '0'::text)) not null,
  organization_id uuid not null,
  name text not null,
  mobile text,
  email text,
  address text,
  service_category text,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table public.finance_payment_account_map (
  payment_method_id uuid not null,
  account_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.finance_fee_revenue_map (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  charge_type text not null,
  account_id uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.finance_payables (
  id uuid default gen_random_uuid() not null,
  payable_no text default ('PAY-'::text || lpad((nextval('finance_payable_no_seq'::regclass))::text, 6, '0'::text)) not null,
  organization_id uuid not null,
  payable_type text not null,
  staff_id uuid,
  vendor_id uuid,
  source_type text not null,
  source_id text not null,
  payable_account_id uuid not null,
  original_amount numeric(14,2) not null,
  due_on date,
  status text default 'OPEN'::text not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null,
  referrer_id uuid
);

create table public.finance_payable_settlements (
  id uuid default gen_random_uuid() not null,
  payable_id uuid not null,
  amount numeric(14,2) not null,
  payment_account_id uuid,
  external_reference text,
  settled_by uuid not null,
  settled_at timestamp with time zone default now() not null,
  reason text not null,
  advance_id uuid
);

create table public.finance_advances (
  id uuid default gen_random_uuid() not null,
  advance_no text default ('ADV-'::text || lpad((nextval('finance_advance_no_seq'::regclass))::text, 6, '0'::text)) not null,
  organization_id uuid not null,
  beneficiary_type text not null,
  staff_id uuid,
  vendor_id uuid,
  project_reference text,
  purpose text not null,
  requested_amount numeric(14,2) not null,
  approved_amount numeric(14,2),
  expected_settlement_date date,
  requested_by uuid not null,
  status text default 'REQUESTED'::text not null,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text
);

create table public.finance_advance_movements (
  id uuid default gen_random_uuid() not null,
  advance_id uuid not null,
  movement_type text not null,
  amount numeric(14,2) not null,
  source_type text,
  source_id text,
  payment_account_id uuid,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null,
  reason text not null,
  payable_id uuid
);

create table public.finance_expense_categories (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  expense_account_id uuid not null,
  is_active boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.finance_expenses (
  id uuid default gen_random_uuid() not null,
  expense_no text default ('EXP-'::text || lpad((nextval('finance_expense_no_seq'::regclass))::text, 6, '0'::text)) not null,
  organization_id uuid not null,
  expense_date date not null,
  category_id uuid not null,
  expense_account_id uuid not null,
  payment_mode text not null,
  payment_account_id uuid,
  payable_id uuid,
  vendor_id uuid,
  staff_id uuid,
  amount numeric(14,2) not null,
  description text not null,
  receipt_reference text,
  status text default 'DRAFT'::text not null,
  submitted_by uuid not null,
  posted_by uuid,
  posted_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text
);

create table public.finance_expense_reconciliations (
  id uuid default gen_random_uuid() not null,
  expense_id uuid not null,
  matched_amount numeric(14,2) not null,
  statement_reference text not null,
  reconciled_by uuid not null,
  reconciled_at timestamp with time zone default now() not null,
  note text not null
);

create table public.finance_account_reconciliations (
  id uuid default gen_random_uuid() not null,
  account_id uuid not null,
  statement_date date not null,
  statement_reference text not null,
  statement_balance numeric(14,2) not null,
  ledger_balance numeric(14,2) not null,
  difference numeric(14,2) not null,
  status text not null,
  reconciled_by uuid,
  reconciled_at timestamp with time zone,
  note text not null
);

create table public.teacher_referrals (
  id uuid default gen_random_uuid() not null,
  admission_id uuid not null,
  teacher_id uuid not null,
  captured_by uuid not null,
  captured_at timestamp with time zone default now() not null,
  reason text not null
);

create table public.teacher_compensation_runs (
  id uuid default gen_random_uuid() not null,
  run_no text default ('CMP-'::text || lpad((nextval('teacher_compensation_run_no_seq'::regclass))::text, 6, '0'::text)) not null,
  organization_id uuid not null,
  period_start date not null,
  period_end date not null,
  policy_version_id uuid not null,
  status text default 'DRAFT'::text not null,
  total_amount numeric(14,2) default 0 not null,
  submitted_by uuid not null,
  approved_by uuid,
  approved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text
);

create table public.teacher_compensation_events (
  id uuid default gen_random_uuid() not null,
  event_key text not null,
  teacher_id uuid not null,
  admission_id uuid,
  event_type text not null,
  event_period date not null,
  amount numeric(14,2) not null,
  created_at timestamp with time zone default now() not null
);

create table public.teacher_compensation_adjustments (
  id uuid default gen_random_uuid() not null,
  teacher_id uuid not null,
  amount numeric(14,2) not null,
  adjustment_type text not null,
  effective_period date not null,
  reason text not null,
  status text default 'PENDING'::text not null,
  requested_by uuid not null,
  approved_by uuid,
  approved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text
);

create table public.teacher_compensation_lines (
  id uuid default gen_random_uuid() not null,
  run_id uuid not null,
  teacher_id uuid not null,
  line_type text not null,
  source_type text not null,
  source_id text not null,
  amount numeric(14,2) not null,
  calculation jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  admission_id uuid
);

create table public.teacher_compensation_settlements (
  id uuid default gen_random_uuid() not null,
  run_id uuid not null,
  teacher_id uuid not null,
  payable_id uuid not null,
  gross_amount numeric(14,2) not null,
  advance_offset numeric(14,2) default 0 not null,
  cash_paid numeric(14,2) default 0 not null,
  payment_account_id uuid,
  external_reference text,
  settled_by uuid not null,
  settled_at timestamp with time zone default now() not null,
  reason text not null
);

create table public.teacher_compensation_claims (
  id uuid default gen_random_uuid() not null,
  teacher_id uuid not null,
  source_type text not null,
  source_id text not null,
  line_id uuid not null,
  run_id uuid not null,
  claimed_at timestamp with time zone default now() not null
);

create table public.referral_people (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  staff_id uuid,
  full_name text not null,
  mobile text,
  relationship_note text,
  contact_note text,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

create table public.admission_referrals (
  admission_id uuid not null,
  source text not null,
  referrer_id uuid,
  captured_by uuid not null,
  captured_at timestamp with time zone default now() not null,
  reason text not null
);

create table public.referral_bonus_awards (
  id uuid default gen_random_uuid() not null,
  admission_id uuid not null,
  referrer_id uuid not null,
  period_start date not null,
  net_collected numeric(14,2) not null,
  policy_version_id uuid not null,
  bonus_percent numeric(7,3) not null,
  amount numeric(14,2) not null,
  status text default 'PENDING'::text not null,
  payable_id uuid,
  requested_by uuid not null,
  reviewed_by uuid,
  created_at timestamp with time zone default now() not null,
  reviewed_at timestamp with time zone
);
