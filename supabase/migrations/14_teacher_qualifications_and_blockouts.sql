-- Generated from supabase/schema/academics/14_teacher_qualifications_and_blockouts.sql; edit the source, then run pnpm db:baseline.
-- Subject qualification and date-specific resource availability.
create table public.teacher_subject_qualifications (
 academy_id uuid not null references public.academies,
 teacher_id uuid not null, subject_id uuid not null,
 is_active boolean not null default true, revision integer not null default 1,
 primary key(teacher_id,subject_id),
 foreign key(teacher_id,academy_id) references public.people(id,academy_id),
 foreign key(subject_id,academy_id) references public.directory_entries(id,academy_id)
);
create table public.academic_resource_blocks (
 id uuid primary key default gen_random_uuid(), academy_id uuid not null references public.academies,
 resource_kind text not null check(resource_kind in('TEACHER','ROOM')), resource_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null,
 reason text not null check(length(btrim(reason)) between 5 and 1000),
 is_active boolean not null default true, revision integer not null default 1,
 check(ends_at>starts_at), unique(id,academy_id)
);
create index academic_resource_block_lookup on public.academic_resource_blocks(academy_id,resource_kind,resource_id,starts_at) where is_active;

create function public.guard_session_teacher_and_blocks() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='CANCELLED' then return new; end if;
 if tg_op='UPDATE' and new.teacher_id=old.teacher_id and new.subject_id=old.subject_id
  and new.room_id=old.room_id and new.starts_at=old.starts_at and new.ends_at=old.ends_at
  and old.status<>'CANCELLED' then return new; end if;
 if not exists(select 1 from public.teacher_subject_qualifications q
   join public.people p on p.id=q.teacher_id and p.is_active
   join public.person_responsibilities pr on pr.person_id=p.id and pr.responsibility='TEACHER' and pr.is_active
   join public.directory_entries d on d.id=q.subject_id and d.kind='SUBJECT' and d.is_active
   where q.academy_id=new.academy_id and q.teacher_id=new.teacher_id and q.subject_id=new.subject_id and q.is_active)
 then raise exception 'Assign an active teacher qualified for this subject. Open Teacher qualifications to verify the assignment.'; end if;
 if exists(select 1 from public.academic_resource_blocks b where b.academy_id=new.academy_id and b.is_active
  and b.starts_at<new.ends_at and b.ends_at>new.starts_at
  and ((b.resource_kind='TEACHER' and b.resource_id=new.teacher_id) or (b.resource_kind='ROOM' and b.resource_id=new.room_id)))
 then raise exception 'Teacher or classroom is unavailable for these dates. Choose another resource or time.'; end if;
 return new;
end $$;
create trigger qualified_available_resource before insert or update on public.academic_sessions
for each row execute function public.guard_session_teacher_and_blocks();

create function public.save_academic_resource(p_request_id uuid,p_payload jsonb) returns jsonb
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
   or not exists(select 1 from public.directory_entries where id=subject and academy_id=aid and kind='SUBJECT' and is_active)
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

create function public.academic_resource_register(p_page integer default 1) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare aid uuid:=public.require_operation('academics.manage');
begin
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Choose a valid page.'; end if;
 return jsonb_build_object(
 'qualifications',coalesce((select jsonb_agg(to_jsonb(q)) from public.teacher_subject_qualifications q where academy_id=aid),'[]'::jsonb),
 'blocks',coalesce((select jsonb_agg(to_jsonb(x)) from(select * from public.academic_resource_blocks where academy_id=aid order by starts_at desc,id limit 25 offset (p_page-1)*25)x),'[]'::jsonb),
 'blockTotal',(select count(*) from public.academic_resource_blocks where academy_id=aid));
end $$;

alter table public.teacher_subject_qualifications enable row level security;
alter table public.academic_resource_blocks enable row level security;
revoke all on public.teacher_subject_qualifications,public.academic_resource_blocks from anon,authenticated;
create trigger no_delete before delete on public.teacher_subject_qualifications for each row execute function public.reject_record_delete();
create trigger no_delete before delete on public.academic_resource_blocks for each row execute function public.reject_record_delete();
revoke all on function public.guard_session_teacher_and_blocks(),public.save_academic_resource(uuid,jsonb),public.academic_resource_register(integer) from public,anon,authenticated;
grant execute on function public.save_academic_resource(uuid,jsonb),public.academic_resource_register(integer) to authenticated;
