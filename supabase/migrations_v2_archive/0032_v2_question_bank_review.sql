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
