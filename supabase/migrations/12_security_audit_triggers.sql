-- Sohoj Academy fresh database baseline: security audit triggers.
-- Install on an empty application schema. Each object is defined once.

grant usage on schema public to anon, authenticated, service_role;
revoke create on schema public from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

alter table public.organizations enable row level security;

alter table public.branches enable row level security;

alter table public.profiles enable row level security;

alter table public.system_roles enable row level security;

alter table public.permissions enable row level security;

alter table public.role_permissions enable row level security;

alter table public.user_role_assignments enable row level security;

alter table public.staff enable row level security;

alter table public.staff_roles enable row level security;

alter table public.staff_role_assignments enable row level security;

alter table public.audit_events enable row level security;

alter table public.approval_requests enable row level security;

alter table public.business_rule_versions enable row level security;

alter table public.academic_years enable row level security;

alter table public.classes enable row level security;

alter table public.programs enable row level security;

alter table public.subjects enable row level security;

alter table public.areas enable row level security;

alter table public.schools enable row level security;

alter table public.lead_sources enable row level security;

alter table public.guardian_relationships enable row level security;

alter table public.payment_methods enable row level security;

alter table public.prospects enable row level security;

alter table public.prospect_program_interests enable row level security;

alter table public.prospect_subject_interests enable row level security;

alter table public.prospect_followups enable row level security;

alter table public.students enable row level security;

alter table public.guardians enable row level security;

alter table public.student_guardians enable row level security;

alter table public.batches enable row level security;

alter table public.enrollments enable row level security;

alter table public.staff_subject_assignments enable row level security;

alter table public.academic_groups enable row level security;

alter table public.programme_offerings enable row level security;

alter table public.fee_plan_versions enable row level security;

alter table public.fee_plan_components enable row level security;

alter table public.admission_cases enable row level security;

alter table public.admission_invoices enable row level security;

alter table public.admission_invoice_lines enable row level security;

alter table public.admission_command_keys enable row level security;

alter table public.admission_payments enable row level security;

alter table public.admission_payment_allocations enable row level security;

alter table public.billing_terms enable row level security;

alter table public.admission_discounts enable row level security;

alter table public.invoice_credits enable row level security;

alter table public.refund_authorizations enable row level security;

alter table public.refund_payouts enable row level security;

alter table public.admission_cancellations enable row level security;

alter table public.billing_runs enable row level security;

alter table public.student_merges enable row level security;

alter table public.enrollment_transfers enable row level security;

alter table public.academic_rooms enable row level security;

alter table public.curriculum_versions enable row level security;

alter table public.academic_routines enable row level security;

alter table public.class_sessions enable row level security;

alter table public.attendance_submissions enable row level security;

alter table public.programme_offering_subjects enable row level security;

alter table public.class_logs enable row level security;

alter table public.question_bank_items enable row level security;

alter table public.homework_checks enable row level security;

alter table public.academic_assessments enable row level security;

alter table public.assessment_result_submissions enable row level security;

alter table public.finance_accounts enable row level security;

alter table public.finance_cost_centres enable row level security;

alter table public.general_ledger_journals enable row level security;

alter table public.general_ledger_lines enable row level security;

alter table public.vendors enable row level security;

alter table public.finance_payment_account_map enable row level security;

alter table public.finance_fee_revenue_map enable row level security;

alter table public.finance_payables enable row level security;

alter table public.finance_payable_settlements enable row level security;

alter table public.finance_advances enable row level security;

alter table public.finance_advance_movements enable row level security;

alter table public.finance_expense_categories enable row level security;

alter table public.finance_expenses enable row level security;

alter table public.finance_expense_reconciliations enable row level security;

alter table public.finance_account_reconciliations enable row level security;

alter table public.teacher_referrals enable row level security;

alter table public.teacher_compensation_runs enable row level security;

alter table public.teacher_compensation_events enable row level security;

alter table public.teacher_compensation_adjustments enable row level security;

alter table public.teacher_compensation_lines enable row level security;

alter table public.teacher_compensation_settlements enable row level security;

alter table public.teacher_compensation_claims enable row level security;

alter table public.referral_people enable row level security;

alter table public.admission_referrals enable row level security;

alter table public.referral_bonus_awards enable row level security;

alter table public.staff_admission_intake_requests enable row level security;

alter table public.admission_physical_consent_receipts enable row level security;

alter table public.staff_access_requests enable row level security;

create policy organizations_authenticated_read on public.organizations as permissive for select to authenticated using (true);

