-- Keep curriculum setup separate from the daily calendar; retain existing immutable plans.
create or replace function public.academic_planning_workspace(p_section text,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare org uuid;rows jsonb;total int;choices jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.sessions.manage') or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Academic planning permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 or p_section not in('offerings','batches','rooms','availability','closures','routines') then raise exception 'Choose an academic planning section/page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 select jsonb_build_object(
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.branches where organization_id=org and is_active),'[]'),
 'offerings',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'name',o.name||' · '||o.code,'days',o.teaching_days,'starts_on',coalesce(o.teaching_starts_on,y.starts_on),'ends_on',coalesce(o.teaching_ends_on,y.ends_on))) from public.programme_offerings o left join public.academic_years y on y.id=o.academic_year_id where o.organization_id=org and o.status in('DRAFT','ACTIVE')),'[]'),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name||' · '||o.name,'offering_id',o.id,'branch_id',b.branch_id,'capacity',b.capacity,'windows',b.teaching_windows,'days',o.teaching_days)) from public.batches b join public.programme_offerings o on o.id=b.offering_id where b.organization_id=org and b.is_active),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'offerings',coalesce((select jsonb_agg(offering_id) from public.programme_offering_subjects where subject_id=s.id),'[]'))) from public.subjects s where s.organization_id=org and s.is_active),'[]'),
 'teachers',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name||' · '||s.staff_no,'subjects',coalesce((select jsonb_agg(subject_id) from public.staff_subject_assignments where staff_id=s.id and(effective_to is null or effective_to>=current_date)),'[]'))) from public.staff s where s.status='ACTIVE' and(s.branch_id is null or s.branch_id in(select id from public.branches where organization_id=org)) and exists(select 1 from public.staff_role_assignments a join public.staff_roles r on r.id=a.staff_role_id where a.staff_id=s.id and r.is_teaching_role and(a.effective_to is null or a.effective_to>=current_date))),'[]'),
 'curricula',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'name',v.title||' · v'||v.version,'batch_id',v.batch_id,'subject_id',v.subject_id)) from public.curriculum_versions v join public.batches b on b.id=v.batch_id where b.organization_id=org),'[]'),
 'rooms',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'branch_id',r.branch_id,'capacity',r.capacity)) from public.academic_rooms r join public.branches b on b.id=r.branch_id where b.organization_id=org and r.is_active),'[]')) into choices;
 with items as(
 select to_jsonb(o)||jsonb_build_object('label',o.name) item,o.id from public.programme_offerings o where p_section='offerings' and o.organization_id=org
 union all select to_jsonb(b)||jsonb_build_object('label',b.name||' · '||o.name),b.id from public.batches b join public.programme_offerings o on o.id=b.offering_id where p_section='batches' and b.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',r.name),r.id from public.academic_rooms r join public.branches b on b.id=r.branch_id where p_section='rooms' and b.organization_id=org
 union all select to_jsonb(a)||jsonb_build_object('label',coalesce(r.name,s.full_name)||' · '||a.resource_kind),a.id from public.academic_availability a left join public.academic_rooms r on r.id=a.resource_id and a.resource_kind='ROOM' left join public.staff s on s.id=a.resource_id and a.resource_kind='TEACHER' where p_section='availability' and a.organization_id=org
 union all select to_jsonb(c)||jsonb_build_object('label',c.label),c.id from public.academic_closures c where p_section='closures' and c.organization_id=org
 union all select to_jsonb(r)||jsonb_build_object('label',b.name||' · '||s.name,'teacher',t.full_name,'room',rm.name),r.id from public.academic_routines r join public.batches b on b.id=r.batch_id join public.subjects s on s.id=r.subject_id join public.staff t on t.id=r.teacher_id join public.academic_rooms rm on rm.id=r.room_id where p_section='routines' and b.organization_id=org),paged as(select * from items order by item->>'label',id limit 25 offset(p_page-1)*25)
 select (select count(*) from items),coalesce((select jsonb_agg(item order by item->>'label',id) from paged),'[]') into total,rows;
 return jsonb_build_object('section',p_section,'page',p_page,'total',total,'choices',choices,'rows',rows);
end $$;;
create or replace function public.academic_curriculum_workspace(p_page integer default 1)
returns jsonb language plpgsql security definer set search_path=public as $$
declare org uuid;result jsonb;begin
 if auth.uid() is null or not public.has_permission('academics.curriculum.manage') then raise exception 'Curriculum management permission required.';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception 'Choose a valid page.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 with items as(select jsonb_build_object('id',v.id,'batchId',v.batch_id,'subjectId',v.subject_id,'batch',b.name,'subject',s.name,'version',v.version,'title',v.title,'units',v.units) item,v.published_at,v.id from public.curriculum_versions v join public.batches b on b.id=v.batch_id join public.subjects s on s.id=v.subject_id where b.organization_id=org),paged as(select * from items order by published_at desc,id limit 25 offset(p_page-1)*25)
 select jsonb_build_object('page',p_page,'total',(select count(*) from items),'workspace',jsonb_build_object(
 'branches','[]'::jsonb,'teachers','[]'::jsonb,'rooms','[]'::jsonb,'routines','[]'::jsonb,'sessions','[]'::jsonb,
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'branchId',b.branch_id,'capacity',b.capacity)) from public.batches b where b.organization_id=org and b.is_active),'[]'),
 'subjects',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name)) from public.subjects s where s.organization_id=org and s.is_active),'[]'),
 'curricula',coalesce((select jsonb_agg(item order by published_at desc,id) from paged),'[]'))) into result;return result;
end $$;
revoke all on function public.academic_curriculum_workspace(integer) from public,anon;
grant execute on function public.academic_curriculum_workspace(integer) to authenticated;
