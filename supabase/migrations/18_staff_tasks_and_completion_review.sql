create table public.staff_work_tasks(
 id uuid primary key default gen_random_uuid(),staff_id uuid not null references public.staff(id),title text not null check(length(btrim(title)) between 3 and 160),
 instructions text not null default '' check(length(instructions)<=4000),due_on date not null,
 status text not null default 'OPEN' check(status in('OPEN','IN_PROGRESS','SUBMITTED','COMPLETED','CANCELLED')),
 progress integer not null default 0 check(progress between 0 and 100),blocker text not null default '' check(length(blocker)<=2000),
 review_note text,created_by uuid not null references public.profiles(id),updated_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),completed_at timestamptz,
 check(status not in('SUBMITTED','COMPLETED') or progress=100),check((status='COMPLETED')=(completed_at is not null))
);
create index work_task_queue_idx on public.staff_work_tasks(staff_id,status,due_on,id);
alter table public.staff_work_tasks enable row level security;
create policy staff_work_tasks_scope on public.staff_work_tasks for select to authenticated using(public.has_permission('workforce.manage') or (public.has_permission('workforce.self.view') and staff_id in(select id from public.staff where profile_id=auth.uid() and status='ACTIVE')));
grant select on public.staff_work_tasks to authenticated;
revoke insert,update,delete on public.staff_work_tasks from anon,authenticated;
create trigger work_tasks_no_delete before delete on public.staff_work_tasks for each row execute function public.prevent_permanent_record_delete();

create function public.staff_task_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('workforce.manage');own_staff uuid;task public.staff_work_tasks;req uuid:=(p_input->>'request_id')::uuid;old_key public.admission_command_keys;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');before_data jsonb;result jsonb;progress_value integer;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Workforce access required.';end if;
 select id into own_staff from public.staff where profile_id=actor and status='ACTIVE';
 if req is null or coalesce(length(reason),0)<5 then raise exception 'Request ID and reason are required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into old_key from public.admission_command_keys where request_id=req;
 if found then if old_key.actor_id<>actor or old_key.payload<>p_input then raise exception 'Request identity conflict.';end if;return old_key.result;end if;
 if action='CREATE' then
  if not manager then raise exception 'Only an administrator assigns work.';end if;
  perform 1 from public.staff where id=(p_input->>'staff_id')::uuid and status='ACTIVE' for update;if not found then raise exception 'Choose active staff.';end if;
  insert into public.staff_work_tasks(staff_id,title,instructions,due_on,created_by,updated_by) values((p_input->>'staff_id')::uuid,btrim(p_input->>'title'),coalesce(p_input->>'instructions',''),(p_input->>'due_on')::date,actor,actor) returning * into task;
 else
  select * into task from public.staff_work_tasks where id=(p_input->>'id')::uuid for update;
  if task.id is null or (not manager and task.staff_id is distinct from own_staff) then raise exception 'Task unavailable.';end if;
  before_data:=to_jsonb(task);
  if action in('REPORT','SUBMIT') then
   if task.staff_id is distinct from own_staff then raise exception 'Only the assigned person reports their progress.';end if;
   if task.status not in('OPEN','IN_PROGRESS') then raise exception 'This task is not open for progress changes.';end if;
   progress_value:=case when action='SUBMIT' then 100 else (p_input->>'progress')::integer end;
   if progress_value is null or progress_value<0 or progress_value>100 or (action='REPORT' and progress_value=100) then raise exception 'Use Submit completion for 100%% progress.';end if;
   update public.staff_work_tasks set progress=progress_value,blocker=coalesce(p_input->>'blocker',''),status=case when action='SUBMIT' then 'SUBMITTED' else 'IN_PROGRESS' end,updated_by=actor,updated_at=now() where id=task.id returning * into task;
  elsif action in('ACCEPT','RETURN') then
   if not manager or task.status<>'SUBMITTED' then raise exception 'Administrator reviews submitted completion only.';end if;
   update public.staff_work_tasks set status=case when action='ACCEPT' then 'COMPLETED' else 'IN_PROGRESS' end,review_note=reason,completed_at=case when action='ACCEPT' then now() else null end,updated_by=actor,updated_at=now() where id=task.id returning * into task;
  elsif action='EDIT' then
   if not manager or task.status not in('OPEN','IN_PROGRESS') then raise exception 'Only open tasks can be edited by an administrator.';end if;
   perform 1 from public.staff where id=(p_input->>'staff_id')::uuid and status='ACTIVE' for update;if not found then raise exception 'Choose active staff.';end if;
   if task.staff_id is distinct from (p_input->>'staff_id')::uuid then raise exception 'Cancel and create a new assignment to change the responsible person.';end if;
   update public.staff_work_tasks set title=btrim(p_input->>'title'),instructions=coalesce(p_input->>'instructions',''),due_on=(p_input->>'due_on')::date,updated_by=actor,updated_at=now() where id=task.id returning * into task;
  elsif action='CANCEL' then
   if not manager or task.status in('COMPLETED','CANCELLED') then raise exception 'Only an open assignment can be cancelled.';end if;
   update public.staff_work_tasks set status='CANCELLED',review_note=reason,updated_by=actor,updated_at=now() where id=task.id returning * into task;
  else raise exception 'Unknown task action.';end if;
 end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data,correlation_id) values(actor,'STAFF_TASK',task.id::text,action,reason,before_data,to_jsonb(task),req);
 result:=jsonb_build_object('id',task.id,'ok',true);insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.staff_task_command(jsonb) from public,anon;
grant execute on function public.staff_task_command(jsonb) to authenticated;

create function public.staff_tasks_workspace(p_staff_id uuid default null,p_history boolean default false,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();manager boolean:=public.has_permission('workforce.manage');sid uuid;rows jsonb;total integer;stats jsonb;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') or not(manager or public.has_permission('workforce.self.view')) then raise exception 'Workforce access required.';end if;
 select id into sid from public.staff where profile_id=actor and status='ACTIVE';
 if p_staff_id is not null then if not manager and p_staff_id is distinct from sid then raise exception 'Only your own tasks are available.';end if;sid:=p_staff_id;end if;
 if p_page is null or p_page<1 or p_page>10000 then raise exception 'Invalid page.';end if;
 select jsonb_build_object('open',count(*) filter(where status in('OPEN','IN_PROGRESS')),'review',count(*) filter(where status='SUBMITTED'),'completed',count(*) filter(where status='COMPLETED'),'blocked',count(*) filter(where status in('OPEN','IN_PROGRESS') and length(btrim(blocker))>0),'overdue',count(*) filter(where status in('OPEN','IN_PROGRESS','SUBMITTED') and due_on<(now() at time zone 'Asia/Dhaka')::date)) into stats from public.staff_work_tasks where staff_id=sid;
 select count(*) into total from public.staff_work_tasks where staff_id=sid and (status in('COMPLETED','CANCELLED'))=coalesce(p_history,false);
 select coalesce(jsonb_agg(to_jsonb(t) order by t.due_on,t.id),'[]'::jsonb) into rows from(select * from public.staff_work_tasks where staff_id=sid and (status in('COMPLETED','CANCELLED'))=coalesce(p_history,false) order by due_on,id limit 25 offset (p_page-1)*25) t;
 return jsonb_build_object('manager',manager,'staffId',sid,'ownStaffId',(select id from public.staff where profile_id=actor and status='ACTIVE'),'total',total,'stats',stats,'tasks',rows);
end $$;
revoke all on function public.staff_tasks_workspace(uuid,boolean,integer) from public,anon;
grant execute on function public.staff_tasks_workspace(uuid,boolean,integer) to authenticated;
