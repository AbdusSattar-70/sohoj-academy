-- Generated from supabase/schema/billing/30_student_payments_and_adjustments.sql; edit the source, then run pnpm db:baseline.
-- Accountants can read the admission identity needed for the linked student account.
update public.access_roles set permissions=permissions||array['admissions.view'] where code='ACCOUNTANT';
create table public.student_payments(
 id uuid primary key default gen_random_uuid(),receipt_no bigint generated always as identity unique,
 invoice_id uuid not null references public.student_invoices,amount numeric(14,2) not null check(amount>0),
 method text not null check(method in('CASH','BANK','MOBILE_BANKING')),reference text,received_on date not null,
 created_by uuid not null references public.account_profiles,created_at timestamptz not null default now()
);
create unique index payment_transaction_ref on public.student_payments(method,reference) where reference is not null;
create table public.student_bill_adjustments(
 id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.student_invoices,
 kind text not null check(kind in('DISCOUNT','SCHOLARSHIP','REFUND')),amount numeric(14,2) not null check(amount>0),
 payment_id uuid references public.student_payments,reason text not null check(length(btrim(reason)) between 5 and 1000),
 created_by uuid not null references public.account_profiles,created_at timestamptz not null default now(),
 check((kind='REFUND')=(payment_id is not null))
);
do $$declare relation text;begin foreach relation in array array['student_payments','student_bill_adjustments'] loop
 execute format('alter table public.%I enable row level security',relation);execute format('revoke all on public.%I from public,anon,authenticated',relation);
 execute format('create trigger preserve_financial_entry before update or delete on public.%I for each row execute function public.reject_record_delete()',relation);
