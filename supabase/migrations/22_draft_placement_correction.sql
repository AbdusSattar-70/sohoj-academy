-- Correct a mistaken draft placement without creating another student or enquiry.
create or replace function public.correct_admission_placement(p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.admission_cases; b public.batches; f public.fee_plan_versions; today date;
begin
 if auth.uid() is null or not public.has_permission('admissions.create') then raise exception 'Admission permission required.'; end if;
 if length(btrim(coalesce(p_input->>'reason',''))) not between 5 and 500 then raise exception 'Correction reason required.'; end if;
 select * into a from public.admission_cases where id=(p_input->>'admission_id')::uuid for update;
 if a.id is null or a.status not in('DRAFT','READY') then raise exception 'Only an unconfirmed draft can change placement. Use enrollment transfer after admission.'; end if;
 select * into b from public.batches where id=(p_input->>'batch_id')::uuid and is_active for update;
 if b.id is null or b.offering_id is distinct from (p_input->>'offering_id')::uuid or not exists(select 1 from public.programme_offerings where id=b.offering_id and status='ACTIVE') then raise exception 'Choose an active offering and its batch.'; end if;
 if b.organization_id is distinct from (select organization_id from public.batches where id=a.batch_id) then raise exception 'Placement must remain in the same academy.'; end if;
 if (select count(*) from public.enrollments where batch_id=b.id and status='ACTIVE')>=b.capacity then raise exception 'Selected batch is full.'; end if;
 select timezone(timezone,now())::date into today from public.organizations where id=b.organization_id;
 select * into f from public.fee_plan_versions where offering_id=b.offering_id and status='ACTIVE' and effective_from<=today order by effective_from desc,version desc limit 1;
 if f.id is null then raise exception 'Save an effective Fee Plan for this offering first.'; end if;
 if a.batch_id=b.id and a.fee_plan_version_id=f.id then return jsonb_build_object('id',a.id); end if;
 update public.admission_cases set batch_id=b.id,fee_plan_version_id=f.id,status='DRAFT',identity_revision=identity_revision+1,
 selected_discount_percent=0,discount_reason=null,
 additional_charges=coalesce((select jsonb_agg(x||jsonb_build_object('is_active',false)) from jsonb_array_elements(a.additional_charges) x),'[]'::jsonb)
 where id=a.id;
 insert into public.audit_events(actor_profile_id,entity_type,entity_id,action,reason,before_data,after_data)
 values(auth.uid(),'ADMISSION',a.id::text,'CORRECT_PLACEMENT',p_input->>'reason',to_jsonb(a),jsonb_build_object('batch_id',b.id,'fee_plan_id',f.id));
 return jsonb_build_object('id',a.id);
end $$;
revoke all on function public.correct_admission_placement(jsonb) from public,anon;
grant execute on function public.correct_admission_placement(jsonb) to authenticated;
