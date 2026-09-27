-- Staff review of an applicant's published requirements. The original public
-- application and its terms snapshot are never edited by this workflow.
create table public.admission_requirement_reviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.public_admission_applications(id),
  requirement_label text not null check (length(btrim(requirement_label)) between 3 and 160),
  status text not null check (status in ('PENDING', 'VERIFIED', 'FOLLOW_UP')),
  note text not null default '' check (length(note) <= 1000),
  revision integer not null check (revision > 0),
  reviewed_by uuid not null references public.profiles(id),
  reviewed_at timestamptz not null default now(),
  unique(application_id, requirement_label, revision)
);
create index admission_requirement_reviews_latest_idx
  on public.admission_requirement_reviews(application_id, requirement_label, revision desc);
alter table public.admission_requirement_reviews enable row level security;
grant select on public.admission_requirement_reviews to authenticated;
revoke insert, update, delete on public.admission_requirement_reviews from anon, authenticated;
create policy admission_requirement_reviews_staff_read
  on public.admission_requirement_reviews for select to authenticated
  using (public.has_permission('crm.prospects.view'));

create or replace function public.review_admission_requirement(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_application public.public_admission_applications;
  v_label text := btrim(coalesce(p_input->>'requirement_label',''));
  v_status text := upper(btrim(coalesce(p_input->>'status','')));
  v_note text := btrim(coalesce(p_input->>'note',''));
  v_previous public.admission_requirement_reviews;
  v_revision integer;
  v_review public.admission_requirement_reviews;
begin
  if v_actor is null or not public.has_permission('crm.followups.manage') then
    raise exception 'CRM review permission is required.';
  end if;
  if length(v_label) not between 3 and 160 or v_status not in ('PENDING','VERIFIED','FOLLOW_UP')
    or length(v_note) > 1000 or (v_status = 'FOLLOW_UP' and length(v_note) < 5) then
    raise exception 'Choose a valid requirement, status and follow-up note.';
  end if;
  select * into v_application from public.public_admission_applications
    where id = (p_input->>'application_id')::uuid for update;
  if not found then raise exception 'Admission application was not found.'; end if;
  if exists (select 1 from public.prospects where id = v_application.prospect_id and status = 'CONVERTED') then
    raise exception 'This application has already been converted. Continue from Admissions.';
  end if;
  select * into v_previous from public.admission_requirement_reviews
    where application_id = v_application.id and requirement_label = v_label
    order by revision desc limit 1;
  if coalesce(v_previous.revision, 0) <> coalesce((p_input->>'expected_revision')::integer, 0) then
    raise exception 'The checklist changed. Refresh before recording your review.';
  end if;
  v_revision := coalesce(v_previous.revision, 0) + 1;
  insert into public.admission_requirement_reviews
    (application_id, requirement_label, status, note, revision, reviewed_by)
  values (v_application.id, v_label, v_status, v_note, v_revision, v_actor)
  returning * into v_review;
  insert into public.audit_events
    (actor_profile_id, entity_type, entity_id, action, reason, before_data, after_data)
  values (v_actor, 'admission_requirement_review', v_application.id::text,
    'REVIEW', nullif(v_note,''), case when v_previous.id is null then null else to_jsonb(v_previous) end,
    to_jsonb(v_review));
  return jsonb_build_object('id', v_review.id, 'revision', v_revision, 'status', v_status);
end;
$$;
revoke all on function public.review_admission_requirement(jsonb) from public, anon;
grant execute on function public.review_admission_requirement(jsonb) to authenticated;