create policy branches_authenticated_read on public.branches as permissive for select to authenticated using (true);

create policy staff_roles_authenticated_read on public.staff_roles as permissive for select to authenticated using (true);

create policy audit_permission_read on public.audit_events as permissive for select to authenticated using (has_permission('audit.view'::text));

create policy staff_role_assignments_read on public.staff_role_assignments as permissive for select to authenticated using (has_permission('staff.view'::text));

create policy staff_role_assignments_insert on public.staff_role_assignments as permissive for insert to authenticated with check (has_permission('staff.manage'::text));

create policy staff_role_assignments_update on public.staff_role_assignments as permissive for update to authenticated using (has_permission('staff.manage'::text)) with check (has_permission('staff.manage'::text));

create policy academic_years_read on public.academic_years as permissive for select to authenticated using (true);

create policy master_data_manage_academic_years on public.academic_years as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy classes_public_read on public.classes as permissive for select to anon, authenticated using (is_active);

create policy master_data_manage_classes on public.classes as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy programs_public_read on public.programs as permissive for select to anon, authenticated using (is_active);

create policy master_data_manage_programs on public.programs as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy subjects_public_read on public.subjects as permissive for select to anon, authenticated using (is_active);

create policy master_data_manage_subjects on public.subjects as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy areas_authenticated_read on public.areas as permissive for select to authenticated using (is_active);

create policy master_data_manage_areas on public.areas as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy schools_public_read on public.schools as permissive for select to anon, authenticated using (is_active);

create policy master_data_manage_schools on public.schools as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy lead_sources_public_read on public.lead_sources as permissive for select to anon, authenticated using (is_active);

create policy master_data_manage_lead_sources on public.lead_sources as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy payment_methods_authenticated_read on public.payment_methods as permissive for select to authenticated using (is_active);

create policy master_data_manage_payment_methods on public.payment_methods as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy guardian_relationships_authenticated_read on public.guardian_relationships as permissive for select to authenticated using (is_active);

create policy master_data_manage_guardian_relationships on public.guardian_relationships as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy guardian_relationships_public_read on public.guardian_relationships as permissive for select to anon using (is_active);

create policy staff_permission_read on public.staff as permissive for select to authenticated using ((has_permission('staff.view'::text) OR (profile_id = auth.uid())));

create policy staff_permission_insert on public.staff as permissive for insert to authenticated with check (has_permission('staff.manage'::text));

create policy staff_permission_update on public.staff as permissive for update to authenticated using (has_permission('staff.manage'::text)) with check (has_permission('staff.manage'::text));

create policy profiles_read on public.profiles as permissive for select to authenticated using (((id = auth.uid()) OR has_permission('system.users.manage'::text) OR has_permission('staff.view'::text)));

create policy student_guardians_view on public.student_guardians as permissive for select to authenticated using (has_permission('students.view'::text));

create policy student_guardians_manage on public.student_guardians as permissive for all to authenticated using (has_permission('students.manage'::text)) with check (has_permission('students.manage'::text));

create policy prospect_program_interests_view on public.prospect_program_interests as permissive for select to authenticated using (has_permission('crm.prospects.view'::text));

create policy prospect_program_interests_manage on public.prospect_program_interests as permissive for all to authenticated using (has_permission('crm.prospects.manage'::text)) with check (has_permission('crm.prospects.manage'::text));

create policy prospect_subject_interests_view on public.prospect_subject_interests as permissive for select to authenticated using (has_permission('crm.prospects.view'::text));

create policy prospect_subject_interests_manage on public.prospect_subject_interests as permissive for all to authenticated using (has_permission('crm.prospects.manage'::text)) with check (has_permission('crm.prospects.manage'::text));

create policy staff_subjects_read on public.staff_subject_assignments as permissive for select to authenticated using (has_permission('staff.view'::text));

create policy staff_subjects_manage_insert on public.staff_subject_assignments as permissive for insert to authenticated with check (has_permission('staff.manage'::text));

create policy staff_subjects_manage_update on public.staff_subject_assignments as permissive for update to authenticated using (has_permission('staff.manage'::text)) with check (has_permission('staff.manage'::text));

create policy prospect_followups_view on public.prospect_followups as permissive for select to authenticated using (has_permission('crm.prospects.view'::text));

create policy prospect_followups_manage on public.prospect_followups as permissive for all to authenticated using (has_permission('crm.followups.manage'::text)) with check ((has_permission('crm.followups.manage'::text) AND (recorded_by = auth.uid())));

