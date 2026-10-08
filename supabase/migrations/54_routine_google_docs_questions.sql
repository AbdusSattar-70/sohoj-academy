-- Retire question-generator writes, retain its historical records.
revoke execute on function public.question_bank_command(jsonb) from public,anon,authenticated;
create table public.class_question_documents(
 id uuid primary key default gen_random_uuid(),session_id uuid not null references public.class_sessions(id),author_id uuid not null references public.profiles(id),
 topic text not null check(length(topic) between 2 and 300),page_reference text not null default '' check(length(page_reference)<=100),draft_url text not null,
 source_id uuid references public.class_question_documents(id),status text not null default 'DRAFT' check(status in('DRAFT','SUBMITTED','RETURNED','FINAL')),
 final_question_url text,final_answer_url text,review_note text,reviewer_id uuid references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),finalized_at timestamptz);
alter table public.class_question_documents enable row level security;
revoke all on public.class_question_documents from public,anon,authenticated;
create trigger question_document_no_delete before delete on public.class_question_documents for each row execute function public.prevent_permanent_record_delete();
create function public.valid_google_document_url(p_url text) returns boolean language sql immutable set search_path='' as $$select coalesce(p_url ~ '^https://docs\.google\.com/document/d/[A-Za-z0-9_-]+(/(edit|view|preview|copy))?([?#][^[:space:]]*)?$',false) and length(p_url)<=2000$$;
revoke all on function public.valid_google_document_url(text) from public,anon,authenticated;
create function public.class_question_document_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=nullif(p_input->>'request_id','')::uuid;act text:=p_input->>'action';sid uuid;row public.class_question_documents;old jsonb;key public.admission_command_keys;result jsonb;source public.class_question_documents;note text:=btrim(coalesce(p_input->>'review_note',''));begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not public.has_permission('academics.view') then raise exception 'Active academic access required.';end if;
 if req is null then raise exception 'Request identity required.';end if;
 perform pg_advisory_xact_lock(hashtextextended('sohoj-academic-operations',20));perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity reused with different input.';end if;return key.result;end if;
 if nullif(p_input->>'id','') is not null then select * into row from public.class_question_documents where id=(p_input->>'id')::uuid for update;if row.id is null or not public.can_access_class_session(row.session_id) then raise exception 'Question submission not accessible.';end if;sid:=row.session_id;old:=to_jsonb(row);else sid:=nullif(p_input->>'session_id','')::uuid;end if;
 if act<>'SAVE' and row.id is null then raise exception 'Select an existing record first.';end if;
 if act='SAVE' then
  if not exists(select 1 from public.class_sessions s join public.staff t on t.id=s.teacher_id where s.id=sid and s.status='SCHEDULED' and t.profile_id=actor and t.status='ACTIVE') then raise exception 'Prepare questions only for your own scheduled class.';end if;
  if row.id is not null and(row.author_id<>actor or row.status not in('DRAFT','RETURNED')) then raise exception 'Edit only your Draft or Returned submission.';end if;
  if length(btrim(coalesce(p_input->>'topic',''))) not between 2 and 300 or length(coalesce(p_input->>'page_reference',''))>100 or not public.valid_google_document_url(p_input->>'draft_url') then raise exception 'Select/write a topic and provide a valid Google Docs document link.';end if;
  if nullif(p_input->>'source_id','') is not null then
   select * into source from public.class_question_documents where id=(p_input->>'source_id')::uuid and status='FINAL';
   if source.id is null or not public.can_access_class_session(source.session_id) or not exists(select 1 from public.class_sessions a join public.class_sessions b on b.subject_id=a.subject_id where a.id=sid and b.id=source.session_id) then raise exception 'Choose an accessible finalized set for the same subject.';end if;
  end if;
  if row.id is null then insert into public.class_question_documents(session_id,author_id,topic,page_reference,draft_url,source_id) values(sid,actor,btrim(p_input->>'topic'),btrim(coalesce(p_input->>'page_reference','')),p_input->>'draft_url',source.id) returning * into row;
  else update public.class_question_documents set topic=btrim(p_input->>'topic'),page_reference=btrim(coalesce(p_input->>'page_reference','')),draft_url=p_input->>'draft_url',source_id=source.id,status='DRAFT',updated_at=now() where id=row.id returning * into row;end if;
 elsif act='SUBMIT' then
  if row.author_id is distinct from actor or row.status<>'DRAFT' then raise exception 'Save your draft before submitting.';end if;
  update public.class_question_documents set status='SUBMITTED',updated_at=now() where id=row.id returning * into row;
 elsif act in('RETURN','FINALIZE') then
  if not public.has_permission('academics.assessments.approve') or row.author_id=actor or row.status<>'SUBMITTED' then raise exception 'Independent administrator review of a submitted document required.';end if;
  if length(note) not between 5 and 1000 then raise exception 'A review note of 5–1000 characters is required.';end if;
  if act='FINALIZE' and(not public.valid_google_document_url(p_input->>'final_question_url') or not public.valid_google_document_url(p_input->>'final_answer_url') or p_input->>'final_question_url'=p_input->>'final_answer_url' or coalesce((p_input->>'academy_copy_confirmed')::boolean,false) is not true) then raise exception 'Confirm academy-owned copies and separate valid question and answer-key links.';end if;
  update public.class_question_documents set status=case when act='FINALIZE' then 'FINAL' else 'RETURNED' end,review_note=note,reviewer_id=actor,final_question_url=case when act='FINALIZE' then p_input->>'final_question_url' end,final_answer_url=case when act='FINALIZE' then p_input->>'final_answer_url' end,finalized_at=case when act='FINALIZE' then now() end,updated_at=now() where id=row.id returning * into row;
 else raise exception 'Unsupported document action.';end if;
 result:=jsonb_build_object('id',row.id,'message','Saved successfully.');
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'CLASS_QUESTION_DOCUMENT',row.id::text,act,coalesce(nullif(note,''),'Teacher prepared questions from scheduled class'),old,to_jsonb(row),req);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
create function public.class_question_documents_workspace(p_page int default 1,p_status text default 'ALL',p_session_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') or not public.has_permission('academics.view') then raise exception 'Academic access required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_status not in('ALL','DRAFT','SUBMITTED','RETURNED','FINAL') then raise exception 'Choose valid filter/page.';end if;
 with visible as(select d.*,b.name batch,su.name subject,s.session_date,t.full_name teacher,t.staff_no from public.class_question_documents d join public.class_sessions s on s.id=d.session_id join public.batches b on b.id=s.batch_id join public.subjects su on su.id=s.subject_id join public.staff t on t.id=s.teacher_id where public.can_access_class_session(s.id) and(p_status='ALL' or d.status=p_status) and(p_session_id is null or s.id=p_session_id)),paged as(select * from visible order by updated_at desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('page',p_page,'total',(select count(*) from visible),'canReview',public.has_permission('academics.assessments.approve'),'rows',coalesce((select jsonb_agg(to_jsonb(p) order by updated_at desc,id) from paged p),'[]'),
 'sessions',coalesce((select jsonb_agg(to_jsonb(x)) from(select s.id,b.name||' · '||su.name||' · '||s.session_date label,coalesce(cv.units,'[]') topics from public.class_sessions s join public.staff t on t.id=s.teacher_id join public.batches b on b.id=s.batch_id join public.subjects su on su.id=s.subject_id left join public.curriculum_versions cv on cv.id=s.curriculum_version_id where t.profile_id=auth.uid() and t.status='ACTIVE' and s.status='SCHEDULED' and(s.id=p_session_id or s.session_date between (now() at time zone 'Asia/Dhaka')::date-30 and(now() at time zone 'Asia/Dhaka')::date+93) order by s.id=p_session_id desc,s.session_date limit 100)x),'[]')) into result;return result;
end $$;
revoke all on function public.class_question_document_command(jsonb),public.class_question_documents_workspace(int,text,uuid) from public,anon;
grant execute on function public.class_question_document_command(jsonb),public.class_question_documents_workspace(int,text,uuid) to authenticated;
notify pgrst,'reload schema';

create function public.protect_final_academic_document() returns trigger language plpgsql set search_path='' as $$begin if old.status='FINAL' then raise exception 'Final academic record cannot be changed. Create a new submission/report.';end if;return new;end $$;
revoke all on function public.protect_final_academic_document() from public,anon,authenticated;
create trigger finalized_question_immutable before update on public.class_question_documents for each row execute function public.protect_final_academic_document();
