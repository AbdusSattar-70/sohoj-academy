alter table public.general_ledger_journals drop constraint general_ledger_journals_journal_type_check;
alter table public.general_ledger_journals add constraint general_ledger_journals_journal_type_check check(journal_type in('INVOICE','INVOICE_CREDIT','PAYMENT','REFUND','ADVANCE_PAYMENT','ADVANCE_SETTLEMENT','ADVANCE_REFUND','EXPENSE','PAYABLE_SETTLEMENT','COMPENSATION_RUN','COMPENSATION_SETTLEMENT','MANUAL','PURCHASE_ADJUSTMENT','SUPPLIER_REFUND'));
alter table public.finance_payable_settlements add column settlement_kind text not null default 'PAYMENT' check(settlement_kind in('PAYMENT','CREDIT_NOTE'));
alter table public.finance_payable_settlements add constraint credit_note_has_no_cash check(settlement_kind<>'CREDIT_NOTE' or (payment_account_id is null and advance_id is null));
insert into public.finance_accounts(organization_id,code,name,account_type,account_subtype,is_control_account) select id,'1230','Supplier Refund Receivable','ASSET','SUPPLIER_REFUND_RECEIVABLE',true from public.organizations where code='SOHOJ';
create table public.purchase_adjustments(
 id uuid primary key default gen_random_uuid(),purchase_id uuid not null references public.finance_purchases(id),kind text not null check(kind in('RETURN','CORRECTION')),
 reference text not null,adjustment_date date not null,amount numeric(14,2) not null check(amount>0),payable_credit numeric(14,2) not null check(payable_credit>=0),cash_refund numeric(14,2) not null check(cash_refund>=0),refund_due numeric(14,2) not null check(refund_due>=0),
 payment_account_id uuid references public.finance_accounts(id),journal_id uuid not null references public.general_ledger_journals(id),reason text not null,actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),check(amount=payable_credit+cash_refund+refund_due)
);
create unique index purchase_adjustment_reference on public.purchase_adjustments(purchase_id,lower(btrim(reference)));
create table public.purchase_refund_receipts(id uuid primary key default gen_random_uuid(),adjustment_id uuid not null references public.purchase_adjustments(id),amount numeric(14,2) not null check(amount>0),receipt_date date not null,payment_account_id uuid not null references public.finance_accounts(id),reference text not null,reason text not null,actor_id uuid not null references public.profiles(id),journal_id uuid not null references public.general_ledger_journals(id),created_at timestamptz not null default now());
alter table public.purchase_adjustments enable row level security;alter table public.purchase_refund_receipts enable row level security;
create policy purchase_adjustment_read on public.purchase_adjustments for select to authenticated using(public.finance_document_entity_allowed('PURCHASE',purchase_id));
create policy purchase_refund_read on public.purchase_refund_receipts for select to authenticated using(exists(select 1 from public.purchase_adjustments a where a.id=adjustment_id and public.finance_document_entity_allowed('PURCHASE',a.purchase_id)));
grant select on public.purchase_adjustments,public.purchase_refund_receipts to authenticated;revoke insert,update,delete on public.purchase_adjustments,public.purchase_refund_receipts from anon,authenticated;
create trigger purchase_adjustment_history before update or delete on public.purchase_adjustments for each row execute function public.prevent_permanent_record_delete();
create trigger purchase_refund_history before update or delete on public.purchase_refund_receipts for each row execute function public.prevent_permanent_record_delete();
create function public.purchase_adjustment_command(p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();req uuid:=(p_input->>'request_id')::uuid;key public.admission_command_keys;p public.finance_purchases;e public.finance_expenses;payable public.finance_payables;a public.purchase_adjustments;action text:=p_input->>'action';amount_value numeric:=(p_input->>'amount')::numeric;cash_value numeric:=coalesce((p_input->>'cash_refund')::numeric,0);credit_value numeric:=0;due_value numeric;account uuid;refund_account uuid;lines jsonb:='[]'::jsonb;journal uuid;record_id uuid:=gen_random_uuid();date_value date:=(p_input->>'date')::date;reason text:=btrim(p_input->>'reason');reference_value text:=btrim(p_input->>'reference');result jsonb;
begin
 if actor is null or not public.has_permission('accounting.expense.manage') or not exists(select 1 from public.profiles where id=actor and status='ACTIVE') then raise exception 'Expense management access required.';end if;
 if req is null or amount_value is null or amount_value<=0 or amount_value<>round(amount_value,2) or cash_value<0 or cash_value<>round(cash_value,2) or date_value is null or date_value>(now() at time zone 'Asia/Dhaka')::date or coalesce(length(reason),0)<10 or coalesce(length(reference_value),0)<3 then raise exception 'Enter an amount, valid date, document reference and clear explanation.';end if;
 perform pg_advisory_xact_lock(hashtextextended(req::text,0));select * into key from public.admission_command_keys where request_id=req;if found then if key.actor_id<>actor or key.payload<>p_input then raise exception 'Request identity conflict.';end if;return key.result;end if;
 if action='ADJUST' then
  select * into p from public.finance_purchases where id=(p_input->>'purchase_id')::uuid for update;
  if p.status is distinct from 'POSTED' or not public.finance_document_entity_allowed('PURCHASE',p.id) then raise exception 'Choose a posted purchase.';end if;
  select * into e from public.finance_expenses where id=p.expense_id;
  if date_value<e.expense_date then raise exception 'Adjustment cannot precede its expense.';end if;
  if p_input->>'kind' not in('RETURN','CORRECTION') or p_input->>'confirmed' is distinct from 'true' then raise exception 'Confirm the supplier credit note or expense correction.';end if;
  if amount_value>e.amount-coalesce((select sum(amount) from public.purchase_adjustments where purchase_id=p.id),0) then raise exception 'Adjustment exceeds the remaining original expense.';end if;
  if exists(select 1 from public.purchase_adjustments where purchase_id=p.id and lower(btrim(reference))=lower(reference_value)) then raise exception 'This correction reference is already recorded.';end if;
  if e.payable_id is not null then
   select * into payable from public.finance_payables where id=e.payable_id for update;
   credit_value:=least(amount_value,greatest(0,payable.original_amount-coalesce((select sum(amount) from public.finance_payable_settlements where payable_id=payable.id),0)));
  end if;
  if cash_value>amount_value-credit_value then raise exception 'Cash refund exceeds the paid portion after supplier credit.';end if;
  due_value:=amount_value-credit_value-cash_value;
  if credit_value>0 then
   insert into public.finance_payable_settlements(payable_id,amount,settled_by,reason,external_reference,settlement_kind) values(payable.id,credit_value,actor,reason,reference_value,'CREDIT_NOTE');
   update public.finance_payables set status=case when original_amount<=(select sum(amount) from public.finance_payable_settlements where payable_id=payable.id) then 'SETTLED' else 'PARTIALLY_SETTLED' end where id=payable.id;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',payable.payable_account_id,'debit',credit_value,'credit',0));
  end if;
  if cash_value>0 then
   if not public.has_permission('finance.payments.post') then raise exception 'Payment access required to record money received.';end if;
   select id into account from public.finance_accounts where id=nullif(p_input->>'payment_account_id','')::uuid and organization_id=p.organization_id and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose an active refund-receiving account.';end if;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',account,'debit',cash_value,'credit',0));
  end if;
  if due_value>0 then select id into refund_account from public.finance_accounts where organization_id=p.organization_id and account_subtype='SUPPLIER_REFUND_RECEIVABLE';lines:=lines||jsonb_build_array(jsonb_build_object('account_id',refund_account,'debit',due_value,'credit',0));end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',e.expense_account_id,'debit',0,'credit',amount_value));
  journal:=public.finance_post_journal(p.organization_id,date_value,'PURCHASE_ADJUSTMENT','PURCHASE_ADJUSTMENT',record_id::text,p.purchase_no||' · '||reference_value,actor,lines);
  insert into public.purchase_adjustments(id,purchase_id,kind,reference,adjustment_date,amount,payable_credit,cash_refund,refund_due,payment_account_id,journal_id,reason,actor_id) values(record_id,p.id,p_input->>'kind',reference_value,date_value,amount_value,credit_value,cash_value,due_value,account,journal,reason,actor);
 elsif action='COLLECT_REFUND' then
  select * into a from public.purchase_adjustments where id=(p_input->>'adjustment_id')::uuid for update;
  if a.id is null or not public.finance_document_entity_allowed('PURCHASE',a.purchase_id) or not public.has_permission('finance.payments.post') then raise exception 'Refund collection access required.';end if;
  select * into p from public.finance_purchases where id=a.purchase_id;
  if date_value<a.adjustment_date or amount_value>a.refund_due-coalesce((select sum(amount) from public.purchase_refund_receipts where adjustment_id=a.id),0) then raise exception 'Refund exceeds outstanding supplier refund or precedes its credit note.';end if;
  select id into account from public.finance_accounts where id=(p_input->>'payment_account_id')::uuid and organization_id=p.organization_id and is_active and account_subtype in('CASH','BANK','MOBILE_BANK');if account is null then raise exception 'Choose an active receiving account.';end if;
  select id into refund_account from public.finance_accounts where organization_id=p.organization_id and account_subtype='SUPPLIER_REFUND_RECEIVABLE';
  journal:=public.finance_post_journal(p.organization_id,date_value,'SUPPLIER_REFUND','SUPPLIER_REFUND',record_id::text,reference_value,actor,jsonb_build_array(jsonb_build_object('account_id',account,'debit',amount_value,'credit',0),jsonb_build_object('account_id',refund_account,'debit',0,'credit',amount_value)));
  insert into public.purchase_refund_receipts(id,adjustment_id,amount,receipt_date,payment_account_id,reference,reason,actor_id,journal_id) values(record_id,a.id,amount_value,date_value,account,reference_value,reason,actor,journal);
 else raise exception 'Unknown purchase adjustment action.';end if;
 insert into public.audit_events(correlation_id,actor_profile_id,entity_type,entity_id,action,reason,after_data) values(req,actor,'PURCHASE',p.id::text,action,reason,p_input||jsonb_build_object('journal_id',journal));result:=jsonb_build_object('id',record_id,'message','Compensating entry posted. Original expense and payment history remain unchanged.');insert into public.admission_command_keys(request_id,actor_id,payload,result) values(req,actor,p_input,result);return result;