create policy prospects_view on public.prospects as permissive for select to authenticated using (has_permission('crm.prospects.view'::text));

create policy prospects_manage_insert on public.prospects as permissive for insert to authenticated with check (has_permission('crm.prospects.manage'::text));

create policy prospects_manage_update on public.prospects as permissive for update to authenticated using (has_permission('crm.prospects.manage'::text)) with check (has_permission('crm.prospects.manage'::text));

create policy students_manage_insert on public.students as permissive for insert to authenticated with check (has_permission('students.manage'::text));

create policy students_view on public.students as permissive for select to authenticated using (has_permission('students.view'::text));

create policy students_manage_update on public.students as permissive for update to authenticated using (has_permission('students.manage'::text)) with check (has_permission('students.manage'::text));

create policy guardians_view on public.guardians as permissive for select to authenticated using (has_permission('students.view'::text));

create policy guardians_manage on public.guardians as permissive for all to authenticated using (has_permission('students.manage'::text)) with check (has_permission('students.manage'::text));

create policy system_roles_read on public.system_roles as permissive for select to authenticated using (true);

create policy permissions_read on public.permissions as permissive for select to authenticated using (true);

create policy role_permissions_read on public.role_permissions as permissive for select to authenticated using ((has_permission('system.roles.manage'::text) OR has_permission('system.users.manage'::text)));

create policy business_rules_read on public.business_rule_versions as permissive for select to authenticated using ((has_permission('system.rules.view'::text) OR (status = 'ACTIVE'::rule_status)));

create policy user_roles_admin_read on public.user_role_assignments as permissive for select to authenticated using (((profile_id = auth.uid()) OR has_permission('system.users.manage'::text)));

create policy user_roles_admin_write on public.user_role_assignments as permissive for insert to authenticated with check (has_permission('system.users.manage'::text));

create policy user_roles_admin_update on public.user_role_assignments as permissive for update to authenticated using (has_permission('system.users.manage'::text)) with check (has_permission('system.users.manage'::text));

create policy academic_groups_read on public.academic_groups as permissive for select to authenticated using ((has_permission('academics.view'::text) OR has_permission('admissions.view'::text)));

create policy master_data_manage_academic_groups on public.academic_groups as permissive for all to authenticated using (has_permission('system.master_data.manage'::text)) with check (has_permission('system.master_data.manage'::text));

create policy programme_offerings_read on public.programme_offerings as permissive for select to authenticated using ((has_permission('academics.view'::text) OR has_permission('admissions.view'::text) OR has_permission('finance.view'::text)));

create policy fee_plan_versions_read on public.fee_plan_versions as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('finance.billing.manage'::text) OR has_permission('admissions.view'::text)));

create policy fee_plan_components_read on public.fee_plan_components as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('finance.billing.manage'::text) OR has_permission('admissions.view'::text)));

create policy batches_view on public.batches as permissive for select to authenticated using ((has_permission('academics.view'::text) OR has_permission('admissions.view'::text)));

create policy batches_manage on public.batches as permissive for all to authenticated using (has_permission('academics.manage'::text)) with check (has_permission('academics.manage'::text));

create policy enrollments_view on public.enrollments as permissive for select to authenticated using ((has_permission('students.view'::text) OR has_permission('admissions.view'::text)));

create policy enrollments_manage on public.enrollments as permissive for all to authenticated using ((has_permission('students.manage'::text) OR has_permission('admissions.create'::text))) with check ((has_permission('students.manage'::text) OR has_permission('admissions.create'::text)));

create policy admission_lines_read on public.admission_invoice_lines as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text)));

create policy admission_payment_read on public.admission_payments as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text)));

create policy admission_allocation_read on public.admission_payment_allocations as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text)));

create policy admission_invoices_read on public.admission_invoices as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text)));

create policy admission_cases_read on public.admission_cases as permissive for select to authenticated using (has_permission('admissions.view'::text));

create policy finance_read on public.invoice_credits as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy finance_read on public.billing_terms as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy finance_read on public.admission_discounts as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy finance_read on public.refund_authorizations as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy finance_read on public.refund_payouts as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy finance_read on public.billing_runs as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy approvals_permission_read on public.approval_requests as permissive for select to authenticated using ((has_permission('approvals.view'::text) OR (requested_by = auth.uid())));

create policy approvals_submit on public.approval_requests as permissive for insert to authenticated with check ((requested_by = auth.uid()));

