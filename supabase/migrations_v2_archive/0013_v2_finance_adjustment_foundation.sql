-- Preserve gross invoices/payments; adjustments are immutable compensating facts.
alter table public.admission_cases drop constraint admission_cases_status_check;
alter table public.admission_cases add constraint admission_cases_status_check check(status in ('DRAFT','READY','ACCEPTED','BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT','CANCELLED'));
alter table public.admission_cases drop constraint admission_cases_prospect_id_key;
create unique index admission_open_prospect on public.admission_cases(prospect_id) where status<>'CANCELLED';
alter table public.admission_invoices drop constraint admission_invoices_admission_id_key;
alter table public.admission_invoices add column invoice_kind text not null default 'INITIAL' check(invoice_kind in ('INITIAL','RECURRING'));
alter table public.admission_invoices add column billing_period date;
-- Controlled one-time backfill; restore the history trigger immediately.
alter table public.admission_invoices disable trigger admission_invoice_immutable;
update public.admission_invoices set billing_period=date_trunc('month',issued_on)::date;
alter table public.admission_invoices enable trigger admission_invoice_immutable;
alter table public.admission_invoices alter column billing_period set not null;
create unique index admission_one_initial_invoice on public.admission_invoices(admission_id) where invoice_kind='INITIAL';
create unique index admission_invoice_period on public.admission_invoices(admission_id,billing_period);
create table public.billing_terms (
 id uuid primary key default gen_random_uuid(), academic_year_id uuid not null references public.academic_years(id),
 name text not null check(length(btrim(name))>=2), starts_on date not null, ends_on date not null, due_on date not null,
 created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
 check(ends_on>=starts_on), check(due_on>=starts_on), unique(academic_year_id,starts_on)
);
create table public.admission_discounts (
 id uuid primary key default gen_random_uuid(), admission_id uuid not null references public.admission_cases(id),
 approval_id uuid not null unique references public.approval_requests(id),
 kind text not null check(kind in ('PERCENT','FIXED')), value numeric(12,2) not null check(value>0),
 starts_on date not null, ends_on date not null, check(ends_on>=starts_on),
 check(kind<>'PERCENT' or value<=100), created_at timestamptz not null default now()
);
create table public.invoice_credits (
 id uuid primary key default gen_random_uuid(), invoice_id uuid not null references public.admission_invoices(id),
 approval_id uuid not null references public.approval_requests(id),
 discount_id uuid references public.admission_discounts(id), kind text not null check(kind in ('DISCOUNT','CANCELLATION')),
 amount numeric(12,2) not null check(amount>0), created_at timestamptz not null default now(),
 unique(invoice_id,approval_id)
);
create table public.refund_authorizations (
 id uuid primary key default gen_random_uuid(), approval_id uuid not null unique references public.approval_requests(id),
 payment_id uuid not null references public.admission_payments(id), invoice_id uuid not null references public.admission_invoices(id),
 amount numeric(12,2) not null check(amount>0), created_at timestamptz not null default now()
);
create sequence public.refund_no_seq;
create table public.refund_payouts (
 id uuid primary key default gen_random_uuid(), authorization_id uuid not null unique references public.refund_authorizations(id),
 refund_no text not null unique default ('RFN-'||lpad(nextval('public.refund_no_seq')::text,6,'0')),
 payment_method_id uuid not null references public.payment_methods(id), external_reference text,
 posted_by uuid not null references public.profiles(id), posted_at timestamptz not null default now(), reason text not null
);
create unique index refund_external_reference on public.refund_payouts(payment_method_id,external_reference) where external_reference is not null;
create table public.admission_cancellations (
 admission_id uuid primary key references public.admission_cases(id), approval_id uuid not null unique references public.approval_requests(id),
 settlement text not null check(settlement in ('KEEP_CHARGES','CREDIT_ALL')), cancelled_at timestamptz not null default now()
);
create table public.billing_runs (
 id uuid primary key, period date not null, term_id uuid references public.billing_terms(id),
 posted_by uuid not null references public.profiles(id), posted_at timestamptz not null default now(),
 invoice_count integer not null, gross_total numeric(14,2) not null, reason text not null
);

create or replace function public.invoice_balance(p_invoice_id uuid)
returns table(gross numeric,credits numeric,paid numeric,refunded numeric,net numeric,due numeric,credit_balance numeric,reserved_refunds numeric)
language sql stable security definer set search_path=public as $$
 with x as (
 select i.total as g,
 coalesce((select sum(amount) from public.invoice_credits where invoice_id=i.id),0) c,
 coalesce((select sum(amount) from public.admission_payment_allocations where invoice_id=i.id),0) p,
 coalesce((select sum(r.amount) from public.refund_authorizations r join public.refund_payouts rp on rp.authorization_id=r.id where r.invoice_id=i.id),0) f,
 coalesce((select sum(r.amount) from public.refund_authorizations r where r.invoice_id=i.id and not exists(select 1 from public.refund_payouts rp where rp.authorization_id=r.id)),0) reserved
 from public.admission_invoices i where i.id=p_invoice_id)
 select g,c,p,f,g-c,greatest(g-c-p+f,0),greatest(p-f-(g-c),0),reserved from x;
$$;
revoke all on function public.invoice_balance(uuid) from public,anon,authenticated;

create or replace function public.apply_invoice_discounts(p_invoice_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare i public.admission_invoices; d public.admission_discounts; tuition numeric; credit numeric;
begin
 select * into i from public.admission_invoices where id=p_invoice_id;
 select coalesce(sum(amount),0) into tuition from public.admission_invoice_lines where invoice_id=i.id and charge_type='TUITION';
 for d in select * from public.admission_discounts where admission_id=i.admission_id and i.billing_period between starts_on and ends_on loop
  credit:=least(tuition,case when d.kind='PERCENT' then round(tuition*d.value/100,2) else d.value end);
  if credit>0 then insert into public.invoice_credits(invoice_id,approval_id,discount_id,kind,amount)
   values(i.id,d.approval_id,d.id,'DISCOUNT',credit) on conflict(invoice_id,approval_id) do nothing; end if;
 end loop;
end; $$;
revoke all on function public.apply_invoice_discounts(uuid) from public,anon,authenticated;

-- Protect all finalized adjustment records, including term definitions used by billing.
do $$ declare t text; begin
 foreach t in array array['billing_terms','admission_discounts','invoice_credits','refund_authorizations','refund_payouts','admission_cancellations','billing_runs'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('revoke insert,update,delete on public.%I from authenticated,anon',t);
  execute format('create policy finance_read on public.%I for select to authenticated using (public.has_permission(''finance.view''))',t);
  execute format('create trigger immutable_finance_history before update or delete on public.%I for each row execute function public.protect_admission_invoice()',t);
 end loop;
end; $$;
-- Decisions must go through the atomic workflow, not direct API updates.
revoke insert,update,delete on public.approval_requests from authenticated;
