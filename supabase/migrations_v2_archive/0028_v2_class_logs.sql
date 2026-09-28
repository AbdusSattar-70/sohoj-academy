-- Actual taught content and homework are immutable, session-linked evidence.
create table public.class_logs (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.class_sessions(id),
 revision integer not null check(revision>0),
 previous_log_id uuid references public.class_logs(id),
 status text not null check(status in ('DRAFT','SUBMITTED')),
 unit_progress jsonb not null default '[]'::jsonb,
 class_summary text not null,
 unfinished_reason text not null default '',
 homework text not null default '',
 next_session_plan text not null default '',
 reason text not null,
 authored_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 submitted_at timestamptz,
 unique(session_id,revision),
 check((status='DRAFT' and submitted_at is null) or (status='SUBMITTED' and submitted_at is not null))
);
create unique index one_class_log_draft_per_session on public.class_logs(session_id) where status='DRAFT';
create index class_logs_session_history on public.class_logs(session_id,revision desc);
alter table public.class_logs enable row level security;
revoke all on public.class_logs from anon,authenticated;

create function public.guard_submitted_class_log() returns trigger language plpgsql as $$
begin
 if tg_op='DELETE' then raise exception 'Class-log history cannot be deleted.'; end if;
 if old.status='SUBMITTED' then raise exception 'Submitted class-log evidence is immutable.'; end if;
 if new.status='SUBMITTED' and (to_jsonb(new)-'status'-'submitted_at') is distinct from (to_jsonb(old)-'status'-'submitted_at') then raise exception 'Submit the saved draft without changing its contents.'; end if;
 return new;
end $$;
create trigger class_log_history_guard before update or delete on public.class_logs for each row execute function public.guard_submitted_class_log();

