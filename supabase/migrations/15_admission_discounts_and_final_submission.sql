-- No operator-facing fee versions. Existing historical fee terms remain immutable.
alter table public.programme_offerings add column allowed_discount_percentages integer[] not null default '{}';
alter table public.programme_offerings add constraint valid_discount_percentages
 check(allowed_discount_percentages <@ array[5,10,15,20,25,30]);
alter table public.admission_cases add column selected_discount_percent integer not null default 0
 check(selected_discount_percent in(0,5,10,15,20,25,30)), add column discount_reason text;

create or replace function public.save_offering_discount_policy(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare o public.programme_offerings; choices integer[]; before_data jsonb;
begin
 if auth.uid() is null or not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
 select array_agg(distinct value::integer order by value::integer) into choices
 from jsonb_array_elements_text(coalesce(p_input->'percentages','[]'::jsonb));
 choices:=coalesce(choices,'{}');
 if not choices <@ array[5,10,15,20,25,30] then raise exception 'Choose discounts from 5 to 30 in steps of five.'; end if;
 select * into o from public.programme_offerings where id=(p_input->>'offering_id')::uuid for update;
 if o.id is null then raise exception 'Offering not found.'; end if;
 before_data:=to_jsonb(o);
 update public.programme_offerings set allowed_discount_percentages=choices where id=o.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'OFFERING',o.id::text,'SAVE_DISCOUNT_POLICY','Updated permitted admission discounts',before_data,
 jsonb_build_object('allowed_discount_percentages',choices));
 return jsonb_build_object('id',o.id);
end $$;
revoke all on function public.save_offering_discount_policy(jsonb) from public,anon;
grant execute on function public.save_offering_discount_policy(jsonb) to authenticated;

-- Wrap the tested lifecycle engine; preserve its consent, capacity, audit and finance checks.
alter function public.admission_command(jsonb) rename to admission_lifecycle_command;
revoke all on function public.admission_lifecycle_command(jsonb) from public,anon,authenticated;
create or replace function public.admission_command(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; o public.programme_offerings; req uuid:=nullif(p_input->>'request_id','')::uuid;
 k public.admission_command_keys; result jsonb; pct integer; today date; end_date date;
begin
 if p_input->>'action' not in('SAVE_DISCOUNT','FINALIZE','RETURN_TO_DRAFT') then
  return public.admission_lifecycle_command(p_input);
 end if;
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if req is null or length(btrim(coalesce(p_input->>'reason','')))<5 then raise exception 'A request identity and note are required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));
 select * into k from public.admission_command_keys where request_id=req;
 if found then
  if k.actor_id<>auth.uid() or k.payload<>p_input then raise exception 'Request identity already used.'; end if;
  return k.result;
 end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Only an unsubmitted draft can be changed or finalized.'; end if;
 select off.* into o from public.batches b join public.programme_offerings off on off.id=b.offering_id where b.id=a.batch_id for share of off;
 if p_input->>'action'='SAVE_DISCOUNT' then
  if not public.has_permission('finance.billing.manage') then raise exception 'Billing management permission required.'; end if;
  pct:=coalesce((p_input->>'discount_percent')::integer,0);
  if pct<>0 and not pct=any(o.allowed_discount_percentages) then raise exception 'This discount is not allowed for the offering.'; end if;
  if pct<>0 and p_input->>'discount_reason' not in('FINANCIAL_HARDSHIP','SIBLING','MERIT','LAUNCH_OFFER','STAFF_FAMILY','OTHER') then raise exception 'Select a discount reason.'; end if;
  update public.admission_cases set selected_discount_percent=pct,
   discount_reason=case when pct=0 then null else p_input->>'discount_reason' end where id=a.id;
 elsif p_input->>'action'='RETURN_TO_DRAFT' then
  update public.admission_cases set status='DRAFT' where id=a.id;
 else
  if a.status<>'READY' then raise exception 'Review and verify the draft before final submission.'; end if;
  if not public.has_permission('finance.billing.manage') then raise exception 'Admission final submission requires billing permission.'; end if;
  if a.selected_discount_percent<>0 and not a.selected_discount_percent=any(o.allowed_discount_percentages) then raise exception 'The discount policy changed. Review the chosen discount.'; end if;
  -- Accept and invoice atomically. Failure rolls back student issuance as well.
  result:=public.admission_lifecycle_command(jsonb_build_object('action','ACCEPT','request_id',gen_random_uuid(),
   'admission_id',a.id,'reason',p_input->>'reason'));
  if a.selected_discount_percent>0 then
   select timezone(org.timezone,now())::date into today from public.organizations org where org.id=o.organization_id;
   select greatest(ends_on,today) into end_date from public.academic_years where id=o.academic_year_id;
   perform public.finance_v3_command(jsonb_build_object('action','APPLY_DISCOUNT','request_id',gen_random_uuid(),
    'admission_id',a.id,'kind','PERCENT','value',a.selected_discount_percent,
    'starts_on',date_trunc('month',today)::date,'ends_on',end_date,
    'reason','Admission discount: '||a.discount_reason));
  end if;
  result:=public.admission_lifecycle_command(jsonb_build_object('action','BILL','request_id',gen_random_uuid(),
   'admission_id',a.id,'reason','Initial invoice posted with final admission submission'));
 end if;
 select jsonb_build_object('id',id,'status',status) into result from public.admission_cases where id=a.id;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(req,auth.uid(),'ADMISSION',a.id::text,p_input->>'action',p_input->>'reason',to_jsonb(a),result);
 insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,auth.uid(),p_input,result);
 return result;
end $$;
revoke all on function public.admission_command(jsonb) from public,anon;
grant execute on function public.admission_command(jsonb) to authenticated;

-- Expose only authorized admission review data, with the configured policy.
create or replace function public.admission_discount_options(p_admission_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb;
begin
 if auth.uid() is null or not public.has_permission('admissions.view') then raise exception 'Admission view permission required.'; end if;
 select jsonb_build_object('allowed',o.allowed_discount_percentages,'selected',a.selected_discount_percent,'reason',a.discount_reason)
 into result from public.admission_cases a join public.batches b on b.id=a.batch_id
 join public.programme_offerings o on o.id=b.offering_id where a.id=p_admission_id;
 return result;
end $$;
revoke all on function public.admission_discount_options(uuid) from public,anon;
grant execute on function public.admission_discount_options(uuid) to authenticated;
