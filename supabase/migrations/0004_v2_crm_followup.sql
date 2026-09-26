-- Sohoj Academy ERP v2
-- Prospect follow-up workflow and controlled CRM status transitions.

alter table public.prospect_followups
  add constraint prospect_followup_type_check
  check (
    followup_type in (
      'CALL',
      'WHATSAPP',
      'IN_PERSON',
      'COUNSELLING',
      'TRIAL',
      'OTHER'
    )
  ) not valid;

alter table public.prospect_followups
  validate constraint prospect_followup_type_check;

create or replace function public.is_valid_prospect_transition(
  p_from public.prospect_status,
  p_to public.prospect_status
)
returns boolean
language sql
immutable
as $$
  select
    p_from = p_to
    or (p_from='NEW' and p_to in ('CONTACTED','COUNSELLING','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='CONTACTED' and p_to in ('COUNSELLING','TRIAL_SCHEDULED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='COUNSELLING' and p_to in ('TRIAL_SCHEDULED','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_SCHEDULED' and p_to in ('TRIAL_ATTENDED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='TRIAL_ATTENDED' and p_to in ('COUNSELLING','REGISTERED','FUTURE_FOLLOW_UP','LOST'))
    or (p_from='REGISTERED' and p_to='LOST')
    or (p_from='FUTURE_FOLLOW_UP' and p_to in ('CONTACTED','COUNSELLING','TRIAL_SCHEDULED','LOST'))
    or (p_from='LOST' and p_to='FUTURE_FOLLOW_UP');
$$;

create or replace function public.record_prospect_followup(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_prospect public.prospects;
  v_followup public.prospect_followups;
  v_followup_type text;
  v_new_status public.prospect_status;
  v_next_follow_up_at timestamptz;
  v_notes text;
  v_outcome text;
  v_lost_reason text;
  v_correlation_id uuid := gen_random_uuid();
  v_actor_role text;
  v_before jsonb;
begin
  if v_actor is null or not public.has_permission('crm.followups.manage') then
    raise exception 'You are not authorized to record CRM follow-ups.';
  end if;

  begin
    select * into v_prospect
    from public.prospects
    where id=(p_input->>'prospect_id')::uuid
    for update;
  exception when others then
    raise exception 'Prospect identity is invalid.';
  end;

  if v_prospect.id is null then
    raise exception 'Prospect was not found.';
  end if;

  if v_prospect.status='CONVERTED' then
    raise exception 'Converted prospects are read-only in CRM. Continue from the Student record.';
  end if;

  v_followup_type := upper(btrim(coalesce(p_input->>'followup_type','')));
  if v_followup_type not in ('CALL','WHATSAPP','IN_PERSON','COUNSELLING','TRIAL','OTHER') then
    raise exception 'Select a valid follow-up type.';
  end if;

  v_notes := nullif(btrim(coalesce(p_input->>'notes','')), '');
  if v_notes is null then
    raise exception 'Follow-up notes are required.';
  end if;

  v_outcome := nullif(btrim(coalesce(p_input->>'outcome','')), '');
  v_lost_reason := nullif(btrim(coalesce(p_input->>'lost_reason','')), '');

  begin
    v_new_status := coalesce(
      nullif(p_input->>'new_status','')::public.prospect_status,
      v_prospect.status
    );
    v_next_follow_up_at := nullif(p_input->>'next_follow_up_at','')::timestamptz;
  exception when others then
    raise exception 'Follow-up status or next follow-up date is invalid.';
  end;

  if not public.is_valid_prospect_transition(v_prospect.status,v_new_status) then
    raise exception 'Prospect status cannot move from % to % through a follow-up.', v_prospect.status, v_new_status;
  end if;

  if v_new_status='LOST' and v_lost_reason is null then
    raise exception 'Lost reason is required when a prospect is marked LOST.';
  end if;

  if v_new_status='FUTURE_FOLLOW_UP' and v_next_follow_up_at is null then
    raise exception 'Next follow-up date is required for FUTURE FOLLOW UP.';
  end if;

  v_before := to_jsonb(v_prospect);

  insert into public.prospect_followups(
    prospect_id,
    followup_type,
    occurred_at,
    outcome,
    notes,
    next_follow_up_at,
    recorded_by
  )
  values(
    v_prospect.id,
    v_followup_type,
    now(),
    v_outcome,
    v_notes,
    v_next_follow_up_at,
    v_actor
  )
  returning * into v_followup;

  update public.prospects
  set
    status=v_new_status,
    next_follow_up_at=v_next_follow_up_at,
    lost_reason=case
      when v_new_status='LOST' then v_lost_reason
      when v_prospect.status='LOST' and v_new_status<>'LOST' then null
      else lost_reason
    end,
    updated_at=now()
  where id=v_prospect.id
  returning * into v_prospect;

  select sr.code into v_actor_role
  from public.user_role_assignments ura
  join public.system_roles sr on sr.id=ura.role_id
  where ura.profile_id=v_actor
    and ura.is_active
    and ura.effective_from<=current_date
    and (ura.effective_to is null or ura.effective_to>=current_date)
  order by case when sr.code='ADMIN' then 0 else 1 end, sr.code
  limit 1;

  insert into public.audit_events(
    correlation_id,
    actor_profile_id,
    actor_staff_id,
    actor_role_code,
    branch_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data,
    metadata
  )
  values(
    v_correlation_id,
    v_actor,
    (select id from public.staff where profile_id=v_actor limit 1),
    v_actor_role,
    v_prospect.branch_id,
    'PROSPECT',
    v_prospect.id::text,
    'RECORD_FOLLOW_UP',
    v_notes,
    v_before,
    to_jsonb(v_prospect),
    jsonb_build_object(
      'workflow','PROSPECT_FOLLOW_UP',
      'followup_id',v_followup.id,
      'followup_type',v_followup.followup_type,
      'outcome',v_followup.outcome
    )
  );

  return jsonb_build_object(
    'prospect_id',v_prospect.id,
    'prospect_no',v_prospect.prospect_no,
    'followup_id',v_followup.id,
    'status',v_prospect.status,
    'correlation_id',v_correlation_id
  );
end;
$$;

revoke all on function public.record_prospect_followup(jsonb) from public;
grant execute on function public.record_prospect_followup(jsonb) to authenticated;
