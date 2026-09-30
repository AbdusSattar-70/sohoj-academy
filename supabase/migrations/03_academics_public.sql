-- ACTIVE V3 MIGRATION · 03_academics_public.sql
-- Source: supabase/baseline_v3/0003_v3_academics_public.sql
-- Apply only on a clean database (no prior schema_migrations history).

-- SOHOJ ACADEMY V3 CLEAN BASELINE · PART 03
-- Generated from the reviewed V2 schema history for a CLEAN database.
-- No data migration is included. Apply after baseline parts 01 and 02.

-- ============================================================
-- SOURCE: 0029_v2_unlisted_school_review.sql
-- ============================================================

-- Preserve unlisted school names on the prospect until staff verifies them.
-- Patch the original submit RPC without rewriting its established validation.
do $migration$
declare
  definition text;
  old_block text := $old$
  elsif v_school_name is not null then
    select * into v_school
    from public.schools
    where organization_id=v_org.id
      and lower(btrim(name))=lower(v_school_name)
      and is_active
    order by is_verified desc, created_at asc
    limit 1;

    if v_school.id is null then
      insert into public.schools(
        organization_id,
        name,
        is_verified,
        is_active
      )
      values(
        v_org.id,
        v_school_name,
        false,
        true
      )
      returning * into v_school;
    end if;

    v_school_name := v_school.name;
  end if;
$old$;
  new_block text := $new$
  elsif v_school_name is not null then
    -- Keep unlisted names as prospect snapshots for staff verification.
    null;
  end if;
$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure)
  into definition;

  if position(old_block in definition) = 0 then
    if position(new_block in definition) > 0 then
      return;
    end if;
    raise exception 'Could not locate the unlisted-school block in submit_public_interest.';
  end if;

  execute replace(definition, old_block, new_block);
end;
$migration$;



-- ============================================================
-- SOURCE: 0030_v2_public_catalogue_and_local_window.sql
-- ============================================================

-- Public catalogue is entirely curated in the ERP. The open state uses the
-- organization's local date, the same date used when accepting a submission.
create or replace function public.list_public_programme_offerings()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select
      o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id,
      ay.name as academic_year_name,
      b.name as branch_name,
      c.name as class_name,
      ag.name as group_name,
      o.showcase_title, o.showcase_title_bn,
      o.showcase_description, o.showcase_description_bn,
      o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case
        when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN'
      end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', s.id, 'code', s.code, 'name', s.name
        ) order by pos.sort_order), '[]'::jsonb)
        from public.programme_offering_subjects pos
        join public.subjects s on s.id = pos.subject_id
        where pos.offering_id = o.id and s.is_active
      ) as subjects,
      (
        select jsonb_build_object(
          'billing_cycle', fp.billing_cycle,
          'currency_code', fp.currency_code,
          'components', coalesce((
            select jsonb_agg(jsonb_build_object(
              'code', fc.code, 'name', fc.name, 'amount', fc.amount,
              'charge_type', fc.charge_type, 'recurrence', fc.recurrence
            ) order by fc.sort_order)
            from public.fee_plan_components fc
            where fc.fee_plan_version_id = fp.id
          ), '[]'::jsonb)
        )
        from public.fee_plan_versions fp
        where fp.offering_id = o.id and fp.status = 'ACTIVE'
        limit 1
      ) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at
    limit 24
  ) x;
$$;

revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;

-- The original submit function has subsequent school-review changes. Replace
-- only its date expression so those validations and snapshots remain intact.
do $migration$
declare
  definition text;
  old_expression text := $old$v_today date := (timezone('utc', now()))::date;$old$;
  new_expression text := $new$v_today date;$new$;
  org_lookup text := $old$
  where code='SOHOJ' and is_active
  limit 1;
$old$;
  local_date_lookup text := $new$
  where code='SOHOJ' and is_active
  limit 1;

  v_today := timezone(v_org.timezone, now())::date;
$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure) into definition;
  if position(old_expression in definition) = 0 then
    if position(new_expression in definition) > 0 and position(local_date_lookup in definition) > 0 then return; end if;
    raise exception 'Could not locate submission date expression; review submit_public_interest before migrating.';
  end if;
  if position(org_lookup in definition) = 0 then
    raise exception 'Could not locate organization lookup; review submit_public_interest before migrating.';
  end if;
  execute replace(replace(definition, old_expression, new_expression), org_lookup, local_date_lookup);
end;
$migration$;

-- Relationships are an administrator-managed public form vocabulary.
grant select on public.guardian_relationships to anon;
create policy guardian_relationships_public_read
on public.guardian_relationships for select to anon
using (is_active);



-- ============================================================
-- SOURCE: 0031_v2_public_admission_application.sql
-- ============================================================

-- Public admission applications remain Prospects until staff verifies and accepts an admission.
-- Keep the applicant's original declarations and the published terms visible at submission.
alter table public.programme_offerings
  add column if not exists public_schedule text,
  add column if not exists public_requirements text,
  add column if not exists admission_policy text,
  add column if not exists public_schedule_bn text,
  add column if not exists public_requirements_bn text,
  add column if not exists admission_policy_bn text;

create table public.public_admission_applications (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid not null unique references public.prospects(id),
  offering_id uuid not null references public.programme_offerings(id),
  fee_plan_version_id uuid references public.fee_plan_versions(id),
  guardian_address text not null check (length(btrim(guardian_address)) between 5 and 300),
  academic_background text check (academic_background is null or length(academic_background) <= 500),
  requirements_acknowledged boolean not null check (requirements_acknowledged),
  policy_acknowledged boolean not null check (policy_acknowledged),
  published_terms_snapshot jsonb not null,
  submitted_at timestamptz not null default now()
);
create index public_admission_applications_offering_idx
  on public.public_admission_applications(offering_id, submitted_at desc);
alter table public.public_admission_applications enable row level security;
grant select on public.public_admission_applications to authenticated;
revoke insert, update, delete on public.public_admission_applications from anon, authenticated;
create policy public_admission_applications_staff_read
on public.public_admission_applications for select to authenticated
using (public.has_permission('crm.prospects.view') or public.has_permission('admissions.view'));

-- The existing public-controls RPC owns the offering row lock, validation and audit.
-- Extend its update atomically, keeping callers that omit the new keys compatible.
do $migration$
declare
  definition text;
  old_block text := $old$    applications_close_on = v_close,
    updated_at = now()$old$;
  new_block text := $new$    applications_close_on = v_close,
    public_schedule = case when p_input ? 'public_schedule' then nullif(btrim(p_input->>'public_schedule'), '') else public_schedule end,
    public_requirements = case when p_input ? 'public_requirements' then nullif(btrim(p_input->>'public_requirements'), '') else public_requirements end,
    admission_policy = case when p_input ? 'admission_policy' then nullif(btrim(p_input->>'admission_policy'), '') else admission_policy end,
    public_schedule_bn = case when p_input ? 'public_schedule_bn' then nullif(btrim(p_input->>'public_schedule_bn'), '') else public_schedule_bn end,
    public_requirements_bn = case when p_input ? 'public_requirements_bn' then nullif(btrim(p_input->>'public_requirements_bn'), '') else public_requirements_bn end,
    admission_policy_bn = case when p_input ? 'admission_policy_bn' then nullif(btrim(p_input->>'admission_policy_bn'), '') else admission_policy_bn end,
    updated_at = now()$new$;
