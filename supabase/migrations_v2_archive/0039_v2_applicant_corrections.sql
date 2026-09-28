-- Account-free applicant correction channel.
-- Applicants authenticate a correction request with their Prospect reference and
-- the mobile number submitted on that Prospect. The original application remains
-- immutable; corrections are reviewable requests for staff action.

create table public.public_admission_corrections (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.public_admission_applications(id),
  prospect_id uuid not null references public.prospects(id),
  requested_changes text not null check (length(btrim(requested_changes)) between 10 and 2000),
  submitted_mobile text not null check (length(btrim(submitted_mobile)) between 5 and 40),
  status text not null default 'SUBMITTED'
    check (status in ('SUBMITTED', 'ACKNOWLEDGED', 'APPLIED', 'REJECTED')),
  staff_note text not null default '' check (length(staff_note) <= 1000),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id)
);

create index public_admission_corrections_application_idx
  on public.public_admission_corrections(application_id, submitted_at desc);
create index public_admission_corrections_status_idx
  on public.public_admission_corrections(status, submitted_at desc);

alter table public.public_admission_corrections enable row level security;
grant select on public.public_admission_corrections to authenticated;
revoke insert, update, delete on public.public_admission_corrections from anon, authenticated;

create policy public_admission_corrections_staff_read
on public.public_admission_corrections for select to authenticated
using (public.has_permission('crm.prospects.view') or public.has_permission('admissions.view'));

create or replace function public.submit_applicant_correction(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prospect public.prospects;
  v_application public.public_admission_applications;
  v_reference text := upper(btrim(coalesce(p_payload->>'prospect_no', '')));
  v_mobile text := regexp_replace(coalesce(p_payload->>'mobile', ''), '\D', '', 'g');
  v_changes text := btrim(coalesce(p_payload->>'requested_changes', ''));
  v_correction public.public_admission_corrections;
begin
  if length(v_reference) < 5 or length(v_changes) not between 10 and 2000
     or length(v_mobile) < 8 then
    raise exception 'Enter a valid reference, mobile number and correction request.';
  end if;

  select * into v_prospect
  from public.prospects
  where upper(prospect_no) = v_reference
    and regexp_replace(coalesce(mobile, ''), '\D', '', 'g') = v_mobile
  limit 1;

  if not found then
    raise exception 'We could not verify that reference and mobile number.';
  end if;

  select * into v_application
  from public.public_admission_applications
  where prospect_id = v_prospect.id
  limit 1;

  if not found then
    raise exception 'This reference does not have an admission application.';
  end if;

  insert into public.public_admission_corrections
    (application_id, prospect_id, requested_changes, submitted_mobile)
  values
    (v_application.id, v_prospect.id, v_changes, p_payload->>'mobile')
  returning * into v_correction;

  insert into public.audit_events
    (entity_type, entity_id, action, reason, after_data)
  values
    ('public_admission_correction', v_correction.id::text, 'SUBMIT',
     'Account-free applicant correction request submitted.',
     jsonb_build_object(
       'application_id', v_application.id,
       'prospect_id', v_prospect.id,
       'prospect_no', v_prospect.prospect_no
     ));

  return jsonb_build_object(
    'ok', true,
    'reference', v_prospect.prospect_no,
    'correction_id', v_correction.id
  );
end;
$$;

create or replace function public.review_applicant_correction(p_input jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_correction public.public_admission_corrections;
  v_status text := upper(btrim(coalesce(p_input->>'status', '')));
  v_note text := btrim(coalesce(p_input->>'staff_note', ''));
  v_before jsonb;
begin
  if v_actor is null or not (
    public.has_permission('crm.prospects.manage')
    or public.has_permission('admissions.manage')
  ) then
    raise exception 'Admission correction review permission is required.';
  end if;

  if v_status not in ('ACKNOWLEDGED', 'APPLIED', 'REJECTED') or length(v_note) > 1000 then
    raise exception 'Choose a valid correction status and staff note.';
  end if;

  select * into v_correction
  from public.public_admission_corrections
  where id = (p_input->>'correction_id')::uuid
  for update;

  if not found then
    raise exception 'Correction request was not found.';
  end if;
  if v_correction.status in ('APPLIED', 'REJECTED') then
    raise exception 'This correction request is already finalized.';
  end if;

  v_before := to_jsonb(v_correction);
  update public.public_admission_corrections
  set status = v_status,
      staff_note = v_note,
      reviewed_at = now(),
      reviewed_by = v_actor
  where id = v_correction.id;

  insert into public.audit_events
    (actor_profile_id, entity_type, entity_id, action, reason, before_data, after_data)
  values
    (v_actor, 'public_admission_correction', v_correction.id::text, 'REVIEW',
     nullif(v_note, ''), v_before,
     (select to_jsonb(c) from public.public_admission_corrections c where c.id = v_correction.id));

  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

revoke all on function public.submit_applicant_correction(jsonb) from public, authenticated;
grant execute on function public.submit_applicant_correction(jsonb) to anon, authenticated;
revoke all on function public.review_applicant_correction(jsonb) from public, anon;
grant execute on function public.review_applicant_correction(jsonb) to authenticated;
