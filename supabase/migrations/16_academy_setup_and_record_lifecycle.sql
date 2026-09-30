alter table public.organizations add column setup_completed_at timestamptz,
 add column setup_completed_by uuid references public.profiles(id);
create or replace function public.academy_setup_status()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare o public.organizations; steps jsonb; ready boolean;
begin
 if auth.uid() is null or not public.has_permission('dashboard.view') then raise exception 'ERP access required.'; end if;
 select * into o from public.organizations where code='SOHOJ' and is_active limit 1;
 steps:=jsonb_build_array(
 jsonb_build_object('id','academy','title','Academy and campus','href','/dashboard/setup','done',o.id is not null and exists(select 1 from public.branches where organization_id=o.id and is_active)),
 jsonb_build_object('id','directory','title','Academic years, classes, subjects and programmes','href','/dashboard/crm/manage','done',
 exists(select 1 from public.academic_years where organization_id=o.id and is_active) and
 exists(select 1 from public.classes where organization_id=o.id and is_active) and
 exists(select 1 from public.subjects where organization_id=o.id and is_active) and
 exists(select 1 from public.programs where organization_id=o.id and is_active)),
 jsonb_build_object('id','rules','title','Capacity and enrollment rules','href','/dashboard/governance/rules','done',
 exists(select 1 from public.business_rule_versions where domain='academics' and rule_key='batch_capacity_policy' and status='ACTIVE') and
 exists(select 1 from public.business_rule_versions where domain='admissions' and rule_key='activation_policy' and status='ACTIVE')),
 jsonb_build_object('id','offering','title','Programme offering','href','/dashboard/academics/offerings','done',exists(select 1 from public.programme_offerings where organization_id=o.id and status<>'RETIRED')),
 jsonb_build_object('id','fees','title','Standard fees and permitted discounts','href','/dashboard/finance/fee-plans','done',exists(select 1 from public.programme_offerings off join public.fee_plan_versions f on f.offering_id=off.id where off.organization_id=o.id and off.status='ACTIVE' and f.status='ACTIVE' and f.effective_from<=timezone(o.timezone,now())::date)),
 jsonb_build_object('id','batches','title','At least one admission-ready batch','href','/dashboard/academics/batches','done',exists(select 1 from public.batches b join public.programme_offerings off on off.id=b.offering_id join public.fee_plan_versions f on f.offering_id=off.id where off.organization_id=o.id and off.status='ACTIVE' and b.is_active and f.status='ACTIVE' and f.effective_from<=timezone(o.timezone,now())::date)));
 select bool_and((value->>'done')::boolean) into ready from jsonb_array_elements(steps);
 return jsonb_build_object('completed',o.setup_completed_at is not null,'ready',coalesce(ready,false),'steps',steps,'academyName',o.name);
end $$;
revoke all on function public.academy_setup_status() from public,anon;
grant execute on function public.academy_setup_status() to authenticated;

create or replace function public.complete_academy_setup()
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('system.settings.manage') then raise exception 'Academy setup permission required.'; end if;
 perform pg_advisory_xact_lock(871604);
 if not (public.academy_setup_status()->>'ready')::boolean then raise exception 'Finish all prerequisite settings before opening operations.'; end if;
 update public.organizations set setup_completed_at=now(),setup_completed_by=auth.uid() where code='SOHOJ' and is_active;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason) values(auth.uid(),'ACADEMY',(select id::text from public.organizations where code='SOHOJ'),'COMPLETE_SETUP','Reviewed academy configuration before opening operations');
 return public.academy_setup_status();
end $$;
revoke all on function public.complete_academy_setup() from public,anon;
grant execute on function public.complete_academy_setup() to authenticated;

create or replace function public.record_lifecycle_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare target_table text; permission text; status_column text; active_value text; inactive_value text;
 before_data jsonb; after_data jsonb; target uuid:=(p_input->>'id')::uuid; enabled boolean:=(p_input->>'active')::boolean;
begin
 case p_input->>'entity'
 when 'batch' then target_table:='batches';permission:='academics.manage';status_column:='is_active';
 when 'offering' then target_table:='programme_offerings';permission:='academics.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='RETIRED';
 when 'student' then target_table:='students';permission:='students.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='INACTIVE';
 when 'staff' then target_table:='staff';permission:='staff.manage';status_column:='status';active_value:='ACTIVE';inactive_value:='ARCHIVED';
 when 'referrer' then target_table:='referral_people';permission:='admissions.create';status_column:='is_active';
 else raise exception 'This record requires its dedicated correction workflow.';
 end case;
 if auth.uid() is null or not public.has_permission(permission) then raise exception 'Record management permission required.'; end if;
 if enabled is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'Select a state and provide a reason.'; end if;
 execute format('select to_jsonb(t) from public.%I t where id=$1 for update',target_table) into before_data using target;
 if before_data is null then raise exception 'Record not found.'; end if;
 if target_table='staff' and before_data->>'profile_id'=auth.uid()::text and not enabled then raise exception 'You cannot deactivate your own staff record.'; end if;
 if target_table='programme_offerings' and enabled and not exists(select 1 from public.fee_plan_versions where offering_id=target and status='ACTIVE') then raise exception 'Save an effective Fee Plan before activating the offering.'; end if;
 if target_table='students' and enabled and not exists(select 1 from public.enrollments where student_id=target and status='ACTIVE') then raise exception 'Activate an enrollment before activating this student.'; end if;
 if target_table='students' and not enabled and exists(select 1 from public.enrollments where student_id=target and status='ACTIVE') then raise exception 'Withdraw or close the active enrollment first; its history and balances remain intact.'; end if;
 if status_column='is_active' then
 execute format('update public.%I set is_active=$2 where id=$1 returning to_jsonb(%I.*)',target_table,target_table) into after_data using target,enabled;
 else
 execute format('update public.%I set status=%L where id=$1 returning to_jsonb(%I.*)',target_table,case when enabled then active_value else inactive_value end,target_table) into after_data using target;
 end if;
 if target_table='staff' then update public.profiles set status=case when enabled then 'ACTIVE'::public.profile_status else 'SUSPENDED'::public.profile_status end where id=(before_data->>'profile_id')::uuid; end if;
 if target_table='programme_offerings' and not enabled then update public.programme_offerings set is_website_visible=false,is_accepting_applications=false where id=target; end if;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),upper(p_input->>'entity'),target::text,case when enabled then 'REACTIVATE' else 'MARK_INACTIVE' end,p_input->>'reason',before_data,after_data);
 return jsonb_build_object('id',target);
end $$;
revoke all on function public.record_lifecycle_command(jsonb) from public,anon;
grant execute on function public.record_lifecycle_command(jsonb) to authenticated;