begin
  select pg_get_functiondef('public.update_programme_offering_public_controls(jsonb)'::regprocedure) into definition;
  if position(old_block in definition) = 0 then
    if position(new_block in definition) > 0 then return; end if;
    raise exception 'Could not extend offering controls; inspect RPC definition before migrating.';
  end if;
  execute replace(definition, old_block, new_block);
end;
$migration$;

-- Public submission stays the only anonymous mutation path. Validate the fuller
-- application before creating the Prospect, then retain an immutable snapshot.
do $migration$
declare
  definition text;
  old_validation text := $old$  select * into v_org
  from public.organizations$old$;
  new_validation text := $new$  if v_intent = 'admission' then
    if length(btrim(coalesce(p_payload->>'guardian_address', ''))) < 5 then
      raise exception 'Guardian address is required for an admission application.';
    end if;
    if coalesce((p_payload->>'requirements_acknowledged')::boolean, false) is not true
      or coalesce((p_payload->>'policy_acknowledged')::boolean, false) is not true then
      raise exception 'Review and acknowledge the programme requirements and admission policy.';
    end if;
  end if;

  select * into v_org
  from public.organizations$new$;
  old_insert text := $old$  insert into public.audit_events(
    correlation_id,
    entity_type,$old$;
  new_insert text := $new$  if v_intent = 'admission' then
    insert into public.public_admission_applications (
      prospect_id, offering_id, fee_plan_version_id, guardian_address,
      academic_background, requirements_acknowledged, policy_acknowledged,
      published_terms_snapshot
    ) values (
      v_prospect.id, v_offering.id,
      (select id from public.fee_plan_versions where offering_id = v_offering.id and status = 'ACTIVE' limit 1),
      btrim(p_payload->>'guardian_address'),
      nullif(btrim(coalesce(p_payload->>'academic_background', '')), ''),
      true, true,
      jsonb_build_object(
        'offering_name', coalesce(v_offering.showcase_title, v_offering.name),
        'requirements', v_offering.public_requirements,
        'policy', v_offering.admission_policy,
        'schedule', v_offering.public_schedule,
        'applications_open_on', v_offering.applications_open_on,
        'applications_close_on', v_offering.applications_close_on
      )
    );
  end if;

  insert into public.audit_events(
    correlation_id,
    entity_type,$new$;
begin
  select pg_get_functiondef('public.submit_public_interest(jsonb)'::regprocedure) into definition;
  if position(old_validation in definition) = 0 or position(old_insert in definition) = 0 then
    raise exception 'Could not extend public admission submission; inspect RPC definition before migrating.';
  end if;
  execute replace(replace(definition, old_validation, new_validation), old_insert, new_insert);
end;
$migration$;

-- The public catalogue is intentionally display-safe; include only curated terms.
create or replace function public.list_public_programme_offerings()
returns jsonb language sql security definer set search_path = public stable as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.showcase_sort_order, x.created_at), '[]'::jsonb)
  from (
    select o.id, o.code, o.name, o.class_id, o.program_id, o.group_id,
      o.branch_id, o.academic_year_id, ay.name as academic_year_name,
      b.name as branch_name, c.name as class_name, ag.name as group_name,
      o.showcase_title, o.showcase_title_bn, o.showcase_description,
      o.showcase_description_bn, o.showcase_eyebrow, o.showcase_eyebrow_bn,
      o.showcase_icon, o.showcase_sort_order,
      o.public_schedule, o.public_schedule_bn, o.public_requirements,
      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (o.is_accepting_applications
        and (o.applications_open_on is null or o.applications_open_on <= local_day.today)
        and (o.applications_close_on is null or o.applications_close_on >= local_day.today)
      ) as is_accepting_applications,
      case when not o.is_accepting_applications then 'CLOSED'
        when o.applications_open_on > local_day.today then 'UPCOMING'
        when o.applications_close_on < local_day.today then 'CLOSED'
        else 'OPEN' end as application_state,
      o.applications_open_on, o.applications_close_on, o.created_at,
      (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name)
        order by pos.sort_order), '[]'::jsonb)
       from public.programme_offering_subjects pos
       join public.subjects s on s.id = pos.subject_id
       where pos.offering_id = o.id and s.is_active) as subjects,
      (select jsonb_build_object('billing_cycle', fp.billing_cycle,
        'currency_code', fp.currency_code,
        'components', coalesce((select jsonb_agg(jsonb_build_object(
          'code', fc.code, 'name', fc.name, 'amount', fc.amount,
          'charge_type', fc.charge_type, 'recurrence', fc.recurrence)
          order by fc.sort_order) from public.fee_plan_components fc
          where fc.fee_plan_version_id = fp.id), '[]'::jsonb))
       from public.fee_plan_versions fp
       where fp.offering_id = o.id and fp.status = 'ACTIVE' limit 1) as fee_plan
    from public.programme_offerings o
    join public.organizations org on org.id = o.organization_id
    join public.academic_years ay on ay.id = o.academic_year_id
    join public.branches b on b.id = o.branch_id
    join public.classes c on c.id = o.class_id
    left join public.academic_groups ag on ag.id = o.group_id
    cross join lateral (select timezone(org.timezone, now())::date as today) local_day
    where o.is_website_visible and o.status = 'ACTIVE'
    order by o.showcase_sort_order, o.created_at limit 24
  ) x;
$$;
revoke all on function public.list_public_programme_offerings() from public;
grant execute on function public.list_public_programme_offerings() to anon, authenticated;



-- ============================================================
-- SOURCE: 0032_v2_question_bank_review.sql
-- ============================================================

-- Staff question authoring and independent review. Submitted revisions are immutable.
create table public.question_bank_items (
  id uuid primary key default gen_random_uuid(),
  root_id uuid references public.question_bank_items(id),
  revision integer not null default 1 check (revision > 0),
  batch_id uuid not null references public.batches(id),
  subject_id uuid not null references public.subjects(id),
  curriculum_version_id uuid references public.curriculum_versions(id),
  topic text not null check (length(btrim(topic)) between 2 and 180),
  difficulty text not null check (difficulty in ('FOUNDATION','STANDARD','ADVANCED')),
  question_type text not null check (question_type in ('MCQ','SHORT_ANSWER')),
  prompt text not null check (length(btrim(prompt)) between 10 and 3000),
  choices jsonb not null default '[]'::jsonb,
  answer_key text not null check (length(btrim(answer_key)) between 1 and 1500),
  explanation text check (explanation is null or length(explanation) <= 3000),
  status text not null default 'DRAFT' check (status in ('DRAFT','SUBMITTED','APPROVED','REJECTED')),
  author_id uuid not null references public.profiles(id),
  reviewer_id uuid references public.profiles(id),
  review_note text,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_at timestamptz,
  unique(root_id, revision),
  check ((status in ('APPROVED','REJECTED')) = (reviewer_id is not null))
);
create index question_bank_scope_idx on public.question_bank_items(batch_id, subject_id, created_at desc);
create unique index question_bank_one_draft on public.question_bank_items(coalesce(root_id,id)) where status = 'DRAFT';
alter table public.question_bank_items enable row level security;
revoke all on public.question_bank_items from anon, authenticated;

