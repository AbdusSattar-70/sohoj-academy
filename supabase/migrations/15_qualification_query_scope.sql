-- Generated from supabase/schema/academics/15_qualification_query_scope.sql; edit the source, then run pnpm db:baseline.
-- Keep previously published migrations stable; qualify the subject lookup explicitly.
create or replace function public.save_academic_resource(p_request_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage'); cmd text:=p_payload->>'action';
 prior jsonb; result jsonb; before_value jsonb; identity uuid; teacher uuid; subject uuid;
 original public.teacher_subject_qualifications; block public.academic_resource_blocks;
 active boolean:=coalesce((p_payload->>'active')::boolean,false); kind text; resource uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended(aid::text||'academic-sessions',0));
 perform public.check_change_reason(p_payload->>'reason');
 prior:=public.lookup_operation(p_request_id,'ACADEMIC_RESOURCE_'||cmd,p_payload);
 if prior is not null then return prior; end if;
 if cmd='QUALIFICATION' then
  teacher:=(p_payload->>'teacherId')::uuid; subject:=(p_payload->>'subjectId')::uuid;
  if not exists(select 1 from public.people p join public.person_responsibilities r on r.person_id=p.id and r.responsibility='TEACHER' and r.is_active where p.id=teacher and p.academy_id=aid and p.is_active)
   or not exists(select 1 from public.directory_entries d where d.id=subject and d.academy_id=aid and d.kind='SUBJECT' and d.is_active)
  then raise exception 'Select an active academy teacher and subject.'; end if;
  select * into original from public.teacher_subject_qualifications where teacher_id=teacher and subject_id=subject for update;
  if coalesce(original.revision,0) is distinct from (p_payload->>'revision')::integer then raise exception 'Qualification changed. Reload before saving.'; end if;
  if not active and exists(select 1 from public.academic_sessions where academy_id=aid and teacher_id=teacher and subject_id=subject and starts_at>now() and status<>'CANCELLED')
  then raise exception 'Reassign or cancel future classes before removing this subject qualification.'; end if;
  before_value:=to_jsonb(original);
  insert into public.teacher_subject_qualifications(academy_id,teacher_id,subject_id,is_active)
   values(aid,teacher,subject,active) on conflict(teacher_id,subject_id) do update
   set is_active=excluded.is_active,revision=teacher_subject_qualifications.revision+1 returning to_jsonb(teacher_subject_qualifications.*) into result;
  identity:=teacher;
 elsif cmd='BLOCK' then
  identity:=nullif(p_payload->>'id','')::uuid; kind:=p_payload->>'kind'; resource:=(p_payload->>'resourceId')::uuid;
  if kind not in('TEACHER','ROOM') or resource is null then raise exception 'Select the resource type and resource.'; end if;
  if(kind='ROOM' and not exists(select 1 from public.academic_rooms where id=resource and academy_id=aid))
    or(kind='TEACHER' and not exists(select 1 from public.people p join public.person_responsibilities r on r.person_id=p.id and r.responsibility='TEACHER' where p.id=resource and p.academy_id=aid))
  then raise exception 'Choose an academy classroom or teacher.'; end if;
  if identity is not null then
   select * into block from public.academic_resource_blocks where id=identity and academy_id=aid for update;
   if not found or block.revision is distinct from (p_payload->>'revision')::int then raise exception 'Unavailable period changed. Reload before saving.'; end if;
   before_value:=to_jsonb(block);
  end if;
  if active and exists(select 1 from public.academic_sessions where academy_id=aid and status<>'CANCELLED'
   and starts_at<(p_payload->>'end')::timestamptz and ends_at>(p_payload->>'start')::timestamptz
   and ((kind='ROOM' and room_id=resource) or(kind='TEACHER' and teacher_id=resource)))
  then raise exception 'Reschedule or cancel overlapping classes before blocking this resource.'; end if;
  identity:=coalesce(identity,gen_random_uuid());
  insert into public.academic_resource_blocks(id,academy_id,resource_kind,resource_id,starts_at,ends_at,reason,is_active)
  values(identity,aid,kind,resource,(p_payload->>'start')::timestamptz,(p_payload->>'end')::timestamptz,p_payload->>'reason',active)
  on conflict(id) do update set resource_kind=excluded.resource_kind,resource_id=excluded.resource_id,starts_at=excluded.starts_at,
  ends_at=excluded.ends_at,reason=excluded.reason,is_active=excluded.is_active,revision=academic_resource_blocks.revision+1
  returning to_jsonb(academic_resource_blocks.*) into result;
 else raise exception 'Unknown resource action.'; end if;
 return public.finish_operation(p_request_id,'ACADEMIC_RESOURCE_'||cmd,p_payload,result,'ACADEMIC_RESOURCE',identity,before_value);
end $$;
