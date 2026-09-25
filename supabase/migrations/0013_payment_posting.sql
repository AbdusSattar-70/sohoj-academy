-- Financial posting hardening: idempotent payment posting and a single
-- server-authoritative write path for official academy receipts.

create table public.payment_posting_keys (
  idempotency_key uuid primary key,
  requested_by uuid not null references public.profiles(id),
  payment_id uuid unique references public.payments(id),
  created_at timestamptz not null default now()
);

alter table public.payment_posting_keys enable row level security;

-- No direct client policies are intentionally granted. The posting RPC owns
-- this internal coordination table.

create or replace function public.post_payment(
  p_student_id uuid,
  p_enrollment_id uuid,
  p_amount numeric,
  p_payment_date date,
  p_method text,
  p_notes text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_role public.app_role;
  v_payment public.payments;
  v_existing_payment_id uuid;
  v_receipt_no text;
  v_claimed integer;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user;

  if v_role not in ('ADMIN','OPERATOR') then
    raise exception 'Not authorized to post payments.';
  end if;

  if p_student_id is null then
    raise exception 'Student is required.';
  end if;

  if not exists (
    select 1 from public.students
    where id = p_student_id
  ) then
    raise exception 'Student not found.';
  end if;

  if p_enrollment_id is not null and not exists (
    select 1
    from public.enrollments e
    where e.id = p_enrollment_id
      and e.student_id = p_student_id
  ) then
    raise exception 'Selected enrollment does not belong to the student.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  if p_payment_date is null then
    raise exception 'Payment date is required.';
  end if;

  if upper(btrim(coalesce(p_method,''))) not in (
    'CASH',
    'BANK',
    'MOBILE BANKING'
  ) then
    raise exception 'Unsupported payment method.';
  end if;

  if p_idempotency_key is null then
    raise exception 'Payment operation identity is required.';
  end if;

  insert into public.payment_posting_keys (
    idempotency_key,
    requested_by
  )
  values (
    p_idempotency_key,
    v_user
  )
  on conflict do nothing;

  get diagnostics v_claimed = row_count;

  if v_claimed = 0 then
    select payment_id
      into v_existing_payment_id
    from public.payment_posting_keys
    where idempotency_key = p_idempotency_key;

    if v_existing_payment_id is null then
      raise exception 'This payment operation is still being processed. Retry shortly.';
    end if;

    select *
      into v_payment
    from public.payments
    where id = v_existing_payment_id;

    if v_payment.id is null then
      raise exception 'Existing payment operation could not be resolved.';
    end if;

    return jsonb_build_object(
      'payment_id', v_payment.id,
      'receipt_no', v_payment.receipt_no,
      'status', v_payment.status,
      'idempotent_replay', true
    );
  end if;

  perform set_config('app.correlation_id', v_correlation_id::text, true);

  v_receipt_no := public.generate_receipt_no();

  insert into public.payments (
    receipt_no,
    student_id,
    enrollment_id,
    amount,
    payment_date,
    method,
    status,
    notes,
    collected_by
  )
  values (
    v_receipt_no,
    p_student_id,
    p_enrollment_id,
    p_amount,
    p_payment_date,
    upper(btrim(p_method)),
    'POSTED',
    nullif(btrim(coalesce(p_notes,'')), ''),
    v_user
  )
  returning * into v_payment;

  update public.payment_posting_keys
  set payment_id = v_payment.id
  where idempotency_key = p_idempotency_key;

  insert into public.audit_events (
    correlation_id,
    actor_id,
    actor_role,
    entity_type,
    entity_id,
    action,
    after_data,
    metadata
  )
  values (
    v_correlation_id,
    v_user,
    v_role,
    'PAYMENT',
    v_payment.id::text,
    'POST',
    jsonb_build_object(
      'payment_id', v_payment.id,
      'receipt_no', v_payment.receipt_no,
      'student_id', v_payment.student_id,
      'enrollment_id', v_payment.enrollment_id,
      'amount', v_payment.amount,
      'payment_date', v_payment.payment_date,
      'method', v_payment.method,
      'status', v_payment.status
    ),
    jsonb_build_object(
      'workflow', 'POST_PAYMENT',
      'idempotency_key', p_idempotency_key
    )
  );

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'receipt_no', v_payment.receipt_no,
    'status', v_payment.status,
    'idempotent_replay', false
  );
end;
$$;

revoke insert, update, delete on public.payments from authenticated;
revoke all on public.payment_posting_keys from authenticated;

revoke all on function public.post_payment(
  uuid,uuid,numeric,date,text,text,uuid
) from public;

grant execute on function public.post_payment(
  uuid,uuid,numeric,date,text,text,uuid
) to authenticated;
