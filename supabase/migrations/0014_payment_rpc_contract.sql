-- Normalize the public payment API to a single JSON request so generated
-- Supabase TypeScript types preserve optional/null fields consistently.

create or replace function public.post_payment_request(
  p_input jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_enrollment_id uuid;
  v_amount numeric;
  v_payment_date date;
  v_method text;
  v_notes text;
  v_idempotency_key uuid;
begin
  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Payment request must be a JSON object.';
  end if;

  begin
    v_student_id := (p_input->>'student_id')::uuid;
    v_enrollment_id := nullif(p_input->>'enrollment_id','')::uuid;
    v_amount := (p_input->>'amount')::numeric;
    v_payment_date := (p_input->>'payment_date')::date;
    v_method := p_input->>'method';
    v_notes := nullif(btrim(coalesce(p_input->>'notes','')), '');
    v_idempotency_key := (p_input->>'idempotency_key')::uuid;
  exception
    when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then
      raise exception 'Payment request contains an invalid value.';
  end;

  return public.post_payment(
    v_student_id,
    v_enrollment_id,
    v_amount,
    v_payment_date,
    v_method,
    v_notes,
    v_idempotency_key
  );
end;
$$;

-- The lower-level function remains available only as an internal database
-- implementation detail. Authenticated application users call the JSON wrapper.
revoke all on function public.post_payment(
  uuid,uuid,numeric,date,text,text,uuid
) from authenticated;

revoke all on function public.post_payment_request(jsonb) from public;
grant execute on function public.post_payment_request(jsonb) to authenticated;