create policy approvals_decide on public.approval_requests as permissive for update to authenticated using (has_permission('approvals.decide'::text)) with check (has_permission('approvals.decide'::text));

create policy finance_read on public.admission_cancellations as permissive for select to authenticated using (has_permission('finance.view'::text));

create policy lifecycle_read on public.student_merges as permissive for select to authenticated using (has_permission('students.view'::text));

create policy lifecycle_read on public.enrollment_transfers as permissive for select to authenticated using (has_permission('students.view'::text));

create policy academic_room_read on public.academic_rooms as permissive for select to authenticated using (has_permission('academics.view'::text));

create policy attendance_read on public.attendance_submissions as permissive for select to authenticated using (can_access_class_session(session_id));

create policy curriculum_read on public.curriculum_versions as permissive for select to authenticated using ((has_permission('academics.curriculum.manage'::text) OR has_permission('academics.sessions.manage'::text) OR (EXISTS ( SELECT 1
   FROM class_sessions s
  WHERE ((s.curriculum_version_id = curriculum_versions.id) AND can_access_class_session(s.id))))));

create policy routine_read on public.academic_routines as permissive for select to authenticated using ((has_permission('academics.sessions.manage'::text) OR (EXISTS ( SELECT 1
   FROM staff
  WHERE ((staff.id = academic_routines.teacher_id) AND (staff.profile_id = auth.uid()))))));

create policy session_read on public.class_sessions as permissive for select to authenticated using (can_access_class_session(id));

create policy offering_subjects_read on public.programme_offering_subjects as permissive for select to anon, authenticated using ((EXISTS ( SELECT 1
   FROM programme_offerings o
  WHERE ((o.id = programme_offering_subjects.offering_id) AND (o.is_website_visible OR has_permission('academics.view'::text) OR has_permission('admissions.view'::text))))));

create policy finance_accounts_read on public.finance_accounts as permissive for select to authenticated using ((has_permission('accounting.view'::text) OR has_permission('finance.view'::text)));

create policy finance_cost_centres_read on public.finance_cost_centres as permissive for select to authenticated using ((has_permission('accounting.view'::text) OR has_permission('finance.view'::text)));

create policy ledger_read on public.general_ledger_journals as permissive for select to authenticated using (has_permission('accounting.view'::text));

create policy ledger_lines_read on public.general_ledger_lines as permissive for select to authenticated using (has_permission('accounting.view'::text));

create policy vendors_read on public.vendors as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy payment_map_read on public.finance_payment_account_map as permissive for select to authenticated using (has_permission('accounting.view'::text));

create policy fee_map_read on public.finance_fee_revenue_map as permissive for select to authenticated using (has_permission('accounting.view'::text));

create policy expense_categories_read on public.finance_expense_categories as permissive for select to authenticated using ((has_permission('accounting.view'::text) OR has_permission('accounting.expense.manage'::text)));

create policy expense_reconciliation_read on public.finance_expense_reconciliations as permissive for select to authenticated using (has_permission('accounting.reconcile'::text));

create policy account_reconciliation_read on public.finance_account_reconciliations as permissive for select to authenticated using (has_permission('accounting.reconcile'::text));

create policy teacher_referrals_read on public.teacher_referrals as permissive for select to authenticated using ((has_permission('staff.compensation.view'::text) OR has_permission('admissions.view'::text)));

create policy compensation_events_read on public.teacher_compensation_events as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy compensation_settlements_read on public.teacher_compensation_settlements as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy compensation_lines_read on public.teacher_compensation_lines as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy advances_read on public.finance_advances as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('finance.advances.manage'::text)));

create policy expenses_read on public.finance_expenses as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('accounting.expense.manage'::text)));

create policy compensation_runs_read on public.teacher_compensation_runs as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy compensation_adjustments_read on public.teacher_compensation_adjustments as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy teacher_compensation_claims_read on public.teacher_compensation_claims as permissive for select to authenticated using (has_permission('staff.compensation.view'::text));

create policy advance_movements_read on public.finance_advance_movements as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('finance.advances.manage'::text)));