create or replace function public.question_bank_workspace()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare actor uuid := auth.uid(); reviewer boolean;
begin
  if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
  reviewer := public.has_permission('academics.assessments.approve');
  return jsonb_build_object(
    'batches', coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name) order by b.name)
      from public.batches b where b.is_active and (reviewer or public.has_permission('academics.sessions.manage')
        or exists (select 1 from public.class_sessions cs join public.staff st on st.id=cs.teacher_id
          where cs.batch_id=b.id and st.profile_id=actor))), '[]'::jsonb),
    'subjects', coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name) order by s.name)
      from public.subjects s where s.is_active and (reviewer or public.has_permission('academics.sessions.manage')
        or exists (select 1 from public.staff_subject_assignments sa join public.staff st on st.id=sa.staff_id
          where sa.subject_id=s.id and st.profile_id=actor and sa.effective_from<=current_date
            and (sa.effective_to is null or sa.effective_to>=current_date)))), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
      'id',q.id,'rootId',q.root_id,'revision',q.revision,'batchId',q.batch_id,'batch',b.name,
      'subjectId',q.subject_id,'subject',s.name,'curriculumVersionId',q.curriculum_version_id,
      'topic',q.topic,'difficulty',q.difficulty,'questionType',q.question_type,
      'prompt',q.prompt,'choices',q.choices,'answerKey',q.answer_key,'explanation',q.explanation,
      'status',q.status,'authorId',q.author_id,'author',p.display_name,'reviewNote',q.review_note,
      'createdAt',q.created_at) order by q.created_at desc)
      from public.question_bank_items q
      join public.batches b on b.id=q.batch_id
      join public.subjects s on s.id=q.subject_id
      join public.profiles p on p.id=q.author_id
      where q.author_id=actor or reviewer), '[]'::jsonb)
  );
end $$;

create or replace function public.question_bank_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  actor uuid := auth.uid(); act text := p_input->>'action'; rid uuid;
  q public.question_bank_items; b public.batches; s public.subjects;
  v_staff_id uuid; v_batch_id uuid; v_subject_id uuid; v_curriculum_id uuid;
  options jsonb; prompt_value text; answer_value text; note text;
  command_key public.admission_command_keys; result jsonb; next_id uuid;
