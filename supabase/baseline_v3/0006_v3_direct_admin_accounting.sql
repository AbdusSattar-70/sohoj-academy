-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 06
-- Direct authorized accounting operations for advances, expenses and teacher compensation.
-- Source: supabase/migrations/0058_v3_direct_admin_accounting.sql

-- SOHOJ ACADEMY V3
-- Direct admin accounting operations for the current two-person ERP phase.
-- Legacy approval-linked rows remain compatible for historical V2 records.

alter table public.finance_advances
  add column if not exists authorized_by uuid references public.profiles(id),
  add column if not exists authorization_reason text;

alter table public.finance_expenses
  alter column approval_id drop not null,
  add column if not exists authorized_by uuid references public.profiles(id),
  add column if not exists authorization_reason text;

alter table public.teacher_compensation_runs
  alter column approval_id drop not null,
  add column if not exists authorized_by uuid references public.profiles(id),
  add column if not exists authorization_reason text;

alter table public.teacher_compensation_adjustments
  alter column approval_id drop not null,
  add column if not exists authorized_by uuid references public.profiles(id),
  add column if not exists authorization_reason text;

create or replace function public.finance_v3_accounting_command(p_input jsonb)
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
  org uuid;
  result jsonb;
  amount numeric;
  payment_account uuid;
  advance public.finance_advances;
  expense public.finance_expenses;
  category public.finance_expense_categories;
  payable public.finance_payables;
  compensation public.teacher_compensation_runs;
  policy public.business_rule_versions;
  preview jsonb;
  line jsonb;
  v_teacher_id uuid;
  teacher_total numeric;
  decision text;
  adjustment_id uuid;