end loop;end $$;
create function public.invoice_balance(p_id uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('reductions',red,'paid',paid,'refunded',refund,'due',i.total-red-paid+refund,'net',i.total-red)
 from public.student_invoices i cross join lateral(select coalesce(sum(amount),0) red from public.student_bill_adjustments where invoice_id=i.id and kind in('DISCOUNT','SCHOLARSHIP'))r
 cross join lateral(select coalesce(sum(amount),0) paid from public.student_payments where invoice_id=i.id)p
 cross join lateral(select coalesce(sum(amount),0) refund from public.student_bill_adjustments where invoice_id=i.id and kind='REFUND')f where i.id=p_id
$$;
create function public.admission_billing(p_admission uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('billing.view');begin
 if not exists(select 1 from public.student_admissions where id=p_admission and academy_id=aid and division_id=public.current_workspace_id()) then raise exception 'Student account not found in this workspace.';end if;
 return coalesce((select jsonb_agg(to_jsonb(i)||jsonb_build_object('balance',public.invoice_balance(i.id),'payments',coalesce((select jsonb_agg(to_jsonb(p) order by created_at,id) from public.student_payments p where invoice_id=i.id),'[]'),'adjustments',coalesce((select jsonb_agg(to_jsonb(x) order by created_at,id) from public.student_bill_adjustments x where invoice_id=i.id),'[]')) order by i.period_start desc,i.id) from public.student_invoices i where admission_id=p_admission),'[]');
end $$;
create function public.student_billing_command(p_request_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('billing.manage');cmd text:=p_input->>'action';i public.student_invoices;a public.student_admissions;prior jsonb;balance jsonb;amount_value numeric;identity uuid;payment public.student_payments;day_value date;subtotal numeric;reduction numeric;lines jsonb;next_date date;payment_ref text;
begin
 perform public.check_change_reason(p_input->>'reason');
 select * into a from public.student_admissions where id=(p_input->>'admissionId')::uuid and academy_id=aid and division_id=public.current_workspace_id() for update;
 if not found or a.status<>'ADMITTED' then raise exception 'Open an admitted student account in this workspace.';end if;
 prior:=public.lookup_operation(p_request_id,'STUDENT_BILLING_'||cmd,p_input);if prior is not null then return prior;end if;
 if cmd='NEXT_INVOICE' then
  if not exists(select 1 from public.academic_batch_enrollments where id=a.enrollment_id and ends_before is null) then raise exception 'Enrollment is closed; recurring billing stopped.';end if;
  if a.fee_snapshot->>'cycle'='COURSE' then raise exception 'One-time programme has no recurring tuition.';end if;
  select max(period_start) into next_date from public.student_invoices where admission_id=a.id;
  if a.fee_snapshot->>'cycle'='MONTHLY' then day_value:=(date_trunc('month',next_date)+interval '1 month')::date;
  else day_value:=nullif(p_input->>'periodStart','')::date;if day_value is null or day_value<=next_date then raise exception 'Choose the next term start after the previous bill.';end if;end if;
  if not exists(select 1 from public.programme_runs where id=a.run_id and day_value between starts_on and ends_on) then raise exception 'Next cycle is outside programme dates.';end if;
  select coalesce(sum((x->>'amount')::numeric),0),coalesce(sum(case when x->>'type'='TUITION' then round((x->>'amount')::numeric*a.discount_percent/100,2) else 0 end),0),jsonb_agg(x||jsonb_build_object('discount',case when x->>'type'='TUITION' then round((x->>'amount')::numeric*a.discount_percent/100,2) else 0 end)) into subtotal,reduction,lines from jsonb_array_elements(a.fee_snapshot->'components')x where x->>'recurrence'='PER_CYCLE';
  if lines is null then raise exception 'No repeating charges in this fee plan.';end if;
  insert into public.student_invoices(academy_id,admission_id,period_start,kind,lines,subtotal,discount,total,due_on,created_by) values(aid,a.id,day_value,'TUITION',lines,subtotal,reduction,subtotal-reduction,case when a.fee_snapshot->>'cycle'='MONTHLY' then day_value+(a.fee_snapshot->>'dueDay')::int-1 else day_value end,auth.uid()) returning id into identity;
 else
  select * into i from public.student_invoices where id=(p_input->>'invoiceId')::uuid and admission_id=a.id for update;
  if not found then raise exception 'Choose an invoice from this student account.';end if;
  amount_value:=(p_input->>'amount')::numeric;if amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) then raise exception 'Enter a positive BDT amount with at most two decimals.';end if;
  balance:=public.invoice_balance(i.id);
  if cmd in('PAYMENT','DISCOUNT','SCHOLARSHIP') and amount_value>(balance->>'due')::numeric then raise exception 'Amount cannot exceed the remaining due. Refund excess collections separately.';end if;
  if cmd='PAYMENT' then
   day_value:=nullif(p_input->>'receivedOn','')::date;if day_value is null or day_value>(now() at time zone 'Asia/Dhaka')::date or day_value<(i.created_at at time zone 'Asia/Dhaka')::date then raise exception 'Choose the actual receipt date, not before invoice creation or in the future.';end if;
   payment_ref:=nullif(btrim(p_input->>'reference'),'');if p_input->>'method'<>'CASH' and payment_ref is null then raise exception 'Enter the bank/mobile transaction reference.';end if;
   insert into public.student_payments(invoice_id,amount,method,reference,received_on,created_by) values(i.id,amount_value,p_input->>'method',payment_ref,day_value,auth.uid()) returning id into identity;
  elsif cmd in('DISCOUNT','SCHOLARSHIP') then
   insert into public.student_bill_adjustments(invoice_id,kind,amount,reason,created_by) values(i.id,cmd,amount_value,p_input->>'reason',auth.uid()) returning id into identity;
  elsif cmd='REFUND' then
   select * into payment from public.student_payments where id=(p_input->>'paymentId')::uuid and invoice_id=i.id for update;
   if not found or amount_value>payment.amount-coalesce((select sum(amount) from public.student_bill_adjustments where payment_id=payment.id and kind='REFUND'),0) then raise exception 'Refund cannot exceed the remaining collection on the selected receipt.';end if;
   insert into public.student_bill_adjustments(invoice_id,kind,amount,payment_id,reason,created_by) values(i.id,cmd,amount_value,payment.id,p_input->>'reason',auth.uid()) returning id into identity;
  else raise exception 'Choose payment, discount, scholarship, refund or next invoice.';end if;
 end if;
 return public.finish_operation(p_request_id,'STUDENT_BILLING_'||cmd,p_input,jsonb_build_object('id',identity),'STUDENT_BILLING',identity,null);
end $$;
create function public.student_billing_register(p_query text default '',p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('billing.view');begin
 if p_query is null or length(p_query)>160 or p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid search and page.';end if;
 return coalesce((select jsonb_agg(to_jsonb(x)) from(select a.id,a.admission_no,p.full_name,p.mobile,p.student_no,r.title programme,
 (select coalesce(sum((public.invoice_balance(i.id)->>'due')::numeric),0) from public.student_invoices i where i.admission_id=a.id) due
 from public.student_admissions a join public.people p on p.id=a.student_id join public.programme_runs r on r.id=a.run_id where a.academy_id=aid and a.division_id=public.current_workspace_id() and a.status='ADMITTED' and(p_query='' or p.full_name ilike '%'||p_query||'%' or p.mobile like '%'||p_query||'%' or p.student_no::text=p_query) order by p.full_name,a.id limit 25 offset(p_page-1)*25)x),'[]');
end $$;
revoke all on function public.invoice_balance(uuid) from public,anon,authenticated;
revoke all on function public.admission_billing(uuid),public.student_billing_command(uuid,jsonb),public.student_billing_register(text,integer) from public,anon;
grant execute on function public.admission_billing(uuid),public.student_billing_command(uuid,jsonb),public.student_billing_register(text,integer) to authenticated;
notify pgrst,'reload schema';
