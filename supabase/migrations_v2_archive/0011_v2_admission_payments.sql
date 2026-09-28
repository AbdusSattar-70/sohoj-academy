-- First-payment workflow: posted money, explicit allocation, immutable receipt.
create sequence public.admission_receipt_no_seq;
create table public.admission_payments (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id),
 payment_method_id uuid not null references public.payment_methods(id),
 amount numeric(12,2) not null check(amount>0),
 currency_code text not null,
 external_reference text,
 receipt_no text not null unique default ('RCT-'||lpad(nextval('public.admission_receipt_no_seq')::text,6,'0')),
 posted_by uuid not null references public.profiles(id),
 posted_at timestamptz not null default now(),
 reason text not null
);
create unique index admission_payment_external_reference on public.admission_payments(payment_method_id,external_reference) where external_reference is not null;
create table public.admission_payment_allocations (
 payment_id uuid primary key references public.admission_payments(id),
 invoice_id uuid not null references public.admission_invoices(id),
 amount numeric(12,2) not null check(amount>0)
);
create trigger admission_payment_immutable before update or delete on public.admission_payments for each row execute function public.protect_admission_invoice();
create trigger admission_allocation_immutable before update or delete on public.admission_payment_allocations for each row execute function public.protect_admission_invoice();

create or replace function public.admission_payment_satisfied(p_admission_id uuid)
returns boolean language sql security definer set search_path=public as $$
 select coalesce(sum(pa.amount),0)>=case
 when not (r.payload->>'allow_credit_enrollment')::boolean or r.payload->>'payment_requirement'='FULL' then i.total
 when r.payload->>'payment_requirement'='MINIMUM_PERCENT' then round(i.total*(r.payload->>'minimum_payment_percent')::numeric/100,2)
 else 0 end
 from public.admission_cases a join public.admission_invoices i on i.admission_id=a.id
 join public.business_rule_versions r on r.id=a.activation_policy_version_id
 left join public.admission_payment_allocations pa on pa.invoice_id=i.id
 where a.id=p_admission_id group by i.total,r.payload;
$$;

create or replace function public.post_admission_payment(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_actor uuid:=auth.uid(); v_request uuid:=(p_input->>'request_id')::uuid;
 v_key public.admission_command_keys; v_case public.admission_cases; v_invoice public.admission_invoices;
 v_payment public.admission_payments; v_amount numeric:=(p_input->>'amount')::numeric;
 v_paid numeric; v_result jsonb; v_reason text:=btrim(coalesce(p_input->>'reason',''));
begin
 if v_actor is null or not public.has_permission('finance.payments.post') then raise exception 'Payment posting permission required.'; end if;
 if v_request is null or v_amount is null or v_amount<=0 or v_amount<>round(v_amount,2) or length(v_reason)<5 then raise exception 'Valid amount, request identity and reason are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_request::text,0));
 select * into v_key from public.admission_command_keys where request_id=v_request;
 if found then
   if v_key.actor_id<>v_actor or v_key.payload<>p_input then raise exception 'Request identity was already used for different input.'; end if;
   return v_key.result;
 end if;
 select * into v_case from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if not found or v_case.status not in ('BILLING_POSTED','PENDING_PAYMENT','ACTIVE_ENROLLMENT') then raise exception 'Post initial billing before collecting payment.'; end if;
 select * into v_invoice from public.admission_invoices where admission_id=v_case.id for update;
 select coalesce(sum(amount),0) into v_paid from public.admission_payment_allocations where invoice_id=v_invoice.id;
 if v_invoice.id is null or v_amount>v_invoice.total-v_paid then raise exception 'Payment exceeds the outstanding invoice balance.'; end if;
 if not exists(select 1 from public.payment_methods where id=(p_input->>'payment_method_id')::uuid and is_active) then raise exception 'Choose an active payment method.'; end if;
 insert into public.admission_payments(student_id,payment_method_id,amount,currency_code,external_reference,posted_by,reason)
 values(v_case.student_id,(p_input->>'payment_method_id')::uuid,v_amount,v_invoice.currency_code,nullif(btrim(p_input->>'external_reference'),''),v_actor,v_reason) returning * into v_payment;
 insert into public.admission_payment_allocations(payment_id,invoice_id,amount) values(v_payment.id,v_invoice.id,v_amount);
 v_result:=jsonb_build_object('id',v_case.id,'status',v_case.status,'receipt_no',v_payment.receipt_no);
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data,metadata)
 values(v_request,v_actor,'PAYMENT',v_payment.id::text,'POST',v_reason,to_jsonb(v_payment),jsonb_build_object('invoice_id',v_invoice.id,'admission_id',v_case.id));
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(v_request,v_actor,p_input,v_result);
 return v_result;
end; $$;
alter table public.admission_payments enable row level security;
alter table public.admission_payment_allocations enable row level security;
grant select on public.admission_payments,public.admission_payment_allocations to authenticated;
revoke insert,update,delete on public.admission_payments,public.admission_payment_allocations from authenticated,anon;
create policy admission_payment_read on public.admission_payments for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
create policy admission_allocation_read on public.admission_payment_allocations for select to authenticated using(public.has_permission('admissions.view') or public.has_permission('finance.view'));
revoke all on function public.post_admission_payment(jsonb) from public,anon;
grant execute on function public.post_admission_payment(jsonb) to authenticated;
