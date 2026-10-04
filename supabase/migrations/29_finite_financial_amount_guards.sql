-- PostgreSQL numeric supports NaN. It must not enter financial amounts,
-- including through direct authenticated RPC calls that bypass browser validation.
alter table public.general_ledger_lines add constraint ledger_amounts_finite check(debit<>'NaN'::numeric and credit<>'NaN'::numeric);
alter table public.finance_expenses add constraint expense_amount_finite check(amount<>'NaN'::numeric);
alter table public.finance_payables add constraint payable_amount_finite check(original_amount<>'NaN'::numeric);
alter table public.finance_payable_settlements add constraint payable_settlement_finite check(amount<>'NaN'::numeric);
alter table public.finance_purchases add constraint purchase_total_finite check(total<>'NaN'::numeric);
alter table public.staff_reimbursements add constraint reimbursement_amount_finite check(amount<>'NaN'::numeric);
alter table public.academy_assets add constraint asset_values_finite check(cost<>'NaN'::numeric and residual<>'NaN'::numeric);
alter table public.asset_depreciation_entries add constraint depreciation_amount_finite check(amount<>'NaN'::numeric);
alter table public.asset_disposals add constraint disposal_values_finite check(proceeds<>'NaN'::numeric and book_value<>'NaN'::numeric);
alter table public.purchase_adjustments add constraint purchase_adjustment_values_finite check(amount<>'NaN'::numeric and payable_credit<>'NaN'::numeric and cash_refund<>'NaN'::numeric and refund_due<>'NaN'::numeric);
alter table public.purchase_refund_receipts add constraint supplier_refund_amount_finite check(amount<>'NaN'::numeric);
