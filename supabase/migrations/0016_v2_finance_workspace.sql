create or replace function public.finance_workspace()
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not public.has_permission('finance.view') then raise exception 'Finance access denied.'; end if;
 return jsonb_build_object(
 'admissions',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.identity_snapshot->>'student_name','number',a.admission_no,'status',a.status)) from public.admission_cases a),'[]'::jsonb),
 'years',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.academic_years),'[]'::jsonb),
 'terms',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'startsOn',starts_on,'endsOn',ends_on,'dueOn',due_on)) from public.billing_terms),'[]'::jsonb),
 'invoices',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'admissionId',a.id,'name',a.identity_snapshot->>'student_name','number',i.invoice_no,'kind',i.invoice_kind,'period',i.billing_period,'dueOn',i.due_on,'currency',i.currency_code,'gross',b.gross,'credits',b.credits,'net',b.net,'paid',b.paid,'refunded',b.refunded,'due',b.due,'credit',b.credit_balance,'reserved',b.reserved_refunds,
 'lines',coalesce((select jsonb_agg(jsonb_build_object('name',name,'amount',amount)) from public.admission_invoice_lines where invoice_id=i.id),'[]'::jsonb)) order by i.posted_at desc) from public.admission_invoices i join public.admission_cases a on a.id=i.admission_id cross join lateral public.invoice_balance(i.id) b),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'invoiceId',pa.invoice_id,'number',p.receipt_no,'amount',p.amount,'postedAt',p.posted_at,'method',pm.name,'remaining',p.amount-coalesce((select sum(amount) from public.refund_authorizations where payment_id=p.id),0))) from public.admission_payments p join public.admission_payment_allocations pa on pa.payment_id=p.id join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'approvals',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'admissionId',r.entity_id,'type',r.workflow_type,'status',r.status,'requesterId',r.requested_by,'requester',p.display_name,'reason',r.request_note,'decisionNote',r.decision_note,'payload',r.payload_snapshot,'createdAt',r.requested_at) order by r.requested_at desc) from public.approval_requests r join public.profiles p on p.id=r.requested_by where r.workflow_type in ('FINANCE_DISCOUNT','ADMISSION_CANCEL','FINANCE_REFUND')),'[]'::jsonb),
 'discounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'admissionId',admission_id,'kind',kind,'value',value,'startsOn',starts_on,'endsOn',ends_on)) from public.admission_discounts),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'invoiceId',r.invoice_id,'paymentId',r.payment_id,'amount',r.amount,'number',p.refund_no,'postedAt',p.posted_at,'method',pm.name,'reference',p.external_reference)) from public.refund_authorizations r left join public.refund_payouts p on p.authorization_id=r.id left join public.payment_methods pm on pm.id=p.payment_method_id),'[]'::jsonb),
 'runs',coalesce((select jsonb_agg(jsonb_build_object('id',id,'period',period,'count',invoice_count,'gross',gross_total,'postedAt',posted_at) order by posted_at desc) from public.billing_runs),'[]'::jsonb),
 'paymentMethods',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.payment_methods where is_active),'[]'::jsonb)
 );
end; $$;
revoke all on function public.finance_workspace() from public,anon;
grant execute on function public.finance_workspace() to authenticated;
