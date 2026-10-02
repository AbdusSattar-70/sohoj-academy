-- Newly verified academy staff may not yet have a campus assignment.
-- Global staff identities are valid; an assigned campus must belong to Sohoj.
create or replace function public.reimbursement_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;manager boolean:=public.has_permission('accounting.expense.manage');r public.staff_reimbursements;sid uuid;org uuid;action text:=p_input->>'action';reason text:=btrim(p_input->>'reason');result jsonb;engine jsonb;amount_value numeric;
begin
 if actor is null or (not manager and not public.has_permission('workforce.self.view')) or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Staff claim access required.';end if;
 if req is null or coalesce(length(reason),0)<5 then raise exception 'Request identity and reason required.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if nullif(p_input->>'id','') is not null then
  select * into r from public.staff_reimbursements where id=(p_input->>'id')::uuid and organization_id=org for update;
  if r.id is null or not public.finance_document_entity_allowed('REIMBURSEMENT',r.id) then raise exception 'Claim unavailable.';end if;
  if r.revision is distinct from (p_input->>'revision')::integer then raise exception 'Claim changed. Refresh before continuing.';end if;
 elsif action<>'SAVE' then raise exception 'Select a claim.';end if;
 if action='SAVE' then
  if r.id is not null and r.status<>'DRAFT' then raise exception 'Only draft claims can be edited.';end if;
  if manager then sid:=(p_input->>'staff_id')::uuid;else select id into sid from public.staff where profile_id=actor and status in('ACTIVE','ON_LEAVE') order by id limit 1;end if;
  if sid is null or not exists(select 1 from public.staff s left join public.branches b on b.id=s.branch_id where s.id=sid and s.status in('ACTIVE','ON_LEAVE') and (s.branch_id is null or b.organization_id=org)) then raise exception 'Choose an active staff identity.';end if;
  if r.id is not null and r.staff_id<>sid then raise exception 'Claim beneficiary cannot be changed after creation.';end if;
  amount_value:=(p_input->>'amount')::numeric;
  if amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) or nullif(p_input->>'expense_date','')::date is null or (p_input->>'expense_date')::date>(now() at time zone 'Asia/Dhaka')::date or coalesce(length(btrim(p_input->>'description')),0)<3 or coalesce(length(btrim(p_input->>'receipt_reference')),0)<3 then raise exception 'Enter actual expense date, positive amount, purpose and receipt reference.';end if;
  if not exists(select 1 from public.finance_expense_categories c join public.finance_accounts a on a.id=c.expense_account_id where c.id=(p_input->>'category_id')::uuid and c.organization_id=org and c.is_active and a.is_active and a.account_type='EXPENSE') then raise exception 'Choose an active expense category.';end if;
  if r.id is null then insert into public.staff_reimbursements(organization_id,staff_id,category_id,expense_date,amount,description,receipt_reference,created_by) values(org,sid,(p_input->>'category_id')::uuid,(p_input->>'expense_date')::date,amount_value,btrim(p_input->>'description'),btrim(p_input->>'receipt_reference'),actor) returning * into r;
  else update public.staff_reimbursements set category_id=(p_input->>'category_id')::uuid,expense_date=(p_input->>'expense_date')::date,amount=amount_value,description=btrim(p_input->>'description'),receipt_reference=btrim(p_input->>'receipt_reference'),revision=revision+1,updated_at=now() where id=r.id returning * into r;end if;
 elsif action='SUBMIT' then
  if r.status<>'DRAFT' or p_input->>'own_funds' is distinct from 'true' then raise exception 'Confirm this draft expense was paid from personal funds, not an academy advance.';end if;
  if not exists(select 1 from public.finance_documents where entity_type='REIMBURSEMENT' and entity_id=r.id and status='READY') then raise exception 'Attach receipt evidence before submitting.';end if;
  if exists(select 1 from public.staff_reimbursements where organization_id=org and staff_id=r.staff_id and id<>r.id and lower(btrim(receipt_reference))=lower(btrim(r.receipt_reference)) and status in('SUBMITTED','POSTED')) then raise exception 'This staff receipt is already submitted or posted.';end if;
  update public.staff_reimbursements set status='SUBMITTED',revision=revision+1,updated_at=now() where id=r.id returning * into r;
 elsif action='RETURN' then
  if not manager or r.status<>'SUBMITTED' then raise exception 'Only finance management may return submitted claims for correction.';end if;
  update public.staff_reimbursements set status='DRAFT',review_note=reason,revision=revision+1,updated_at=now() where id=r.id returning * into r;
 elsif action='CANCEL' then
  if r.status<>'DRAFT' then raise exception 'Only unused draft claims can be cancelled.';end if;
  update public.staff_reimbursements set status='CANCELLED',revision=revision+1,updated_at=now() where id=r.id returning * into r;
 elsif action='POST' then
  if not manager or r.status<>'SUBMITTED' then raise exception 'Finance management must verify a submitted claim before posting.';end if;
  engine:=public.post_accounting_operation(jsonb_build_object('action','CREATE_EXPENSE_DIRECT','request_id',gen_random_uuid(),'reason',reason,'amount',r.amount,'category_id',r.category_id,'staff_id',r.staff_id,'expense_date',r.expense_date,'payment_mode','ON_ACCOUNT','description',r.claim_no||' · '||r.description,'receipt_reference',r.receipt_reference));
  update public.staff_reimbursements set status='POSTED',expense_id=(engine->>'id')::uuid,review_note=reason,revision=revision+1,updated_at=now() where id=r.id returning * into r;
 elsif action='PAY' then
  if not manager or not public.has_permission('finance.payments.post') or r.status<>'POSTED' then raise exception 'Payment access and a posted claim required.';end if;
  amount_value:=(p_input->>'amount')::numeric;if amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) or coalesce(length(btrim(p_input->>'reference')),0)<3 then raise exception 'Enter actual payment amount and reference.';end if;
  perform public.finance_accounting_command(jsonb_build_object('action','SETTLE_PAYABLE','request_id',gen_random_uuid(),'reason',reason,'payable_id',(select payable_id from public.finance_expenses where id=r.expense_id),'amount',amount_value,'payment_account_id',p_input->>'payment_account_id','external_reference',p_input->>'reference'));
 else raise exception 'Unknown claim action.';end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'REIMBURSEMENT',r.id::text,action,reason,to_jsonb(r)||jsonb_build_object('command',p_input));result:=jsonb_build_object('id',r.id,'message','Claim action recorded. Posting creates staff payable; only actual settlement records payment.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.reimbursement_command(jsonb) from public,anon;grant execute on function public.reimbursement_command(jsonb) to authenticated;
create or replace function public.reimbursement_workspace(p_page integer default 1,p_status text default 'ALL') returns jsonb language plpgsql stable security definer set search_path='' as $$
declare manager boolean:=public.has_permission('accounting.expense.manage');org uuid;sid uuid;total integer;rows jsonb;
begin
 if auth.uid() is null or (not manager and not public.has_permission('workforce.self.view')) or not exists(select 1 from public.profiles where id=auth.uid() and status='ACTIVE') then raise exception 'Staff claim access required.';end if;
 if p_page is null or p_page not between 1 and 100000 or p_status not in('ALL','DRAFT','SUBMITTED','POSTED','CANCELLED') then raise exception 'Invalid claim filter.';end if;
 select id into org from public.organizations where code='SOHOJ' and is_active;select id into sid from public.staff where profile_id=auth.uid() and status in('ACTIVE','ON_LEAVE') order by id limit 1;
 select count(*) into total from public.staff_reimbursements where organization_id=org and (manager or staff_id=sid) and (p_status='ALL' or status=p_status);
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into rows from(select r.*,s.full_name staff_name,c.name category_name,e.payable_id,case when e.payable_id is null then 0 else r.amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=e.payable_id),0) end remaining,public.finance_document_workspace('REIMBURSEMENT',r.id) documents from public.staff_reimbursements r join public.staff s on s.id=r.staff_id join public.finance_expense_categories c on c.id=r.category_id left join public.finance_expenses e on e.id=r.expense_id where r.organization_id=org and (manager or r.staff_id=sid) and (p_status='ALL' or r.status=p_status) order by r.created_at desc,r.id limit 25 offset (p_page-1)*25)x;
 return jsonb_build_object('manager',manager,'canPay',manager and public.has_permission('finance.payments.post'),'page',p_page,'total',total,'rows',rows,'staff',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.full_name) order by s.full_name) from public.staff s left join public.branches b on b.id=s.branch_id where (s.branch_id is null or b.organization_id=org) and s.status in('ACTIVE','ON_LEAVE') and (manager or s.id=sid)),'[]'::jsonb),'categories',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_expense_categories where organization_id=org and is_active),'[]'::jsonb),'accounts',case when manager then coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name) from public.finance_accounts where organization_id=org and is_active and account_subtype in('CASH','BANK','MOBILE_BANK')),'[]'::jsonb) else '[]'::jsonb end);
end $$;
revoke all on function public.reimbursement_workspace(integer,text) from public,anon;grant execute on function public.reimbursement_workspace(integer,text) to authenticated;