create policy payable_settlements_read on public.finance_payable_settlements as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy payables_read on public.finance_payables as permissive for select to authenticated using ((has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy referral_people_read on public.referral_people as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy admission_referrals_read on public.admission_referrals as permissive for select to authenticated using ((has_permission('admissions.view'::text) OR has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy referral_bonus_awards_read on public.referral_bonus_awards as permissive for select to authenticated using ((has_permission('staff.compensation.view'::text) OR has_permission('finance.view'::text) OR has_permission('accounting.view'::text)));

create policy staff_requests_read on public.staff_access_requests as permissive for select to authenticated using (has_permission('system.users.manage'::text));

create policy admission_physical_consent_staff_read on public.admission_physical_consent_receipts as permissive for select to authenticated using (has_permission('admissions.view'::text));

grant select on public.organizations to authenticated;

grant select on public.branches to authenticated;

grant select on public.staff_roles to authenticated;

grant select on public.audit_events to authenticated;

grant select on public.staff_role_assignments to authenticated;

grant select on public.academic_years to authenticated;

grant select on public.classes to anon;

grant select on public.classes to authenticated;

grant select on public.programs to anon;

grant select on public.programs to authenticated;

grant select on public.subjects to anon;

grant select on public.subjects to authenticated;

grant select on public.areas to authenticated;

grant select on public.schools to anon;

grant select on public.schools to authenticated;

grant select on public.lead_sources to anon;

grant select on public.lead_sources to authenticated;

grant select on public.payment_methods to authenticated;

grant select on public.guardian_relationships to authenticated;

grant select on public.guardian_relationships to anon;

grant select on public.staff to authenticated;

grant select on public.profiles to authenticated;

grant select on public.student_guardians to authenticated;

grant select on public.prospect_program_interests to authenticated;

grant select on public.prospect_subject_interests to authenticated;

grant select on public.staff_subject_assignments to authenticated;

grant select on public.prospect_followups to authenticated;

grant select on public.prospects to authenticated;

grant select on public.students to authenticated;

grant select on public.guardians to authenticated;

grant select on public.system_roles to authenticated;

grant select on public.permissions to authenticated;

grant select on public.role_permissions to authenticated;

grant select on public.business_rule_versions to authenticated;

grant select on public.user_role_assignments to authenticated;

grant select on public.academic_groups to authenticated;

grant select on public.programme_offerings to authenticated;

grant select on public.fee_plan_versions to authenticated;

grant select on public.fee_plan_components to authenticated;

grant select on public.batches to authenticated;

grant select on public.enrollments to authenticated;

grant select on public.admission_invoice_lines to authenticated;

grant select on public.admission_payments to authenticated;

grant select on public.admission_payment_allocations to authenticated;

grant select on public.admission_invoices to authenticated;

grant select on public.admission_cases to authenticated;

grant select on public.invoice_credits to authenticated;

grant select on public.billing_terms to authenticated;

grant select on public.admission_discounts to authenticated;

grant select on public.refund_authorizations to authenticated;

grant select on public.refund_payouts to authenticated;

grant select on public.billing_runs to authenticated;

grant select on public.approval_requests to authenticated;

grant select on public.admission_cancellations to authenticated;

grant select on public.student_merges to authenticated;

grant select on public.enrollment_transfers to authenticated;

grant select on public.academic_rooms to authenticated;

grant select on public.attendance_submissions to authenticated;

grant select on public.curriculum_versions to authenticated;

grant select on public.academic_routines to authenticated;

grant select on public.class_sessions to authenticated;

grant select on public.programme_offering_subjects to authenticated;

grant select on public.programme_offering_subjects to anon;

grant select on public.finance_accounts to authenticated;

grant select on public.finance_cost_centres to authenticated;

grant select on public.general_ledger_journals to authenticated;

grant select on public.general_ledger_lines to authenticated;

grant select on public.vendors to authenticated;

grant select on public.finance_payment_account_map to authenticated;

grant select on public.finance_fee_revenue_map to authenticated;

grant select on public.finance_expense_categories to authenticated;

grant select on public.finance_expense_reconciliations to authenticated;

grant select on public.finance_account_reconciliations to authenticated;

grant select on public.teacher_referrals to authenticated;

grant select on public.teacher_compensation_events to authenticated;

grant select on public.teacher_compensation_settlements to authenticated;

grant select on public.teacher_compensation_lines to authenticated;

grant select on public.finance_advances to authenticated;

grant select on public.finance_expenses to authenticated;

grant select on public.teacher_compensation_runs to authenticated;

grant select on public.teacher_compensation_adjustments to authenticated;

grant select on public.teacher_compensation_claims to authenticated;

grant select on public.finance_advance_movements to authenticated;

grant select on public.finance_payable_settlements to authenticated;

grant select on public.finance_payables to authenticated;

grant select on public.referral_people to authenticated;

grant select on public.admission_referrals to authenticated;

grant select on public.referral_bonus_awards to authenticated;

grant select on public.staff_access_requests to authenticated;

grant select on public.admission_physical_consent_receipts to authenticated;

grant select on public.current_fee_plans to authenticated;

grant select on public.current_fee_plan_components to authenticated;

grant select on public.current_operating_rules to authenticated;

grant execute on function public.academic_command(p_input jsonb) to authenticated;

grant execute on function public.academic_workspace(p_from date, p_to date) to authenticated;

grant execute on function public.academy_setup_status() to authenticated;

grant execute on function public.admin_review_queue() to authenticated;

grant execute on function public.admission_case_detail(p_admission_id uuid) to authenticated;

grant execute on function public.admission_command(p_input jsonb) to authenticated;

grant execute on function public.admission_directory_options() to authenticated;

grant execute on function public.admission_discount_options(p_admission_id uuid) to authenticated;

grant execute on function public.admission_offering_options() to authenticated;

grant execute on function public.admission_review_checks(p_admission_id uuid) to authenticated;

grant execute on function public.admission_workspace() to authenticated;

grant execute on function public.assessment_command(p_input jsonb) to authenticated;

grant execute on function public.assessment_workspace() to authenticated;

grant execute on function public.assign_prospect_staff(p_input jsonb) to authenticated;

grant execute on function public.attendance_command(p_input jsonb) to authenticated;

grant execute on function public.audit_event_list(p_correlation uuid) to authenticated;

grant execute on function public.batch_command(p_input jsonb) to authenticated;

grant execute on function public.billing_preview(p_period date, p_term_id uuid) to authenticated;

grant execute on function public.can_access_assessment(p_batch uuid, p_subject uuid) to authenticated;

grant execute on function public.can_access_class_session(p_session uuid) to authenticated;

grant execute on function public.class_log_command(p_input jsonb) to authenticated;

grant execute on function public.class_log_workspace(p_session_id uuid) to authenticated;

grant execute on function public.class_session_workspace(p_session_id uuid) to authenticated;

grant execute on function public.close_student_enrollment(p_input jsonb) to authenticated;

grant execute on function public.complete_academy_setup() to authenticated;

grant execute on function public.correct_admission_placement(p_input jsonb) to authenticated;

grant execute on function public.create_admission_directory_choice(p_input jsonb) to authenticated;

grant execute on function public.create_programme_offering(p_input jsonb) to authenticated;

grant execute on function public.create_prospect_admission(p_input jsonb) to authenticated;

grant execute on function public.create_staff_admission_intake(p_input jsonb) to authenticated;

grant execute on function public.create_staff_member(p_input jsonb) to authenticated;

grant execute on function public.deactivate_admission_extra_charge(p_admission_id uuid, p_charge_id uuid) to authenticated;

grant execute on function public.edit_admission_identity(p_input jsonb) to authenticated;

grant execute on function public.edit_staff_record(p_input jsonb) to authenticated;

grant execute on function public.finance_accounting_command(p_input jsonb) to authenticated;

grant execute on function public.finance_command(p_input jsonb) to authenticated;

grant execute on function public.finance_read_account_balance(p_account_id uuid, p_as_of date) to authenticated;

grant execute on function public.finance_workspace() to authenticated;

grant execute on function public.has_permission(p_permission_code text) to authenticated;

grant execute on function public.homework_command(p_input jsonb) to authenticated;

grant execute on function public.homework_workspace(p_session_id uuid) to authenticated;

grant execute on function public.is_valid_prospect_transition(p_from prospect_status, p_to prospect_status) to authenticated;

grant execute on function public.list_public_programme_offerings() to anon;

grant execute on function public.list_public_programme_offerings() to authenticated;

grant execute on function public.manage_crm_master_record(p_input jsonb) to authenticated;

grant execute on function public.my_erp_context() to authenticated;

grant execute on function public.post_admission_payment(p_input jsonb) to authenticated;

grant execute on function public.prospect_assignment_options() to authenticated;

grant execute on function public.publish_business_rule_version(p_domain text, p_rule_key text, p_payload jsonb, p_reason text) to authenticated;

grant execute on function public.question_bank_command(p_input jsonb) to authenticated;

grant execute on function public.question_bank_workspace() to authenticated;

grant execute on function public.record_lifecycle_command(p_input jsonb) to authenticated;

grant execute on function public.record_physical_admission_consent(p_input jsonb) to authenticated;

grant execute on function public.record_prospect_followup(p_input jsonb) to authenticated;

grant execute on function public.referral_command(p_input jsonb) to authenticated;

grant execute on function public.request_staff_access(p_input jsonb) to anon;

grant execute on function public.request_staff_access(p_input jsonb) to authenticated;

grant execute on function public.review_staff_access(p_input jsonb) to authenticated;

grant execute on function public.save_academy_identity(p_input jsonb) to authenticated;

grant execute on function public.save_admission_extra_charge(p_input jsonb) to authenticated;

grant execute on function public.save_fee_plan(p_input jsonb) to authenticated;

grant execute on function public.save_offering_discount_policy(p_input jsonb) to authenticated;

grant execute on function public.set_role_permissions(p_role_code text, p_permission_codes text[], p_reason text) to authenticated;

grant execute on function public.set_user_operational_roles(p_profile_id uuid, p_role_codes text[], p_reason text, p_branch_id uuid) to authenticated;

grant execute on function public.student_command(p_input jsonb) to authenticated;

grant execute on function public.student_profile_workspace(p_student_id uuid) to authenticated;

grant execute on function public.submit_public_interest(p_payload jsonb) to anon;

grant execute on function public.submit_public_interest(p_payload jsonb) to authenticated;

grant execute on function public.teacher_compensation_preview(p_from date, p_to date) to authenticated;

grant execute on function public.update_programme_offering(p_input jsonb) to authenticated;

grant execute on function public.update_programme_offering_public_controls(p_input jsonb) to authenticated;

grant execute on function public.validate_business_rule_payload(p_domain text, p_rule_key text, p_payload jsonb) to authenticated;

grant execute on function public.has_permission(text) to anon;

CREATE TRIGGER organizations_set_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER branches_set_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER profiles_set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER staff_set_updated_at BEFORE UPDATE ON staff FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER schools_set_updated_at BEFORE UPDATE ON schools FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();

CREATE TRIGGER approval_requests_decision_guard BEFORE UPDATE OF status ON approval_requests FOR EACH ROW EXECUTE FUNCTION enforce_approval_decision();

CREATE TRIGGER business_rule_version_guard BEFORE DELETE OR UPDATE ON business_rule_versions FOR EACH ROW EXECUTE FUNCTION protect_active_business_rule();

CREATE TRIGGER prospects_set_updated_at BEFORE UPDATE ON prospects FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER students_set_updated_at BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER guardians_set_updated_at BEFORE UPDATE ON guardians FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER batches_set_updated_at BEFORE UPDATE ON batches FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER enrollments_set_updated_at BEFORE UPDATE ON enrollments FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER batches_capacity_policy BEFORE INSERT OR UPDATE OF capacity ON batches FOR EACH ROW EXECUTE FUNCTION enforce_batch_policy();

CREATE TRIGGER enrollments_batch_integrity BEFORE INSERT OR UPDATE OF batch_id, status, academic_year_id, class_id, program_id ON enrollments FOR EACH ROW EXECUTE FUNCTION enforce_enrollment_batch_integrity();

CREATE TRIGGER staff_subject_requires_teaching_role BEFORE INSERT OR UPDATE OF staff_id, subject_id, effective_to ON staff_subject_assignments FOR EACH ROW EXECUTE FUNCTION enforce_staff_subject_teaching_role();

CREATE TRIGGER programme_offerings_set_updated_at BEFORE UPDATE ON programme_offerings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER fee_plan_version_history_guard BEFORE DELETE OR UPDATE ON fee_plan_versions FOR EACH ROW EXECUTE FUNCTION guard_fee_plan_history();

CREATE TRIGGER fee_plan_component_history_guard BEFORE INSERT OR DELETE OR UPDATE ON fee_plan_components FOR EACH ROW EXECUTE FUNCTION guard_fee_plan_history();

CREATE TRIGGER admission_updated BEFORE UPDATE ON admission_cases FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER admission_invoice_immutable BEFORE DELETE OR UPDATE ON admission_invoices FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER admission_lines_immutable BEFORE DELETE OR UPDATE ON admission_invoice_lines FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER admission_payment_immutable BEFORE DELETE OR UPDATE ON admission_payments FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER admission_allocation_immutable BEFORE DELETE OR UPDATE ON admission_payment_allocations FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON billing_terms FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON admission_discounts FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON invoice_credits FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON refund_authorizations FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON refund_payouts FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON admission_cancellations FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER immutable_finance_history BEFORE DELETE OR UPDATE ON billing_runs FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER lifecycle_immutable BEFORE DELETE OR UPDATE ON student_merges FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER lifecycle_immutable BEFORE DELETE OR UPDATE ON enrollment_transfers FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER academic_immutable BEFORE DELETE OR UPDATE ON academic_rooms FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER academic_immutable BEFORE DELETE OR UPDATE ON curriculum_versions FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER academic_immutable BEFORE DELETE OR UPDATE ON academic_routines FOR EACH ROW EXECUTE FUNCTION protect_academic_record();

CREATE TRIGGER academic_immutable BEFORE DELETE OR UPDATE ON class_sessions FOR EACH ROW EXECUTE FUNCTION protect_academic_record();

CREATE TRIGGER academic_immutable BEFORE DELETE OR UPDATE ON attendance_submissions FOR EACH ROW EXECUTE FUNCTION protect_academic_record();

CREATE TRIGGER class_log_history_guard BEFORE DELETE OR UPDATE ON class_logs FOR EACH ROW EXECUTE FUNCTION guard_submitted_class_log();

CREATE TRIGGER staff_link_profile AFTER INSERT OR UPDATE OF email, status ON staff FOR EACH ROW WHEN (new.profile_id IS NULL AND new.email IS NOT NULL) EXECUTE FUNCTION staff_link_profile_trigger();

CREATE TRIGGER on_auth_user_link_staff AFTER INSERT OR UPDATE OF email, email_confirmed_at ON auth.users FOR EACH ROW EXECUTE FUNCTION auth_user_link_staff_trigger();

CREATE CONSTRAINT TRIGGER journal_must_balance AFTER INSERT OR DELETE OR UPDATE ON general_ledger_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assert_journal_balanced();

CREATE TRIGGER vendors_set_updated_at BEFORE UPDATE ON vendors FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER admission_invoice_lines_to_ledger AFTER INSERT ON admission_invoice_lines REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION finance_sync_invoice_line_statement();

CREATE TRIGGER invoice_credits_to_ledger AFTER INSERT ON invoice_credits FOR EACH ROW EXECUTE FUNCTION finance_sync_invoice_credit_trigger();

CREATE TRIGGER admission_payment_allocations_to_ledger AFTER INSERT ON admission_payment_allocations FOR EACH ROW EXECUTE FUNCTION finance_sync_payment_trigger();

CREATE TRIGGER refund_payouts_to_ledger AFTER INSERT ON refund_payouts FOR EACH ROW EXECUTE FUNCTION finance_sync_refund_trigger();

CREATE TRIGGER immutable_compensation_claim BEFORE DELETE OR UPDATE ON teacher_compensation_claims FOR EACH ROW EXECUTE FUNCTION protect_admission_invoice();

CREATE TRIGGER admission_referral_choice_gate BEFORE UPDATE OF status ON admission_cases FOR EACH ROW EXECUTE FUNCTION require_admission_referral_choice();

CREATE TRIGGER teacher_referral_match BEFORE INSERT OR UPDATE ON teacher_referrals FOR EACH ROW EXECUTE FUNCTION teacher_referral_matches_admission();

CREATE TRIGGER admission_student_details_sync AFTER UPDATE OF student_id ON admission_cases FOR EACH ROW EXECUTE FUNCTION sync_admission_student_details();

CREATE TRIGGER admission_workflow_evidence_gate BEFORE UPDATE OF status ON admission_cases FOR EACH ROW EXECUTE FUNCTION require_admission_workflow_evidence();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON organizations FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON branches FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON profiles FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON staff FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON schools FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON academic_years FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON classes FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON academic_groups FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON subjects FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON programs FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON students FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON guardians FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON prospects FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON batches FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON enrollments FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON admission_cases FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON admission_invoices FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON admission_invoice_lines FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON admission_payments FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON invoice_credits FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON admission_physical_consent_receipts FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER preserve_permanent_record BEFORE DELETE ON staff_access_requests FOR EACH ROW EXECUTE FUNCTION prevent_permanent_record_delete();

CREATE TRIGGER capture_audit_identity BEFORE INSERT ON audit_events FOR EACH ROW EXECUTE FUNCTION capture_audit_actor();