begin
  if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
  if p_input is null or jsonb_typeof(p_input)<>'object' then raise exception 'Question command must be an object.'; end if;
  rid := (p_input->>'request_id')::uuid;
  if rid is null then raise exception 'Request identity required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into command_key from public.admission_command_keys where request_id=rid;
  if found then
    if command_key.actor_id<>actor or command_key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
    return command_key.result;
  end if;

  if act='CREATE_DRAFT' then
    if not (public.has_permission('academics.assessments.record') or public.has_permission('academics.sessions.manage')) then raise exception 'Question authoring permission required.'; end if;
    v_batch_id := (p_input->>'batch_id')::uuid;
    v_subject_id := (p_input->>'subject_id')::uuid;
    select * into b from public.batches where id=v_batch_id and is_active;
    select * into s from public.subjects where id=v_subject_id and is_active;
    if b.id is null or s.id is null or b.organization_id<>s.organization_id then raise exception 'Choose an active batch and subject in the same academy.'; end if;
    select id into v_staff_id from public.staff where profile_id=actor and status='ACTIVE';
    if not public.has_permission('academics.sessions.manage') and not exists (
      select 1 from public.class_sessions cs
      join public.staff_subject_assignments sa on sa.staff_id=cs.teacher_id and sa.subject_id=cs.subject_id
      where cs.batch_id=v_batch_id and cs.subject_id=v_subject_id and cs.teacher_id=v_staff_id
        and sa.effective_from<=cs.session_date and (sa.effective_to is null or sa.effective_to>=cs.session_date)
    ) then raise exception 'Question scope requires an assigned class and subject qualification.'; end if;
    v_curriculum_id := nullif(p_input->>'curriculum_version_id','')::uuid;
    if v_curriculum_id is not null and not exists(select 1 from public.curriculum_versions cv where cv.id=v_curriculum_id and cv.batch_id=v_batch_id and cv.subject_id=v_subject_id) then raise exception 'Curriculum version must match the batch and subject.'; end if;
    q.root_id := null;
    q.revision := 1;
  else
    select * into q from public.question_bank_items where id=(p_input->>'item_id')::uuid for update;
    if q.id is null then raise exception 'Question not found.'; end if;
    if act in ('EDIT_DRAFT','SUBMIT','REVISE_REJECTED') and q.author_id<>actor then raise exception 'Only the author can change this question.'; end if;
    if act in ('APPROVE','REJECT') then
      if not public.has_permission('academics.assessments.approve') then raise exception 'Question review permission required.'; end if;
      if q.author_id=actor then raise exception 'A question author cannot review their own work.'; end if;
      if q.status<>'SUBMITTED' then raise exception 'Only submitted questions can be reviewed.'; end if;
    elsif act='EDIT_DRAFT' or act='SUBMIT' then
      if q.status<>'DRAFT' then raise exception 'Only a draft can be edited or submitted.'; end if;
    elsif act='REVISE_REJECTED' then
      if q.status<>'REJECTED' then raise exception 'Only a rejected question can start a new revision.'; end if;
      if exists(select 1 from public.question_bank_items newer where newer.root_id=coalesce(q.root_id,q.id) and newer.revision>q.revision) then raise exception 'A newer revision already exists.'; end if;
    else raise exception 'Unknown question action.'; end if;
  end if;

  if act in ('CREATE_DRAFT','EDIT_DRAFT') then
    options := coalesce(p_input->'choices','[]'::jsonb);
    prompt_value := btrim(coalesce(p_input->>'prompt',''));
    answer_value := btrim(coalesce(p_input->>'answer_key',''));
    if length(prompt_value) not between 10 and 3000 or length(answer_value) not between 1 and 1500
      or length(btrim(coalesce(p_input->>'topic',''))) not between 2 and 180
      or coalesce(length(p_input->>'explanation'),0)>3000
      or p_input->>'difficulty' not in ('FOUNDATION','STANDARD','ADVANCED')
      or p_input->>'question_type' not in ('MCQ','SHORT_ANSWER') then raise exception 'Check the question content and difficulty.'; end if;
    if jsonb_typeof(options)<>'array' or jsonb_array_length(options)>6
      or exists(select 1 from jsonb_array_elements(options) e where jsonb_typeof(e)<>'string' or length(btrim(e#>>'{}')) not between 1 and 500) then raise exception 'Invalid answer choices.'; end if;
    if p_input->>'question_type'='MCQ' and (jsonb_array_length(options)<2 or answer_value not in ('A','B','C','D','E','F')
      or ascii(answer_value)-64>jsonb_array_length(options)) then raise exception 'MCQ needs choices and a matching answer key (A–F).'; end if;
    if p_input->>'question_type'='SHORT_ANSWER' and jsonb_array_length(options)<>0 then raise exception 'Short answers cannot have MCQ choices.'; end if;
    if act='CREATE_DRAFT' then
      insert into public.question_bank_items(batch_id,subject_id,curriculum_version_id,topic,difficulty,question_type,prompt,choices,answer_key,explanation,author_id)
      values(v_batch_id,v_subject_id,v_curriculum_id,btrim(p_input->>'topic'),p_input->>'difficulty',p_input->>'question_type',prompt_value,options,answer_value,nullif(btrim(coalesce(p_input->>'explanation','')),''),actor) returning * into q;
    else
      update public.question_bank_items set topic=btrim(p_input->>'topic'),difficulty=p_input->>'difficulty',question_type=p_input->>'question_type',prompt=prompt_value,choices=options,answer_key=answer_value,explanation=nullif(btrim(coalesce(p_input->>'explanation','')),'') where id=q.id returning * into q;
    end if;
  elsif act='REVISE_REJECTED' then
    insert into public.question_bank_items(root_id,revision,batch_id,subject_id,curriculum_version_id,topic,difficulty,question_type,prompt,choices,answer_key,explanation,author_id)
    values(coalesce(q.root_id,q.id),q.revision+1,q.batch_id,q.subject_id,q.curriculum_version_id,q.topic,q.difficulty,q.question_type,q.prompt,q.choices,q.answer_key,q.explanation,actor) returning * into q;
  elsif act='SUBMIT' then
    update public.question_bank_items set status='SUBMITTED',submitted_at=now() where id=q.id returning * into q;
  else
    note := btrim(coalesce(p_input->>'review_note',''));
    if length(note)<5 or length(note)>1000 then raise exception 'Give a review reason (5–1000 characters).'; end if;
    update public.question_bank_items set status=case when act='APPROVE' then 'APPROVED' else 'REJECTED' end,
      reviewer_id=actor,review_note=note,reviewed_at=now() where id=q.id returning * into q;
  end if;
  result := jsonb_build_object('id',q.id,'status',q.status,'revision',q.revision);
  insert into public.audit_events(actor_profile_id,branch_id,entity_type,entity_id,action,reason,after_data)
  values(actor,(select branch_id from public.batches where id=q.batch_id),'QUESTION_BANK_ITEM',q.id::text,act,
    case when act in ('APPROVE','REJECT') then note else null end,to_jsonb(q));
  insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
  return result;
end $$;
revoke all on function public.question_bank_workspace(),public.question_bank_command(jsonb) from public,anon;
grant execute on function public.question_bank_workspace(),public.question_bank_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0033_v2_admission_consent_evidence.sql
-- ============================================================

-- Signed forms stay in a private, append-only bucket. A metadata receipt binds the
-- stored bytes to the case, file hash, guardian signing date and receiving staff.
create table public.admission_consent_documents (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admission_cases(id),
  version integer not null check(version>0),
  storage_path text not null unique,
  sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png')),
  file_size integer not null check(file_size between 1 and 5242880),
  guardian_signed_on date not null,
  student_signed boolean not null default false,
  received_by uuid not null references public.profiles(id),
  received_at timestamptz not null default now(),
  unique(admission_id,version),
  check(storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$')
);
create index admission_consent_case_idx on public.admission_consent_documents(admission_id,version desc);
alter table public.admission_consent_documents enable row level security;
grant select on public.admission_consent_documents to authenticated;
revoke insert,update,delete on public.admission_consent_documents from anon,authenticated;
create policy admission_consent_staff_read on public.admission_consent_documents
  for select to authenticated using(public.has_permission('admissions.view'));

create or replace function public.record_admission_consent(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid := auth.uid(); c public.admission_cases; d public.admission_consent_documents;
  path text := p_input->>'storage_path'; present boolean; signed_on date;
begin
  if actor is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
  if path is null or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' then raise exception 'Invalid signed document path.'; end if;
  select * into c from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
  if c.id is null or c.status not in ('DRAFT','READY') then raise exception 'Consent can be received only before acceptance.'; end if;
  if split_part(path,'/',1)<>c.id::text then raise exception 'Document path must match the admission case.'; end if;
  signed_on := (p_input->>'guardian_signed_on')::date;
  if signed_on is null or signed_on>current_date then raise exception 'Enter a valid guardian signing date.'; end if;
  if (p_input->>'sha256') !~ '^[0-9a-f]{64}$' or (p_input->>'file_size')::integer not between 1 and 5242880
    or p_input->>'mime_type' not in ('application/pdf','image/jpeg','image/png') then raise exception 'Invalid signed document metadata.'; end if;
  if to_regclass('storage.objects') is null then raise exception 'Private document storage is unavailable.'; end if;
  execute 'select exists(select 1 from storage.objects where bucket_id=$1 and name=$2 and owner_id=$3)'
    into present using 'admission-consent',path,actor::text;
  if not present then raise exception 'Upload the signed form before recording its receipt.'; end if;
  insert into public.admission_consent_documents(admission_id,version,storage_path,sha256,mime_type,file_size,guardian_signed_on,student_signed,received_by)
  values(c.id,(select coalesce(max(version),0)+1 from public.admission_consent_documents where admission_id=c.id),
    path,p_input->>'sha256',p_input->>'mime_type',(p_input->>'file_size')::integer,signed_on,
    coalesce((p_input->>'student_signed')::boolean,false),actor) returning * into d;
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'ADMISSION_CONSENT',d.id::text,'RECEIVE_SIGNED_FORM',to_jsonb(d));
  return jsonb_build_object('id',d.id,'version',d.version);
end $$;
revoke all on function public.record_admission_consent(jsonb) from public,anon;
grant execute on function public.record_admission_consent(jsonb) to authenticated;

-- Storage is an installed Supabase schema. The guard lets isolated PostgreSQL
-- schema tests apply the migration while live Supabase configures the bucket.
do $$ begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('admission-consent','admission-consent',false,5242880,array['application/pdf','image/jpeg','image/png'])
    on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
    execute $policy$create policy admission_consent_upload on storage.objects
      for insert to authenticated with check (
        bucket_id='admission-consent' and public.has_permission('admissions.create')
        and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$'
        and exists(select 1 from public.admission_cases c where c.id::text=split_part(name,'/',1) and c.status in ('DRAFT','READY'))
      )$policy$;
    execute $policy$create policy admission_consent_download on storage.objects
      for select to authenticated using (bucket_id='admission-consent' and public.has_permission('admissions.view'))$policy$;
  end if;
end $$;



-- ============================================================
-- SOURCE: 0034_v2_homework_followup.sql
-- ============================================================

-- A submitted class log assigns homework; teachers record observed per-student
-- follow-up. Each correction appends a revision and preserves the earlier check.
create table public.homework_checks (
  id uuid primary key default gen_random_uuid(),
  class_log_id uuid not null references public.class_logs(id),
  enrollment_id uuid not null references public.enrollments(id),
  revision integer not null check(revision>0),
  status text not null check(status in ('NOT_SUBMITTED','NEEDS_WORK','COMPLETE')),
  submitted_on date,
  feedback text not null default '' check(length(feedback)<=1000),
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now(),
  unique(class_log_id,enrollment_id,revision)
);
create index homework_checks_history on public.homework_checks(class_log_id,enrollment_id,revision desc);
alter table public.homework_checks enable row level security;
revoke all on public.homework_checks from anon,authenticated;

create or replace function public.homework_workspace(p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare log_row public.class_logs; session_row public.class_sessions;
begin
  if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.'; end if;
  select * into session_row from public.class_sessions where id=p_session_id;
  select * into log_row from public.class_logs where session_id=p_session_id and status='SUBMITTED' and btrim(homework)<>'' order by revision desc limit 1;
  return jsonb_build_object(
    'assignment',case when log_row.id is null then null else jsonb_build_object('id',log_row.id,'revision',log_row.revision,'description',log_row.homework,'submittedAt',log_row.submitted_at) end,
    'students',coalesce((select jsonb_agg(jsonb_build_object(
      'enrollmentId',e.id,'studentNo',s.student_no,'name',s.full_name,
      'latestRevision',hc.revision,'status',hc.status,'submittedOn',hc.submitted_on,'feedback',hc.feedback
      ) order by s.student_no)
      from public.enrollments e join public.students s on s.id=e.student_id
      left join lateral (select * from public.homework_checks h where h.class_log_id=log_row.id and h.enrollment_id=e.id order by revision desc limit 1) hc on true
      where log_row.id is not null and e.batch_id=session_row.batch_id and e.admission_date<=session_row.session_date
      and (e.ended_on is null or e.ended_on>session_row.session_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'enrollmentId',h.enrollment_id,'revision',h.revision,'status',h.status,'submittedOn',h.submitted_on,'feedback',h.feedback,'recordedAt',h.recorded_at) order by h.recorded_at desc)
      from public.homework_checks h where h.class_log_id=log_row.id),'[]'::jsonb)
  );
end $$;

create or replace function public.homework_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid:=auth.uid(); rid uuid:=(p_input->>'request_id')::uuid;
  sid uuid:=(p_input->>'session_id')::uuid; log_id uuid:=(p_input->>'class_log_id')::uuid;
  v_enrollment_id uuid:=(p_input->>'enrollment_id')::uuid; cs public.class_sessions;
  log_row public.class_logs; previous integer; check_row public.homework_checks;
  key public.admission_command_keys; result jsonb; feedback_value text:=btrim(coalesce(p_input->>'feedback',''));
  submitted_on_value date;
begin
  if actor is null or not public.has_permission('academics.view') or not (public.has_permission('academics.attendance.record') or public.has_permission('academics.sessions.manage')) then raise exception 'Teaching permission required.'; end if;
  if rid is null or sid is null or log_id is null or v_enrollment_id is null then raise exception 'Homework request identity and scope are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
  select * into key from public.admission_command_keys where request_id=rid;
  if found then
    if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
    return key.result;
  end if;
  if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.'; end if;
  select * into cs from public.class_sessions where id=sid;
  if cs.status<>'SCHEDULED' or (not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff st where st.id=cs.teacher_id and st.profile_id=actor)) then raise exception 'Only the assigned teacher may check homework.'; end if;
  select * into log_row from public.class_logs where id=log_id and session_id=sid and status='SUBMITTED' and btrim(homework)<>'';
  if log_row.id is null then raise exception 'Submit the class log with homework before follow-up.'; end if;
  if not exists(select 1 from public.enrollments e where e.id=v_enrollment_id and e.batch_id=cs.batch_id
    and e.admission_date<=cs.session_date and (e.ended_on is null or e.ended_on>cs.session_date)
    and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')) then raise exception 'Student was not on this class roster.'; end if;
  if p_input->>'status' not in ('NOT_SUBMITTED','NEEDS_WORK','COMPLETE') or length(feedback_value)>1000
    or (p_input->>'status'='NEEDS_WORK' and length(feedback_value)<5) then raise exception 'Choose a status and explain work that needs attention.'; end if;
  submitted_on_value:=nullif(p_input->>'submitted_on','')::date;
  if submitted_on_value>current_date or (p_input->>'status'='NOT_SUBMITTED' and submitted_on_value is not null) then raise exception 'Check the homework submission date.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(log_id::text||v_enrollment_id::text,31));
  select coalesce(max(revision),0) into previous from public.homework_checks where class_log_id=log_id and enrollment_id=v_enrollment_id;
  if previous<>coalesce((p_input->>'base_revision')::integer,0) then raise exception 'Homework review changed. Refresh and try again.'; end if;
  insert into public.homework_checks(class_log_id,enrollment_id,revision,status,submitted_on,feedback,recorded_by)
  values(log_id,v_enrollment_id,previous+1,p_input->>'status',submitted_on_value,feedback_value,actor) returning * into check_row;
  result:=jsonb_build_object('id',check_row.id,'revision',check_row.revision);
  insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
  values(actor,'HOMEWORK_CHECK',check_row.id::text,'RECORD',to_jsonb(check_row));
  insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
  return result;
end $$;
revoke all on function public.homework_workspace(uuid),public.homework_command(jsonb) from public,anon;
grant execute on function public.homework_workspace(uuid),public.homework_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0035_v2_assessment_results.sql
-- ============================================================

-- Assessments are dated batch/subject events. Result submissions preserve
-- revisions; only a different authorized reviewer makes one official.
create table public.academic_assessments (
 id uuid primary key default gen_random_uuid(),
 batch_id uuid not null references public.batches(id),
 subject_id uuid not null references public.subjects(id),
 title text not null check(length(btrim(title)) between 3 and 180),
 assessment_date date not null,
 max_marks numeric(8,2) not null check(max_marks>0 and max_marks<=1000),
 status text not null default 'DRAFT' check(status in ('DRAFT','PUBLISHED','CANCELLED')),
 author_id uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 published_at timestamptz,
 check ((status='DRAFT')=(published_at is null) or status='CANCELLED')
);
create index academic_assessments_scope on public.academic_assessments(batch_id,subject_id,assessment_date desc);
create table public.assessment_result_submissions (
 id uuid primary key default gen_random_uuid(),
 assessment_id uuid not null references public.academic_assessments(id),
 revision integer not null check(revision>0),
 entries jsonb not null,
 status text not null default 'DRAFT' check(status in ('DRAFT','SUBMITTED','APPROVED','REJECTED')),
 author_id uuid not null references public.profiles(id),
 reviewer_id uuid references public.profiles(id),
 review_note text,
 created_at timestamptz not null default now(),
 submitted_at timestamptz,
 reviewed_at timestamptz,
 unique(assessment_id,revision),
 check ((status in ('APPROVED','REJECTED'))=(reviewer_id is not null))
);
create unique index assessment_one_draft on public.assessment_result_submissions(assessment_id) where status='DRAFT';
create unique index assessment_one_pending on public.assessment_result_submissions(assessment_id) where status='SUBMITTED';
alter table public.academic_assessments enable row level security;
alter table public.assessment_result_submissions enable row level security;
revoke all on public.academic_assessments,public.assessment_result_submissions from anon,authenticated;

create or replace function public.can_access_assessment(p_batch uuid,p_subject uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and public.has_permission('academics.view') and (
  public.has_permission('academics.assessments.approve') or public.has_permission('academics.sessions.manage')
  or exists(select 1 from public.class_sessions cs join public.staff st on st.id=cs.teacher_id
    where cs.batch_id=p_batch and cs.subject_id=p_subject and st.profile_id=auth.uid())
 );
$$;
revoke all on function public.can_access_assessment(uuid,uuid) from public,anon;
grant execute on function public.can_access_assessment(uuid,uuid) to authenticated;

create or replace function public.assessment_workspace()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 return jsonb_build_object(
  'scopes',coalesce((select jsonb_agg(jsonb_build_object('batchId',cs.batch_id,'subjectId',cs.subject_id,'batch',b.name,'subject',s.name) order by b.name,s.name)
    from (select distinct batch_id,subject_id from public.class_sessions) cs
    join public.batches b on b.id=cs.batch_id join public.subjects s on s.id=cs.subject_id
    where public.can_access_assessment(cs.batch_id,cs.subject_id)),'[]'::jsonb),
  'assessments',coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'batchId',a.batch_id,'subjectId',a.subject_id,'batch',b.name,'subject',s.name,
    'title',a.title,'date',a.assessment_date,'maxMarks',a.max_marks,'status',a.status,
    'authorId',a.author_id,'roster',coalesce((select jsonb_agg(jsonb_build_object('enrollmentId',e.id,'studentNo',st.student_no,'name',st.full_name) order by st.student_no)
      from public.enrollments e join public.students st on st.id=e.student_id
      where e.batch_id=a.batch_id and e.admission_date<=a.assessment_date
        and (e.ended_on is null or e.ended_on>a.assessment_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED')),'[]'::jsonb),
    'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'revision',r.revision,'status',r.status,'entries',r.entries,'authorId',r.author_id,'reviewNote',r.review_note,'createdAt',r.created_at) order by r.revision desc)
      from public.assessment_result_submissions r where r.assessment_id=a.id),'[]'::jsonb)
    ) order by a.assessment_date desc)
    from public.academic_assessments a join public.batches b on b.id=a.batch_id join public.subjects s on s.id=a.subject_id
    where public.can_access_assessment(a.batch_id,a.subject_id)),'[]'::jsonb)
 );
end $$;

create or replace function public.assessment_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare actor uuid:=auth.uid(); act text:=p_input->>'action'; rid uuid:=(p_input->>'request_id')::uuid;
  a public.academic_assessments; r public.assessment_result_submissions; key public.admission_command_keys;
  v_entries jsonb:=coalesce(p_input->'entries','[]'::jsonb); expected integer; result jsonb;
  v_batch uuid; v_subject uuid; v_date date; v_max numeric;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 if rid is null then raise exception 'Request identity required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
 select * into key from public.admission_command_keys where request_id=rid;
 if found then
   if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if;
   return key.result;
 end if;
 if act='CREATE' then
   if not public.has_permission('academics.assessments.record') then raise exception 'Assessment recording permission required.'; end if;
   v_batch:=(p_input->>'batch_id')::uuid; v_subject:=(p_input->>'subject_id')::uuid;
   if not public.can_access_assessment(v_batch,v_subject) then raise exception 'Assessment is outside your teaching scope.'; end if;
   if not exists(select 1 from public.class_sessions where batch_id=v_batch and subject_id=v_subject) then raise exception 'Schedule a class for this batch and subject first.'; end if;
   v_date:=(p_input->>'assessment_date')::date; v_max:=(p_input->>'max_marks')::numeric;
   if v_date is null or v_max is null or v_max<=0 or v_max>1000
     or length(btrim(coalesce(p_input->>'title',''))) not between 3 and 180 then raise exception 'Enter assessment title, date and valid maximum marks.'; end if;
   if not exists(select 1 from public.batches b join public.academic_years y on y.id=b.academic_year_id where b.id=v_batch and v_date between y.starts_on and y.ends_on) then raise exception 'Assessment date must be in the batch academic year.'; end if;
   insert into public.academic_assessments(batch_id,subject_id,title,assessment_date,max_marks,author_id)
   values(v_batch,v_subject,btrim(p_input->>'title'),v_date,v_max,actor) returning * into a;
 else
   select * into a from public.academic_assessments where id=(p_input->>'assessment_id')::uuid for update;
   if a.id is null or not public.can_access_assessment(a.batch_id,a.subject_id) then raise exception 'Assessment not found in your scope.'; end if;
   if act='PUBLISH' then
     if a.status<>'DRAFT' or not public.has_permission('academics.assessments.record') then raise exception 'Only a draft can be published.'; end if;
     if a.author_id<>actor and not public.has_permission('academics.sessions.manage') then raise exception 'Only the author may publish this assessment.'; end if;
     update public.academic_assessments set status='PUBLISHED',published_at=now() where id=a.id returning * into a;
   elsif act='SAVE_RESULTS' then
     if a.status<>'PUBLISHED' or not public.has_permission('academics.assessments.record') then raise exception 'Published assessment and recording permission required.'; end if;
     if jsonb_typeof(v_entries)<>'array' or jsonb_array_length(v_entries)>500 then raise exception 'Check result entries.'; end if;
     select count(*) into expected from public.enrollments e where e.batch_id=a.batch_id and e.admission_date<=a.assessment_date
       and (e.ended_on is null or e.ended_on>a.assessment_date) and e.status in ('ACTIVE','WITHDRAWN','COMPLETED');
     if expected=0 or expected<>jsonb_array_length(v_entries) then raise exception 'Record exactly one result for every eligible student.'; end if;
     if exists(select 1 from jsonb_array_elements(v_entries) e where
       not (e ? 'enrollment_id' and e ? 'score') or (e->>'score') !~ '^([0-9]+)(\.[0-9]{1,2})?$'
       or (e->>'score')::numeric>a.max_marks or length(coalesce(e->>'feedback',''))>500
       or not exists(select 1 from public.enrollments x where x.id=(e->>'enrollment_id')::uuid and x.batch_id=a.batch_id
         and x.admission_date<=a.assessment_date and (x.ended_on is null or x.ended_on>a.assessment_date)
         and x.status in ('ACTIVE','WITHDRAWN','COMPLETED')))
       or (select count(distinct e->>'enrollment_id') from jsonb_array_elements(v_entries) e)<>expected
       then raise exception 'Invalid or duplicate result entries.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null then
       if exists(select 1 from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED') then raise exception 'Results are awaiting independent review.'; end if;
       insert into public.assessment_result_submissions(assessment_id,revision,entries,author_id)
       values(a.id,(select coalesce(max(revision),0)+1 from public.assessment_result_submissions where assessment_id=a.id),v_entries,actor) returning * into r;
     else
       if r.author_id<>actor then raise exception 'Only the draft author can change these results.'; end if;
       update public.assessment_result_submissions set entries=v_entries where id=r.id returning * into r;
     end if;
   elsif act='SUBMIT_RESULTS' then
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='DRAFT' for update;
     if r.id is null or r.author_id<>actor then raise exception 'Save your result draft before submitting.'; end if;
     update public.assessment_result_submissions set status='SUBMITTED',submitted_at=now() where id=r.id returning * into r;
   elsif act in ('APPROVE_RESULTS','REJECT_RESULTS') then
     if not public.has_permission('academics.assessments.approve') then raise exception 'Assessment review permission required.'; end if;
     select * into r from public.assessment_result_submissions where assessment_id=a.id and status='SUBMITTED' for update;
     if r.id is null then raise exception 'No submitted result revision is awaiting review.'; end if;
     if r.author_id=actor then raise exception 'Result author cannot approve or reject their own submission.'; end if;
     if length(btrim(coalesce(p_input->>'review_note','')))<5 then raise exception 'Enter a review reason.'; end if;
     update public.assessment_result_submissions set status=case when act='APPROVE_RESULTS' then 'APPROVED' else 'REJECTED' end,
       reviewer_id=actor,review_note=btrim(p_input->>'review_note'),reviewed_at=now() where id=r.id returning * into r;
   else raise exception 'Unknown assessment action.'; end if;
 end if;
 result:=jsonb_build_object('id',a.id,'status',coalesce(r.status,a.status),'revision',r.revision);
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,after_data)
 values(actor,'ASSESSMENT',a.id::text,act,case when r.id is null then to_jsonb(a) else to_jsonb(r) end);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
 return result;
end $$;
revoke all on function public.assessment_workspace(),public.assessment_command(jsonb) from public,anon;
grant execute on function public.assessment_workspace(),public.assessment_command(jsonb) to authenticated;



-- ============================================================
-- SOURCE: 0036_v2_public_batch_availability.sql
-- ============================================================

-- Display only a current, non-reserving availability snapshot. Admission and
-- activation continue to recheck capacity under their own database locks.
do $migration$
declare
 definition text;
 old_fields text := $old$      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,$old$;
 new_fields text := $new$      o.public_requirements_bn, o.admission_policy, o.admission_policy_bn,
      (select count(*)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as active_batch_count,
      (select coalesce(sum(bb.capacity),0)::integer from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_total_seats,
      (select coalesce(sum(greatest(bb.capacity-(select count(*) from public.enrollments e where e.batch_id=bb.id and e.status='ACTIVE'),0)),0)::integer
       from public.batches bb where bb.offering_id=o.id and bb.is_active) as current_open_seats,$new$;
begin
 select pg_get_functiondef('public.list_public_programme_offerings()'::regprocedure) into definition;
 if position(old_fields in definition)=0 then raise exception 'Could not extend public catalogue availability; inspect RPC definition.'; end if;
 execute replace(definition,old_fields,new_fields);
end;
$migration$;



-- ============================================================
-- SOURCE: 0037_v2_admission_requirement_review.sql
-- ============================================================

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



-- ============================================================
-- SOURCE: 0038_v2_link_staff_profiles.sql
-- ============================================================

-- Link Staff identities to Auth profiles.
--
-- create_staff_member() never set staff.profile_id, so a Staff record (e.g. a
-- Teacher) stayed unlinked even when that person signed in. my_erp_context()
-- then returned no staff identity and assigned sessions never appeared.
--
-- Linking rule (conservative):
--   * the Auth user's email is confirmed and equals the Staff email (case-insensitive)
--   * the Auth user has a profile and is not already linked to another Staff record
--   * exactly one ACTIVE / ON_LEAVE unlinked Staff record uses that email

create or replace function public.link_staff_profile_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(nullif(btrim(coalesce(p_email, '')), ''));
  v_user_id uuid;
  v_staff_ids uuid[];
begin
  if v_email is null then
    return null;
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_email
    and u.email_confirmed_at is not null
  order by u.created_at asc
  limit 1;

  if v_user_id is null
     or not exists (select 1 from public.profiles where id = v_user_id)
     or exists (select 1 from public.staff where profile_id = v_user_id) then
    return null;
  end if;

  select array_agg(s.id) into v_staff_ids
  from public.staff s
  where s.profile_id is null
    and lower(s.email) = v_email
    and s.status in ('ACTIVE', 'ON_LEAVE');

  if coalesce(array_length(v_staff_ids, 1), 0) <> 1 then
    return null;
  end if;

  update public.staff
  set profile_id = v_user_id
  where id = v_staff_ids[1]
    and profile_id is null;

  insert into public.audit_events(entity_type, entity_id, action, reason, metadata)
  values (
    'STAFF',
    v_staff_ids[1]::text,
    'LINK_PROFILE',
    'Linked to Auth profile by confirmed email match.',
    jsonb_build_object('profile_id', v_user_id, 'email', v_email)
  );

  return v_staff_ids[1];
end;
$$;

revoke all on function public.link_staff_profile_by_email(text) from public, anon, authenticated;

-- Staff created or edited after the person already has a login.
create or replace function public.staff_link_profile_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.link_staff_profile_by_email(new.email);
  return null;
end;
$$;

drop trigger if exists staff_link_profile on public.staff;
create trigger staff_link_profile
after insert or update of email, status on public.staff
for each row
when (new.profile_id is null and new.email is not null)
execute function public.staff_link_profile_trigger();

-- Person signs up / confirms their email after the Staff record exists.
-- Named so it fires after on_auth_user_created (which creates the profile).
create or replace function public.auth_user_link_staff_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null then
    perform public.link_staff_profile_by_email(new.email);
  end if;
  return null;
end;
$$;

drop trigger if exists on_auth_user_link_staff on auth.users;
create trigger on_auth_user_link_staff
after insert or update of email, email_confirmed_at on auth.users
for each row
execute function public.auth_user_link_staff_trigger();

-- Backfill existing unlinked Staff records.
do $backfill$
declare
  v_email text;
begin
  for v_email in
    select distinct lower(email)
    from public.staff
    where profile_id is null
      and email is not null
      and status in ('ACTIVE', 'ON_LEAVE')
  loop
    perform public.link_staff_profile_by_email(v_email);
  end loop;
end;
$backfill$;



-- ============================================================
-- SOURCE: 0039_v2_applicant_corrections.sql
-- ============================================================

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



-- ============================================================
-- SOURCE: 0040_v2_admission_consent_acceptance_gate.sql
-- ============================================================

-- Phase 1: require a recorded signed-consent receipt before accepting new cases.
-- Existing cases are grandfathered so this cutover does not block historical work.

alter table public.admission_cases
  add column if not exists consent_required boolean;

update public.admission_cases
set consent_required = false
where consent_required is null;

alter table public.admission_cases
  alter column consent_required set default true,
  alter column consent_required set not null;

create index if not exists admission_cases_consent_gate_idx
  on public.admission_cases(consent_required, status);

-- Replace the current admission command definition while preserving all existing
-- workflow behavior. The gate is deliberately in the transactional ACCEPT branch
-- so direct callers cannot bypass the policy.

do $migration$
declare
  definition text;
  fee_check text := 'if v_fee.status<>''ACTIVE'' then raise exception ''Fee Plan changed. Refresh and review before acceptance.''; end if;';
  consent_gate text := $gate$
      if v_case.consent_required and not exists (
        select 1 from public.admission_consent_documents d
        where d.admission_id = v_case.id
      ) then
        raise exception 'A recorded signed consent receipt is required before acceptance.';
      end if;$gate$;
begin
  select pg_get_functiondef('public.admission_command(jsonb)'::regprocedure)
    into definition;

  -- Already installed
  if position('A recorded signed consent receipt is required before acceptance.' in definition) > 0 then
    return;
  end if;

  -- Must still contain the fee-plan guard we anchor on
  if position(fee_check in definition) = 0 then
    raise exception 'Could not install admission consent acceptance gate; inspect admission_command before migrating. Fee-plan guard not found.';
  end if;

  -- Inject the consent gate immediately after the fee-plan guard
  definition := replace(
    definition,
    fee_check,
    fee_check || E'\n' || consent_gate
  );

  execute definition;
end;
$migration$;



-- ============================================================
-- SOURCE: 0041_v2_offering_public_content_versions.sql
-- ============================================================

-- Phase 2: versioned, reviewed public offering content.
-- Existing programme_offerings columns remain the current live contract until a
-- published version is selected. Each version is immutable after publication.

create table public.programme_offering_public_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.programme_offerings(id) on delete cascade,
  version integer not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'PENDING_REVIEW', 'PUBLISHED', 'RETIRED')),
  content jsonb not null check (jsonb_typeof(content) = 'object'),
  change_reason text not null check (length(btrim(change_reason)) between 5 and 500),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  submitted_by uuid references public.profiles(id),
  submitted_at timestamptz,
  published_by uuid references public.profiles(id),
  published_at timestamptz,
  unique (offering_id, version)
);

create unique index programme_offering_public_one_published
  on public.programme_offering_public_versions(offering_id)
  where status = 'PUBLISHED';
create index programme_offering_public_versions_history_idx
  on public.programme_offering_public_versions(offering_id, version desc);

alter table public.programme_offering_public_versions enable row level security;
grant select on public.programme_offering_public_versions to authenticated;
revoke insert, update, delete on public.programme_offering_public_versions from anon, authenticated;
create policy programme_offering_public_versions_staff_read
on public.programme_offering_public_versions for select to authenticated
using (public.has_permission('academics.view'));

create or replace function public.create_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  offering uuid := nullif(p_input->>'offering_id', '')::uuid;
  reason text := btrim(coalesce(p_input->>'reason', ''));
  content jsonb := p_input->'content';
  next_version integer;
  created programme_offering_public_versions;
begin
  if actor is null or not public.has_permission('academics.manage') then
    raise exception 'Offering management permission required.';
  end if;
  if offering is null or length(reason) not between 5 and 500 or jsonb_typeof(content) <> 'object' then
    raise exception 'Offering, reason and public content are required.';
  end if;
  if not exists (select 1 from public.programme_offerings where id = offering) then
    raise exception 'Programme offering not found.';
  end if;
  select coalesce(max(version), 0) + 1 into next_version
  from public.programme_offering_public_versions
  where offering_id = offering;
  insert into public.programme_offering_public_versions(offering_id, version, content, change_reason, created_by)
  values (offering, next_version, content, reason, actor)
  returning * into created;
  return jsonb_build_object('id', created.id, 'version', created.version, 'status', created.status);
end;
$$;

create or replace function public.submit_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare actor uuid := auth.uid(); v programme_offering_public_versions;
begin
  if actor is null or not public.has_permission('academics.manage') then raise exception 'Offering management permission required.'; end if;
  select * into v from public.programme_offering_public_versions
  where id = (p_input->>'version_id')::uuid for update;
  if not found or v.status <> 'DRAFT' then raise exception 'Only a draft version can be submitted.'; end if;
  update public.programme_offering_public_versions
  set status = 'PENDING_REVIEW', submitted_by = actor, submitted_at = now()
  where id = v.id;
  return jsonb_build_object('id', v.id, 'version', v.version, 'status', 'PENDING_REVIEW');
end;
$$;

create or replace function public.publish_programme_offering_public_version(p_input jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare actor uuid := auth.uid(); v programme_offering_public_versions; old_id uuid;
begin
  if actor is null or not public.has_permission('academics.manage') then raise exception 'Offering management permission required.'; end if;
  select * into v from public.programme_offering_public_versions
  where id = (p_input->>'version_id')::uuid for update;
  if not found or v.status <> 'PENDING_REVIEW' then raise exception 'Only a submitted version can be published.'; end if;
  if v.submitted_by = actor then raise exception 'The author cannot publish their own public content.'; end if;
  select id into old_id from public.programme_offering_public_versions
  where offering_id = v.offering_id and status = 'PUBLISHED' for update;
  update public.programme_offering_public_versions set status = 'RETIRED' where id = old_id;
  update public.programme_offering_public_versions
  set status = 'PUBLISHED', published_by = actor, published_at = now()
  where id = v.id;
  update public.programme_offerings set
    showcase_title = v.content->>'showcase_title', showcase_title_bn = v.content->>'showcase_title_bn',
    showcase_description = v.content->>'showcase_description', showcase_description_bn = v.content->>'showcase_description_bn',
    showcase_eyebrow = v.content->>'showcase_eyebrow', showcase_eyebrow_bn = v.content->>'showcase_eyebrow_bn',
    public_schedule = v.content->>'public_schedule', public_schedule_bn = v.content->>'public_schedule_bn',
    public_requirements = v.content->>'public_requirements', public_requirements_bn = v.content->>'public_requirements_bn',
    admission_policy = v.content->>'admission_policy', admission_policy_bn = v.content->>'admission_policy_bn',
    updated_at = now()
  where id = v.offering_id;
  return jsonb_build_object('id', v.id, 'version', v.version, 'status', 'PUBLISHED');
end;
$$;

revoke all on function public.create_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.create_programme_offering_public_version(jsonb) to authenticated;
revoke all on function public.submit_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.submit_programme_offering_public_version(jsonb) to authenticated;
revoke all on function public.publish_programme_offering_public_version(jsonb) from public, anon;
grant execute on function public.publish_programme_offering_public_version(jsonb) to authenticated;