create function public.class_log_workspace(p_session_id uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.can_access_class_session(p_session_id) then raise exception 'This class is outside your assigned scope.'; end if;
 select jsonb_build_object(
  'logs',coalesce((select jsonb_agg(to_jsonb(l) order by revision desc) from public.class_logs l where l.session_id=p_session_id),'[]'::jsonb),
  'units',coalesce((select cv.units from public.class_sessions cs join public.curriculum_versions cv on cv.id=cs.curriculum_version_id where cs.id=p_session_id),'[]'::jsonb)
 ) into result;
 return result;
end $$;

create function public.class_log_command(p_input jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
 actor uuid:=auth.uid(); rid uuid:=nullif(p_input->>'request_id','')::uuid; sid uuid:=nullif(p_input->>'session_id','')::uuid;
 act text:=p_input->>'action'; why text:=trim(coalesce(p_input->>'reason','')); key public.admission_command_keys;
 cs public.class_sessions; latest public.class_logs; draft public.class_logs; progress jsonb:=coalesce(p_input->'unit_progress','[]'::jsonb); unit_count integer;
 summary text:=trim(coalesce(p_input->>'class_summary','')); unfinished text:=trim(coalesce(p_input->>'unfinished_reason',''));
 homework_value text:=trim(coalesce(p_input->>'homework','')); next_value text:=trim(coalesce(p_input->>'next_session_plan',''));
 result jsonb; new_revision integer; branch uuid;
begin
 if actor is null or not public.has_permission('academics.view') then raise exception 'Academic access required.'; end if;
 if rid is null or sid is null or length(why)<5 or length(why)>500 then raise exception 'Session, request identity and reason (5–500 characters) are required.'; end if;
 if act not in ('SAVE_DRAFT','SUBMIT') then raise exception 'Unsupported class-log action.'; end if;
 if not (public.has_permission('academics.attendance.record') or public.has_permission('academics.sessions.manage')) then raise exception 'Attendance recording permission required.'; end if;
 if not public.can_access_class_session(sid) then raise exception 'This class is outside your assigned scope.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(rid::text,0));
 select * into key from public.admission_command_keys where request_id=rid;
 if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity already used for different input.'; end if; return key.result; end if;
 perform pg_advisory_xact_lock(hashtextextended(sid::text,21));
 select * into cs from public.class_sessions where id=sid for update;
 select branch_id into branch from public.batches where id=cs.batch_id;
 if cs.status<>'SCHEDULED' then raise exception 'A cancelled class cannot receive a class log.'; end if;
 if cs.starts_at>now() then raise exception 'Class log opens after the scheduled class starts.'; end if;
 if not public.has_permission('academics.sessions.manage') and not exists(select 1 from public.staff st where st.profile_id=actor and st.id=cs.teacher_id) then raise exception 'Only the assigned teacher may record this class.'; end if;
 select * into latest from public.class_logs where session_id=sid order by revision desc limit 1;
 select * into draft from public.class_logs where session_id=sid and status='DRAFT' for update;
 if act='SAVE_DRAFT' then
  if jsonb_typeof(progress)<>'array' or jsonb_array_length(progress)>200 then raise exception 'Check curriculum progress entries.'; end if;
  select coalesce(jsonb_array_length(cv.units),0) into unit_count from public.class_sessions x left join public.curriculum_versions cv on cv.id=x.curriculum_version_id where x.id=sid;
  if jsonb_array_length(progress)>unit_count then raise exception 'Progress must refer only to the curriculum pinned to this class.'; end if;
  if exists(select 1 from jsonb_array_elements(progress) e where (e->>'unit_index')::integer<0 or (e->>'unit_index')::integer>=unit_count or e->>'status' not in ('COVERED','PARTIAL','NOT_COVERED') or length(coalesce(e->>'note',''))>500) then raise exception 'Invalid curriculum progress entry.'; end if;
  if summary='' or length(summary)>4000 or length(unfinished)>2000 or length(homework_value)>2000 or length(next_value)>2000 then raise exception 'Class summary is required; keep each field within its limit.'; end if;
  if exists(select 1 from jsonb_array_elements(progress) e where e->>'status' in ('PARTIAL','NOT_COVERED')) and unfinished='' then raise exception 'Explain any planned curriculum left incomplete.'; end if;
  if draft.id is not null and draft.authored_by<>actor then raise exception 'Another staff member owns the current draft.'; end if;
  if draft.id is null then
   select coalesce(max(revision),0)+1 into new_revision from public.class_logs where session_id=sid;
   insert into public.class_logs(session_id,revision,previous_log_id,status,unit_progress,class_summary,unfinished_reason,homework,next_session_plan,reason,authored_by)
   values(sid,new_revision,latest.id,'DRAFT',progress,summary,unfinished,homework_value,next_value,why,actor) returning * into draft;
  else
   update public.class_logs set unit_progress=progress,class_summary=summary,unfinished_reason=unfinished,homework=homework_value,next_session_plan=next_value,reason=why where id=draft.id returning * into draft;
  end if;
  result:=jsonb_build_object('id',draft.id,'revision',draft.revision,'status',draft.status,'message','Class-log draft saved.');
 else
  if draft.id is null or draft.authored_by<>actor then raise exception 'Save your class-log draft before submitting it.'; end if;
  update public.class_logs set status='SUBMITTED',submitted_at=now() where id=draft.id returning * into draft;
  result:=jsonb_build_object('id',draft.id,'revision',draft.revision,'status',draft.status,'message','Class log submitted. Curriculum completion remains a teacher report, separate from attendance approval.');
 end if;
 insert into public.audit_events(actor_profile_id,branch_id,entity_type,entity_id,action,reason,before_data,after_data,metadata)
 values(actor,branch,'CLASS_LOG',draft.id::text,act,why,null,to_jsonb(draft),jsonb_build_object('session_id',sid,'revision',draft.revision));
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(rid,actor,p_input,result);
 return result;
end $$;
revoke all on function public.class_log_workspace(uuid),public.class_log_command(jsonb) from public,anon;
grant execute on function public.class_log_workspace(uuid),public.class_log_command(jsonb) to authenticated;