end $$;
revoke all on function public.purchase_adjustment_command(jsonb) from public,anon;
grant execute on function public.purchase_adjustment_command(jsonb) to authenticated;
create function public.purchase_adjustment_workspace(p_ids uuid[]) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare id_value uuid;result jsonb:='[]'::jsonb;
begin if p_ids is null or cardinality(p_ids)>25 then raise exception 'Request at most 25 purchases.';end if;foreach id_value in array p_ids loop
 if not public.finance_document_entity_allowed('PURCHASE',id_value) then raise exception 'Purchase adjustment access denied.';end if;
 result:=result||jsonb_build_array(jsonb_build_object('purchaseId',id_value,'adjustments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'kind',a.kind,'reference',a.reference,'date',a.adjustment_date,'amount',a.amount,'credit',a.payable_credit,'cash',a.cash_refund,'due',a.refund_due-coalesce((select sum(amount) from public.purchase_refund_receipts where adjustment_id=a.id),0),'reason',a.reason) order by created_at desc) from public.purchase_adjustments a where a.purchase_id=id_value),'[]'::jsonb)));end loop;return result;end $$;
revoke all on function public.purchase_adjustment_workspace(uuid[]) from public,anon;
grant execute on function public.purchase_adjustment_workspace(uuid[]) to authenticated;