begin
  if actor is null then
    raise exception 'Sign in to continue.';
  end if;

  if req is null or length(reason)<5 then
    raise exception 'A request identity and reason of at least five characters are required.';
  end if;

  if action not in (
    'CREATE_ADVANCE',
    'CREATE_EXPENSE_DIRECT',
    'RUN_COMPENSATION',
    'APPLY_COMP_ADJUSTMENT'
  ) then
    raise exception 'Unsupported V3 accounting action.';
  end if;

  if action='CREATE_ADVANCE'
    and not public.has_permission('finance.advances.manage') then
    raise exception 'Advance management permission required.';
  end if;

  if action='CREATE_EXPENSE_DIRECT'
    and not public.has_permission('accounting.expense.manage') then
    raise exception 'Expense management permission required.';
  end if;

  if action in ('RUN_COMPENSATION','APPLY_COMP_ADJUSTMENT')
    and not public.has_permission('staff.compensation.manage') then
    raise exception 'Teacher compensation management permission required.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(req::text,9));

  select * into key
  from public.admission_command_keys
  where request_id=req;

  if found then
    if key.actor_id<>actor or key.payload<>p_input then
      raise exception 'Request identity already used for different input.';
    end if;
    return key.result;
  end if;

  select id into org
  from public.organizations
  where code='SOHOJ' and is_active
  limit 1;

  if action='CREATE_ADVANCE' then
    if p_input->>'beneficiary_type' not in ('STAFF','VENDOR','PROJECT') then
      raise exception 'Choose staff, vendor or project as the advance beneficiary.';
    end if;

    amount:=(p_input->>'requested_amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Advance amount must be a positive two-decimal amount.';
    end if;

    if p_input->>'beneficiary_type'='STAFF' and not exists(
      select 1 from public.staff
      where id=nullif(p_input->>'staff_id','')::uuid
        and organization_id=org
        and status='ACTIVE'
    ) then
      raise exception 'Choose an active staff member.';
    end if;

    if p_input->>'beneficiary_type'='VENDOR' and not exists(
      select 1 from public.vendors
      where id=nullif(p_input->>'vendor_id','')::uuid
        and organization_id=org
        and is_active
    ) then
      raise exception 'Choose an active vendor.';
    end if;

    if p_input->>'beneficiary_type'='PROJECT'
      and nullif(btrim(p_input->>'project_reference'),'') is null then
      raise exception 'Project reference is required for a project advance.';
    end if;

    if length(btrim(coalesce(p_input->>'purpose','')))<5 then
      raise exception 'Advance purpose must be at least five characters.';
    end if;

    insert into public.finance_advances(
      organization_id,
      beneficiary_type,
      staff_id,
      vendor_id,
      project_reference,
      purpose,
      requested_amount,
      approved_amount,
      expected_settlement_date,
      requested_by,
      authorized_by,
      authorization_reason,
      status
    )
    values(
      org,
      p_input->>'beneficiary_type',
      nullif(p_input->>'staff_id','')::uuid,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(btrim(p_input->>'project_reference'),''),
      btrim(p_input->>'purpose'),
      amount,
      amount,
      nullif(p_input->>'expected_settlement_date','')::date,
      actor,
      actor,
      reason,
      'APPROVED'
    )
    returning * into advance;

    result:=jsonb_build_object(
      'id',advance.id,
      'advanceNo',advance.advance_no,
      'message','Advance authorized and recorded.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'FINANCE_ADVANCE',
      advance.id::text,
      'CREATE_ADVANCE',
      reason,
      jsonb_build_object(
        'advance_no',advance.advance_no,
        'beneficiary_type',advance.beneficiary_type,
        'requested_amount',advance.requested_amount,
        'approved_amount',advance.approved_amount,
        'status',advance.status
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='CREATE_EXPENSE_DIRECT' then
    amount:=(p_input->>'amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Expense amount must be a positive two-decimal amount.';
    end if;

    select * into category
    from public.finance_expense_categories
    where id=nullif(p_input->>'category_id','')::uuid
      and organization_id=org
      and is_active;

    if category.id is null then
      raise exception 'Choose an active expense category.';
    end if;

    if p_input->>'payment_mode' not in ('PAID_NOW','ON_ACCOUNT') then
      raise exception 'Choose whether the expense is paid now or payable later.';
    end if;

    if length(btrim(coalesce(p_input->>'description','')))<3 then
      raise exception 'Expense description is required.';
    end if;

    if p_input->>'payment_mode'='PAID_NOW' then
      select id into payment_account
      from public.finance_accounts
      where id=nullif(p_input->>'payment_account_id','')::uuid
        and organization_id=org
        and account_subtype in ('CASH','BANK','MOBILE_BANK')
        and is_active;

      if payment_account is null then
        raise exception 'Choose an active cash or bank account for a paid expense.';
      end if;
    else
      payment_account:=null;
    end if;

    insert into public.finance_expenses(
      organization_id,
      expense_date,
      category_id,
      expense_account_id,
      payment_mode,
      payment_account_id,
      vendor_id,
      staff_id,
      amount,
      description,
      receipt_reference,
      status,
      approval_id,
      authorized_by,
      authorization_reason,
      submitted_by,
      posted_by,
      posted_at
    )
    values(
      org,
      coalesce(nullif(p_input->>'expense_date','')::date,current_date),
      category.id,
      category.expense_account_id,
      p_input->>'payment_mode',
      payment_account,
      nullif(p_input->>'vendor_id','')::uuid,
      nullif(p_input->>'staff_id','')::uuid,
      amount,
      btrim(p_input->>'description'),
      nullif(btrim(p_input->>'receipt_reference'),''),
      'POSTED',
      null,
      actor,
      reason,
      actor,
      actor,
      now()
    )
    returning * into expense;

    if expense.payment_mode='PAID_NOW' then
      perform public.finance_post_journal(
        org,
        expense.expense_date,
        'EXPENSE',
        'EXPENSE',
        expense.id::text,
        'Expense '||expense.expense_no,
        actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',expense.expense_account_id,
            'debit',expense.amount,
            'credit',0,
            'memo',expense.description
          ),
          jsonb_build_object(
            'account_id',payment_account,
            'debit',0,
            'credit',expense.amount,
            'memo',coalesce(expense.receipt_reference,'Paid expense')
          )
        )
      );
    else
      insert into public.finance_payables(
        organization_id,
        payable_type,
        staff_id,
        vendor_id,
        source_type,
        source_id,
        payable_account_id,
        original_amount,
        due_on,
        created_by
      )
      values(
        org,
        case
          when expense.vendor_id is not null then 'VENDOR'
          when expense.staff_id is not null then 'STAFF_REIMBURSEMENT'
          else 'OTHER'
        end,
        expense.staff_id,
        expense.vendor_id,
        'EXPENSE',
        expense.id::text,
        case
          when expense.vendor_id is not null then
            (select id from public.finance_accounts where organization_id=org and account_subtype='VENDOR_PAYABLE' limit 1)
          else
            (select id from public.finance_accounts where organization_id=org and account_subtype='STAFF_PAYABLE' limit 1)
        end,
        expense.amount,
        expense.expense_date+30,
        actor
      )
      returning * into payable;

      update public.finance_expenses
      set payable_id=payable.id
      where id=expense.id;

      perform public.finance_post_journal(
        org,
        expense.expense_date,
        'EXPENSE',
        'EXPENSE',
        expense.id::text,
        'Expense payable '||expense.expense_no,
        actor,
        jsonb_build_array(
          jsonb_build_object(
            'account_id',expense.expense_account_id,
            'debit',expense.amount,
            'credit',0,
            'memo',expense.description
          ),
          jsonb_build_object(
            'account_id',payable.payable_account_id,
            'debit',0,
            'credit',expense.amount,
            'memo','Payable for expense '||expense.expense_no
          )
        )
      );
    end if;

    result:=jsonb_build_object(
      'id',expense.id,
      'expenseNo',expense.expense_no,
      'message','Expense posted to the ledger.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'FINANCE_EXPENSE',
      expense.id::text,
      'CREATE_EXPENSE_DIRECT',
      reason,
      jsonb_build_object(
        'expense_no',expense.expense_no,
        'amount',expense.amount,
        'payment_mode',expense.payment_mode,
        'status',expense.status
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  elsif action='RUN_COMPENSATION' then
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

    if policy.id is null then
      raise exception 'No active teacher compensation policy is configured.';
    end if;

    insert into public.teacher_compensation_runs(
      organization_id,
      period_start,
      period_end,
      policy_version_id,
      status,
      total_amount,
      submitted_by,
      approved_by,
      approved_at,
      authorized_by,
      authorization_reason
    )
    values(
      org,
      (p_input->>'period_start')::date,
      (p_input->>'period_end')::date,
      policy.id,
      'APPROVED',
      (preview->>'total')::numeric,
      actor,
      actor,
      now(),
      actor,
      reason
    )
    returning * into compensation;

    for line in
      select value
      from jsonb_array_elements(preview->'rows')
    loop
      insert into public.teacher_compensation_lines(
        run_id,
        teacher_id,
        admission_id,
        line_type,
        source_type,
        source_id,
        amount,
        calculation
      )
      values(
        compensation.id,
        (line->>'teacherId')::uuid,
        nullif(line->>'admissionId','')::uuid,
        line->>'lineType',
        line->>'sourceType',
        line->>'sourceId',
        (line->>'amount')::numeric,
        coalesce(line->'calculation','{}'::jsonb)
      )
      on conflict(run_id,source_type,source_id) do nothing;
    end loop;

    for v_teacher_id in
      select distinct l.teacher_id
      from public.teacher_compensation_lines l
      where l.run_id=compensation.id
      from public.teacher_compensation_lines
      where run_id=compensation.id
    loop
      select coalesce(sum(l.amount),0)
      into teacher_total
      from public.teacher_compensation_lines l
      where l.run_id=compensation.id
        and l.teacher_id=v_teacher_id;

      if teacher_total>0 then
        insert into public.finance_payables(
          organization_id,
          payable_type,
          staff_id,
          source_type,
          source_id,
          payable_account_id,
          original_amount,
          due_on,
          created_by
        )
        values(
          org,
          'TEACHER_COMPENSATION',
          v_teacher_id,
          'COMPENSATION_RUN',
          compensation.id::text||':'||teacher_id::text,
          (
            select id
            from public.finance_accounts
            where organization_id=org
              and account_subtype='TEACHER_PAYABLE'
            limit 1
          ),
          teacher_total,
          compensation.period_end,
          actor
        )
        on conflict(source_type,source_id) do nothing;
      end if;
    end loop;

    perform public.finance_post_journal(
      org,
      compensation.period_end,
      'COMPENSATION_RUN',
      'COMPENSATION_RUN',
      compensation.id::text,
      'Teacher compensation run '||compensation.run_no,
      actor,
      (
        select jsonb_build_array(
          jsonb_build_object(
            'account_id',(
              select id
              from public.finance_accounts
              where organization_id=org
                and account_subtype='TEACHING_COMPENSATION'
              limit 1
            ),
            'debit',compensation.total_amount,
            'credit',0,
            'memo','Teaching compensation expense'
          )
        ) ||
        coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'account_id',(
                select id
                from public.finance_accounts
                where organization_id=org
                  and account_subtype='TEACHER_PAYABLE'
                limit 1
              ),
              'debit',0,
              'credit',sum(l.amount),
              'memo','Payable for teacher '||l.teacher_id::text
            )
          )
          from public.teacher_compensation_lines l
          where l.run_id=compensation.id
          group by l.teacher_id
        ),'[]'::jsonb)
      )
    );

    result:=jsonb_build_object(
      'id',compensation.id,
      'runNo',compensation.run_no,
      'message','Teacher compensation run approved and posted.',
      'total',compensation.total_amount
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'TEACHER_COMPENSATION_RUN',
      compensation.id::text,
      'RUN_COMPENSATION',
      reason,
      jsonb_build_object(
        'run_no',compensation.run_no,
        'status',compensation.status,
        'total_amount',compensation.total_amount
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );

  else
    if not exists(
      select 1
      from public.staff
      where id=nullif(p_input->>'teacher_id','')::uuid
        and status='ACTIVE'
    ) then
      raise exception 'Choose an active teacher.';
    end if;

    amount:=(p_input->>'amount')::numeric;

    if amount is null or amount<=0 or amount<>round(amount,2) then
      raise exception 'Adjustment amount must be a positive two-decimal amount.';
    end if;

    if (p_input->>'effective_period')::date is null then
      raise exception 'Choose an effective period.';
    end if;

    insert into public.teacher_compensation_adjustments(
      teacher_id,
      amount,
      adjustment_type,
      effective_period,
      reason,
      approval_id,
      authorized_by,
      authorization_reason,
      status,
      requested_by,
      approved_by,
      approved_at
    )
    values(
      (p_input->>'teacher_id')::uuid,
      amount,
      coalesce(p_input->>'adjustment_type','ADJUSTMENT'),
      (p_input->>'effective_period')::date,
      reason,
      null,
      actor,
      reason,
      'APPROVED',
      actor,
      actor,
      now()
    )
    returning id into adjustment_id;

    result:=jsonb_build_object(
      'id',adjustment_id,
      'message','Teacher compensation adjustment authorized and recorded.'
    );

    insert into public.audit_events(
      correlation_id,
      actor_profile_id,
      actor_staff_id,
      entity_type,
      entity_id,
      action,
      reason,
      after_data,
      metadata
    )
    values(
      req,
      actor,
      (select id from public.staff where profile_id=actor limit 1),
      'TEACHER_COMPENSATION_ADJUSTMENT',
      adjustment_id::text,
      'APPLY_COMP_ADJUSTMENT',
      reason,
      jsonb_build_object(
        'teacher_id',(p_input->>'teacher_id')::uuid,
        'amount',amount,
        'effective_period',(p_input->>'effective_period')::date,
        'status','APPROVED'
      ),
      jsonb_build_object('finance_flow','V3_DIRECT_ADMIN')
    );
  end if;

  insert into public.admission_command_keys(
    request_id,actor_id,payload,result
  )
  values(req,actor,p_input,result);

  return result;
end;
$$;

revoke all on function public.finance_v3_accounting_command(jsonb) from public,anon;
grant execute on function public.finance_v3_accounting_command(jsonb) to authenticated;
