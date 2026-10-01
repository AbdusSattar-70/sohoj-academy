-- Sohoj Academy fresh database baseline: billing payments adjustments.
-- Install on an empty application schema. Each object is defined once.

create table public.payment_methods (
  id uuid default gen_random_uuid() not null,
  organization_id uuid not null,
  code text not null,
  name text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null
);

create table public.admission_invoices (
  id uuid default gen_random_uuid() not null,
  invoice_no text default ('INV-'::text || lpad((nextval('invoice_no_seq'::regclass))::text, 6, '0'::text)) not null,
  admission_id uuid not null,
  student_id uuid not null,
  fee_plan_version_id uuid not null,
  currency_code text not null,
  total numeric(12,2) not null,
  due_on date not null,
  issued_on date not null,
  posted_by uuid not null,
  posted_at timestamp with time zone default now() not null,
  invoice_kind text default 'INITIAL'::text not null,
  billing_period date not null
);

create table public.admission_invoice_lines (
  id uuid default gen_random_uuid() not null,
  invoice_id uuid not null,
  fee_component_id uuid,
  name text not null,
  charge_type text not null,
  amount numeric(12,2) not null
);

create table public.admission_payments (
  id uuid default gen_random_uuid() not null,
  student_id uuid not null,
  payment_method_id uuid not null,
  amount numeric(12,2) not null,
  currency_code text not null,
  external_reference text,
  receipt_no text default ('RCT-'::text || lpad((nextval('admission_receipt_no_seq'::regclass))::text, 6, '0'::text)) not null,
  posted_by uuid not null,
  posted_at timestamp with time zone default now() not null,
  reason text not null
);

create table public.admission_payment_allocations (
  payment_id uuid not null,
  invoice_id uuid not null,
  amount numeric(12,2) not null
);

create table public.billing_terms (
  id uuid default gen_random_uuid() not null,
  academic_year_id uuid not null,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  due_on date not null,
  created_by uuid not null,
  created_at timestamp with time zone default now() not null
);

create table public.admission_discounts (
  id uuid default gen_random_uuid() not null,
  admission_id uuid not null,
  kind text not null,
  value numeric(12,2) not null,
  starts_on date not null,
  ends_on date not null,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text,
  correlation_id uuid
);

create table public.invoice_credits (
  id uuid default gen_random_uuid() not null,
  invoice_id uuid not null,
  discount_id uuid,
  kind text not null,
  amount numeric(12,2) not null,
  created_at timestamp with time zone default now() not null,
  applied_by uuid
);

create table public.refund_authorizations (
  id uuid default gen_random_uuid() not null,
  payment_id uuid not null,
  invoice_id uuid not null,
  amount numeric(12,2) not null,
  created_at timestamp with time zone default now() not null,
  authorized_by uuid,
  authorization_reason text,
  correlation_id uuid
);

create table public.refund_payouts (
  id uuid default gen_random_uuid() not null,
  authorization_id uuid not null,
  refund_no text default ('RFN-'::text || lpad((nextval('refund_no_seq'::regclass))::text, 6, '0'::text)) not null,
  payment_method_id uuid not null,
  external_reference text,
  posted_by uuid not null,
  posted_at timestamp with time zone default now() not null,
  reason text not null
);

create table public.admission_cancellations (
  admission_id uuid not null,
  settlement text not null,
  cancelled_at timestamp with time zone default now() not null,
  cancelled_by uuid,
  cancellation_reason text,
  correlation_id uuid
);

create table public.billing_runs (
  id uuid not null,
  period date not null,
  term_id uuid,
  posted_by uuid not null,
  posted_at timestamp with time zone default now() not null,
  invoice_count integer not null,
  gross_total numeric(14,2) not null,
  reason text not null
);
