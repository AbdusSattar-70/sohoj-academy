-- ACTIVE V3 MIGRATION · 05_direct_admin_finance.sql
-- Source: supabase/baseline_v3/0005_v3_direct_admin_finance.sql
-- Apply only on a clean database (no prior schema_migrations history).

-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 05
-- Direct authorized finance operations. No generic second-person approval is required.
-- Source: supabase/migrations/0057_v3_direct_admin_finance_operations.sql

-- SOHOJ ACADEMY V3
-- Direct authorized finance operations: no generic second-person approval.
-- Legacy approval links remain nullable for historical V2 records.

alter table public.admission_discounts
  alter column approval_id drop not null,
  add column authorized_by uuid references public.profiles(id),
  add column authorization_reason text,
  add column correlation_id uuid;

alter table public.invoice_credits
  alter column approval_id drop not null,
  add column applied_by uuid references public.profiles(id);

alter table public.refund_authorizations
  alter column approval_id drop not null,
  add column authorized_by uuid references public.profiles(id),
  add column authorization_reason text,
  add column correlation_id uuid;

alter table public.admission_cancellations
  alter column approval_id drop not null,
  add column cancelled_by uuid references public.profiles(id),
  add column cancellation_reason text,
  add column correlation_id uuid;

alter table public.admission_discounts
  add constraint admission_discounts_authorization_actor_check
  check (approval_id is not null or authorized_by is not null);

alter table public.refund_authorizations
  add constraint refund_authorizations_authorization_actor_check
  check (approval_id is not null or authorized_by is not null);

alter table public.admission_cancellations
  add constraint admission_cancellations_authorization_actor_check
  check (approval_id is not null or cancelled_by is not null);

alter table public.invoice_credits
  drop constraint if exists invoice_credits_invoice_id_approval_id_key;

create unique index if not exists invoice_credit_discount_unique
  on public.invoice_credits(invoice_id, discount_id)
  where kind='DISCOUNT' and discount_id is not null;

create unique index if not exists invoice_credit_cancellation_unique
  on public.invoice_credits(invoice_id)
  where kind='CANCELLATION';

