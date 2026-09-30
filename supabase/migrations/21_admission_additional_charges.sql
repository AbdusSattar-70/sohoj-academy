alter table public.admission_cases add column additional_charges jsonb not null default '[]';
alter table public.admission_invoice_lines alter column fee_component_id drop not null;
create or replace function public.save_admission_extra_charge(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; req uuid:=(p_input->>'request_id')::uuid; k public.admission_command_keys;
 charge jsonb; result jsonb; amount numeric:=(p_input->>'amount')::numeric;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') or not public.has_permission('finance.billing.manage') then raise exception 'Admission and billing permissions required.'; end if;
 if req is null then raise exception 'Request identity required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if; return k.result; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Additional charges must be agreed before final submission.'; end if;
 if length(btrim(coalesce(p_input->>'name',''))) not between 2 and 100 or amount is null or amount<=0 or amount<>round(amount,2) or amount>99999999
 or coalesce(p_input->>'charge_type','') not in('ADMISSION','EXAM','MATERIAL','OTHER') then raise exception 'Enter a valid one-time fee and amount.'; end if;
 if jsonb_array_length(a.additional_charges)>=10 then raise exception 'No more than ten additional charges per admission.'; end if;
 charge:=jsonb_build_object('id',req,'name',btrim(p_input->>'name'),'charge_type',p_input->>'charge_type','amount',amount,'is_active',true);
 update public.admission_cases set additional_charges=additional_charges||jsonb_build_array(charge) where id=a.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'ADMISSION',a.id::text,'ADD_ONE_TIME_CHARGE','One-time charge agreed with guardian before final submission',a.additional_charges,charge);
 result:=jsonb_build_object('id',a.id);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,auth.uid(),p_input,result);
 return result;
end $$;
revoke all on function public.save_admission_extra_charge(jsonb) from public,anon;
grant execute on function public.save_admission_extra_charge(jsonb) to authenticated;
create or replace function public.deactivate_admission_extra_charge(p_admission_id uuid,p_charge_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; charges jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') or not public.has_permission('finance.billing.manage') then raise exception 'Admission and billing permissions required.'; end if;
 select * into a from public.admission_cases where id=p_admission_id for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Posted charges require a recorded financial correction.'; end if;
 select coalesce(jsonb_agg(case when value->>'id'=p_charge_id::text then value||'{"is_active":false}'::jsonb else value end order by ord),'[]') into charges from jsonb_array_elements(a.additional_charges) with ordinality items(value,ord);
 update public.admission_cases set additional_charges=charges where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'DEACTIVATE_DRAFT_CHARGE','Corrected draft charges before submission',a.additional_charges,charges);
end $$;
revoke all on function public.deactivate_admission_extra_charge(uuid,uuid) from public,anon;
grant execute on function public.deactivate_admission_extra_charge(uuid,uuid) to authenticated;
-- All lines must insert together: the statement-level ledger trigger sees a balanced invoice.
do $migration$
declare definition text; anchor text;
begin
 select pg_get_functiondef('public.admission_lifecycle_command(jsonb)'::regprocedure) into definition;
 anchor:='select coalesce(sum(amount),0) into v_total from public.fee_plan_components where fee_plan_version_id=v_fee.id;';
 if position(anchor in definition)=0 then raise exception 'Initial billing contract changed; inspect before applying additional charges.'; end if;
 definition:=replace(definition,anchor,anchor||$extra$
     v_total:=v_total+coalesce((select sum((value->>'amount')::numeric) from jsonb_array_elements(v_case.additional_charges) where (value->>'is_active')::boolean),0);$extra$);
 anchor:='select v_invoice,id,name,charge_type,amount from public.fee_plan_components where fee_plan_version_id=v_fee.id;';
 if position(anchor in definition)=0 then raise exception 'Invoice line contract changed.'; end if;
 definition:=replace(definition,anchor,$extra$select v_invoice,id,name,charge_type,amount from public.fee_plan_components where fee_plan_version_id=v_fee.id
     union all select v_invoice,null,value->>'name',value->>'charge_type',(value->>'amount')::numeric from jsonb_array_elements(v_case.additional_charges) where (value->>'is_active')::boolean;$extra$);
 execute definition;
end $migration$;
-- Detail keeps standard fees and additional agreed one-time charges together for review/printing.
alter function public.admission_case_detail(uuid) rename to admission_case_detail_with_identity;
revoke all on function public.admission_case_detail_with_identity(uuid) from public,anon,authenticated;
create or replace function public.admission_case_detail(p_admission_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb; charges jsonb; extras jsonb;
begin
 result:=public.admission_case_detail_with_identity(p_admission_id);
 select additional_charges into charges from public.admission_cases where id=p_admission_id;
 select coalesce(jsonb_agg(jsonb_build_object('name',value->>'name','amount',(value->>'amount')::numeric,'recurrence','ONE_TIME')),'[]') into extras from jsonb_array_elements(charges) where (value->>'is_active')::boolean;
 return result||jsonb_build_object('tuitionTotal',(select coalesce(sum(c.amount),0) from public.fee_plan_components c join public.admission_cases a on a.fee_plan_version_id=c.fee_plan_version_id where a.id=p_admission_id and c.charge_type='TUITION'),'additionalCharges',charges,'components',(result->'components')||extras);
end $$;
revoke all on function public.admission_case_detail(uuid) from public,anon;
grant execute on function public.admission_case_detail(uuid) to authenticated;