create or replace function public.apply_invoice_discounts(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  i public.admission_invoices;
  d public.admission_discounts;
  tuition numeric;
  credit numeric;
begin
  select * into i
  from public.admission_invoices
  where id=p_invoice_id;

  select coalesce(sum(amount),0)
  into tuition
  from public.admission_invoice_lines
  where invoice_id=i.id
    and charge_type='TUITION';

  for d in
    select *
    from public.admission_discounts
    where admission_id=i.admission_id
      and i.billing_period between starts_on and ends_on
  loop
    credit:=least(
      tuition,
      case
        when d.kind='PERCENT' then round(tuition*d.value/100,2)
        else d.value
      end
    );

    if credit>0 then
      insert into public.invoice_credits(
        invoice_id,
        approval_id,
        discount_id,
        kind,
        amount,
        applied_by
      )
      values(
        i.id,
        d.approval_id,
        d.id,
        'DISCOUNT',
        credit,
        d.authorized_by
      )
      on conflict (invoice_id, discount_id)
        where discount_id is not null
      do nothing;
    end if;
  end loop;
end;
$$;

revoke all on function public.apply_invoice_discounts(uuid) from public,anon,authenticated;

create or replace function public.finance_v3_command(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  actor uuid:=auth.uid();
  action text:=p_input->>'action';
  req uuid:=nullif(p_input->>'request_id','')::uuid;
  reason text:=btrim(coalesce(p_input->>'reason',''));
  key public.admission_command_keys;
  a public.admission_cases;
  i public.admission_invoices;
  payment public.admission_payments;
  discount public.admission_discounts;
  cancellation public.admission_cancellations;
  refund_auth public.refund_authorizations;
  payout public.refund_payouts;
  balance record;
  invoice_allocation numeric;
  reserved numeric;
  amount numeric;
  kind text;
  value numeric;
  start_date date;
  end_date date;
  settlement text;
  payment_method uuid;
  today date;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
begin
  if actor is null then
    raise exception 'Sign in to continue.';
  end if;

  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason are required.';
  end if;

  if action not in ('APPLY_DISCOUNT','CANCEL_ADMISSION','REFUND') then
    raise exception 'Unsupported V3 finance action.';
  end if;

  if action='APPLY_DISCOUNT' and not public.has_permission('finance.billing.manage') then
    raise exception 'Billing management permission required.';
  end if;

  if action='CANCEL_ADMISSION' and not public.has_permission('admissions.create') then
    raise exception 'Admission management permission required.';
  end if;

  if action='REFUND' and not public.has_permission('finance.payments.post') then
    raise exception 'Payment posting permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,0));

  select * into key
  from public.admission_command_keys
  where request_id=req;

  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select * into a
  from public.admission_cases
  where id=nullif(p_input->>'admission_id','')::uuid
  for update;

  if action in ('APPLY_DISCOUNT','CANCEL_ADMISSION') and a.id is null then
    raise exception 'Admission not found.';
  end if;

  if a.id is not null then
    select (now() at time zone o.timezone)::date
    into today
    from public.batches b
    join public.organizations o on o.id=b.organization_id
    where b.id=a.batch_id;
  end if;

  if action='APPLY_DISCOUNT' then
    kind:=p_input->>'kind';
    value:=(p_input->>'value')::numeric;
    start_date:=(p_input->>'starts_on')::date;
    end_date:=(p_input->>'ends_on')::date;

    if a.status='CANCELLED'
      or kind not in ('PERCENT','FIXED')
      or value is null
      or value<=0
      or value<>round(value,2)
      or value>9999999999.99
      or (kind='PERCENT' and value>100)
      or start_date is null
      or end_date is null
      or end_date<start_date
    then
      raise exception 'Enter a valid discount and effective period.';
    end if;

    if exists(
      select 1
      from public.admission_discounts d
      where d.admission_id=a.id
        and daterange(d.starts_on,d.ends_on,'[]')
          && daterange(start_date,end_date,'[]')
    ) then
      raise exception 'Discount overlaps an existing discount. Use a non-overlapping period.';
    end if;

    before_data:=jsonb_build_object(
      'admission_id',a.id,
      'status',a.status
    );

    insert into public.admission_discounts(
      admission_id,
      approval_id,
      authorized_by,
      authorization_reason,
      correlation_id,
      kind,
      value,
      starts_on,
      ends_on
    )
    values(
      a.id,
      null,
      actor,
      reason,
      req,
      kind,
      value,
      start_date,
      end_date
    )
    returning * into discount;

    for i in
      select *
      from public.admission_invoices
      where admission_id=a.id
        and billing_period between start_date and end_date
    loop
      perform public.apply_invoice_discounts(i.id);
    end loop;

    after_data:=jsonb_build_object(
      'discount_id',discount.id,
      'admission_id',a.id,
      'kind',discount.kind,
      'value',discount.value,
      'starts_on',discount.starts_on,
      'ends_on',discount.ends_on
    );

    result:=jsonb_build_object(
      'id',discount.id,
      'message','Discount applied and recorded.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'ADMISSION_DISCOUNT',a.id::text,'APPLY_DISCOUNT',reason,
      before_data,after_data,jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='CANCEL_ADMISSION' then
    settlement:=p_input->>'settlement';

    if a.status='CANCELLED'
      or settlement not in ('KEEP_CHARGES','CREDIT_ALL')
    then
      raise exception 'Choose a valid cancellation settlement for an open admission.';
    end if;

    if exists(
      select 1 from public.admission_cancellations
      where admission_id=a.id
    ) then
      raise exception 'Admission cancellation is already recorded.';
    end if;

    before_data:=jsonb_build_object(
      'admission_id',a.id,
      'status',a.status,
      'enrollment_id',a.enrollment_id
    );

    insert into public.admission_cancellations(
      admission_id,
      approval_id,
      cancelled_by,
      cancellation_reason,
      correlation_id,
      settlement
    )
    values(
      a.id,
      null,
      actor,
      reason,
      req,
      settlement
    )
    returning * into cancellation;

    if settlement='CREDIT_ALL' then
      for i in
        select *
        from public.admission_invoices
        where admission_id=a.id
      loop
        select * into balance
        from public.invoice_balance(i.id);

        if balance.net>0 then
          insert into public.invoice_credits(
            invoice_id,
            approval_id,
            kind,
            amount,
            applied_by
          )
          values(
            i.id,
            null,
            'CANCELLATION',
            balance.net,
            actor
          )
          on conflict (invoice_id)
            where kind='CANCELLATION'
          do nothing;
        end if;
      end loop;
    end if;

    update public.admission_cases
    set status='CANCELLED'
    where id=a.id;

    update public.enrollments
    set status='WITHDRAWN',
        ended_on=today
    where id=a.enrollment_id
      and status='ACTIVE';

    if a.student_id is not null
      and not exists(
        select 1
        from public.enrollments
        where student_id=a.student_id
          and status='ACTIVE'
      )
    then
      update public.students
      set status='INACTIVE'
      where id=a.student_id;
    end if;

    after_data:=jsonb_build_object(
      'cancellation_id',cancellation.id,
      'admission_id',a.id,
      'status','CANCELLED',
      'settlement',settlement
    );

    result:=jsonb_build_object(
      'id',cancellation.id,
      'message','Admission cancelled and recorded.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'ADMISSION_CANCELLATION',a.id::text,'CANCEL_ADMISSION',reason,
      before_data,after_data,jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  else
    select * into payment
    from public.admission_payments
    where id=nullif(p_input->>'payment_id','')::uuid
    for update;

    select * into i
    from public.admission_invoices
    where id=nullif(p_input->>'invoice_id','')::uuid
    for update;

    amount:=(p_input->>'amount')::numeric;
    payment_method:=nullif(p_input->>'payment_method_id','')::uuid;

    if payment.id is null or i.id is null then
      raise exception 'Payment or invoice not found.';
    end if;

    if not exists(
      select 1
      from public.admission_payment_allocations pa
      where pa.payment_id=payment.id
        and pa.invoice_id=i.id
    ) then
      raise exception 'The selected payment is not allocated to this invoice.';
    end if;

    select coalesce(sum(pa.amount),0)
    into invoice_allocation
    from public.admission_payment_allocations pa
    where pa.payment_id=payment.id
      and pa.invoice_id=i.id;

    select coalesce(sum(r.amount),0)
    into reserved
    from public.refund_authorizations r
    where r.payment_id=payment.id;

    select * into balance
    from public.invoice_balance(i.id);

    if amount is null
      or amount<=0
      or amount<>round(amount,2)
      or payment_method is null
      or amount>payment.amount-reserved
      or amount>invoice_allocation
      or amount>balance.credit_balance-balance.reserved_refunds
    then
      raise exception 'Refund exceeds the unreserved eligible credit for this payment and invoice.';
    end if;

    if not exists(
      select 1
      from public.payment_methods
      where id=payment_method
        and is_active
    ) then
      raise exception 'Choose an active refund payment method.';
    end if;

    before_data:=jsonb_build_object(
      'payment_id',payment.id,
      'invoice_id',i.id,
      'amount_received',payment.amount,
      'invoice_credit',balance.credit_balance
    );

    insert into public.refund_authorizations(
      approval_id,
      payment_id,
      invoice_id,
      amount,
      authorized_by,
      authorization_reason,
      correlation_id
    )
    values(
      null,
      payment.id,
      i.id,
      amount,
      actor,
      reason,
      req
    )
    returning * into refund_auth;

    insert into public.refund_payouts(
      authorization_id,
      payment_method_id,
      external_reference,
      posted_by,
      reason
    )
    values(
      refund_auth.id,
      payment_method,
      nullif(btrim(coalesce(p_input->>'external_reference','')),''),
      actor,
      reason
    )
    returning * into payout;

    after_data:=jsonb_build_object(
      'refund_authorization_id',refund_auth.id,
      'refund_id',payout.id,
      'refund_no',payout.refund_no,
      'invoice_id',i.id,
      'payment_id',payment.id,
      'amount',amount
    );

    result:=jsonb_build_object(
      'id',payout.id,
      'refund_no',payout.refund_no,
      'message','Actual refund posted: '||payout.refund_no||'.'
    );

    insert into public.audit_events(
      correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,metadata
    )
    values(
      req,actor,'REFUND',payout.id::text,'POST_REFUND',reason,
      before_data,after_data,jsonb_build_object(
        'finance_flow','V3_DIRECT_ADMIN',
        'invoice_id',i.id,
        'payment_id',payment.id
      )
    );
  end if;

  insert into public.admission_command_keys(request_id,actor_id,payload,result)
  values(req,actor,p_input,result);

  return result;
end;
$$;

revoke all on function public.finance_v3_command(jsonb) from public,anon;
grant execute on function public.finance_v3_command(jsonb) to authenticated;

