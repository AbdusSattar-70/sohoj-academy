-- Sohoj Academy fresh database baseline: constraints indexes.
-- Install on an empty application schema. Each object is defined once.

alter table public.organizations add constraint organizations_pkey PRIMARY KEY (id);

alter table public.organizations add constraint organizations_code_key UNIQUE (code);

alter table public.branches add constraint branches_pkey PRIMARY KEY (id);

alter table public.branches add constraint branches_organization_id_code_key UNIQUE (organization_id, code);

alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);

alter table public.system_roles add constraint system_roles_pkey PRIMARY KEY (id);

alter table public.system_roles add constraint system_roles_code_key UNIQUE (code);

alter table public.permissions add constraint permissions_pkey PRIMARY KEY (id);

alter table public.permissions add constraint permissions_code_key UNIQUE (code);

alter table public.role_permissions add constraint role_permissions_pkey PRIMARY KEY (role_id, permission_id);

alter table public.user_role_assignments add constraint user_role_assignments_check CHECK (effective_to IS NULL OR effective_to >= effective_from);

alter table public.user_role_assignments add constraint user_role_assignments_pkey PRIMARY KEY (id);

alter table public.staff add constraint staff_check CHECK (left_on IS NULL OR joined_on IS NULL OR left_on >= joined_on);

alter table public.staff add constraint staff_pkey PRIMARY KEY (id);

alter table public.staff add constraint staff_staff_no_key UNIQUE (staff_no);

alter table public.staff add constraint staff_profile_id_key UNIQUE (profile_id);

alter table public.staff_roles add constraint staff_roles_pkey PRIMARY KEY (id);

alter table public.staff_roles add constraint staff_roles_code_key UNIQUE (code);

alter table public.staff_role_assignments add constraint staff_role_assignments_check CHECK (effective_to IS NULL OR effective_to >= effective_from);

alter table public.staff_role_assignments add constraint staff_role_assignments_pkey PRIMARY KEY (id);

alter table public.audit_events add constraint audit_events_pkey PRIMARY KEY (id);

alter table public.approval_requests add constraint approval_requests_check CHECK (status = 'PENDING'::approval_status AND decided_by IS NULL AND decided_at IS NULL OR status <> 'PENDING'::approval_status);

alter table public.approval_requests add constraint approval_requests_pkey PRIMARY KEY (id);

alter table public.business_rule_versions add constraint business_rule_versions_check CHECK (effective_to IS NULL OR effective_to >= effective_from);

alter table public.business_rule_versions add constraint business_rule_versions_pkey PRIMARY KEY (id);

alter table public.business_rule_versions add constraint business_rule_versions_domain_rule_key_version_key UNIQUE (domain, rule_key, version);

alter table public.academic_years add constraint academic_years_check CHECK (ends_on >= starts_on);

alter table public.academic_years add constraint academic_years_pkey PRIMARY KEY (id);

alter table public.academic_years add constraint academic_years_organization_id_name_key UNIQUE (organization_id, name);

alter table public.classes add constraint classes_pkey PRIMARY KEY (id);

alter table public.classes add constraint classes_organization_id_code_key UNIQUE (organization_id, code);

alter table public.programs add constraint programs_pkey PRIMARY KEY (id);

alter table public.programs add constraint programs_organization_id_code_key UNIQUE (organization_id, code);

alter table public.subjects add constraint subjects_pkey PRIMARY KEY (id);

alter table public.subjects add constraint subjects_organization_id_code_key UNIQUE (organization_id, code);

alter table public.areas add constraint areas_pkey PRIMARY KEY (id);

alter table public.schools add constraint schools_pkey PRIMARY KEY (id);

alter table public.lead_sources add constraint lead_sources_pkey PRIMARY KEY (id);

alter table public.lead_sources add constraint lead_sources_organization_id_code_key UNIQUE (organization_id, code);

alter table public.guardian_relationships add constraint guardian_relationships_pkey PRIMARY KEY (id);

alter table public.guardian_relationships add constraint guardian_relationships_organization_id_code_key UNIQUE (organization_id, code);

alter table public.payment_methods add constraint payment_methods_pkey PRIMARY KEY (id);

alter table public.payment_methods add constraint payment_methods_organization_id_code_key UNIQUE (organization_id, code);

alter table public.prospects add constraint prospects_pkey PRIMARY KEY (id);

alter table public.prospects add constraint prospects_prospect_no_key UNIQUE (prospect_no);

alter table public.prospect_program_interests add constraint prospect_program_interests_pkey PRIMARY KEY (prospect_id, program_id);

alter table public.prospect_subject_interests add constraint prospect_subject_interests_pkey PRIMARY KEY (prospect_id, subject_id);

alter table public.prospect_followups add constraint prospect_followups_pkey PRIMARY KEY (id);

alter table public.students add constraint students_pkey PRIMARY KEY (id);

alter table public.students add constraint students_student_no_key UNIQUE (student_no);

alter table public.students add constraint students_created_from_prospect_id_key UNIQUE (created_from_prospect_id);

alter table public.guardians add constraint guardians_pkey PRIMARY KEY (id);

alter table public.student_guardians add constraint student_guardians_pkey PRIMARY KEY (id);

alter table public.student_guardians add constraint student_guardians_student_id_guardian_id_key UNIQUE (student_id, guardian_id);

alter table public.batches add constraint batches_capacity_check CHECK (capacity > 0);

alter table public.batches add constraint batches_pkey PRIMARY KEY (id);

alter table public.batches add constraint batches_organization_id_academic_year_id_code_key UNIQUE (organization_id, academic_year_id, code);

alter table public.enrollments add constraint enrollments_check CHECK (ended_on IS NULL OR ended_on >= admission_date);

alter table public.enrollments add constraint enrollments_pkey PRIMARY KEY (id);

alter table public.staff_subject_assignments add constraint staff_subject_assignments_check CHECK (effective_to IS NULL OR effective_to >= effective_from);

alter table public.staff_subject_assignments add constraint staff_subject_assignments_pkey PRIMARY KEY (id);

alter table public.prospect_followups add constraint prospect_followup_type_check CHECK (followup_type = ANY (ARRAY['CALL'::text, 'WHATSAPP'::text, 'IN_PERSON'::text, 'COUNSELLING'::text, 'TRIAL'::text, 'OTHER'::text]));

alter table public.academic_groups add constraint academic_groups_pkey PRIMARY KEY (id);

alter table public.academic_groups add constraint academic_groups_organization_id_code_key UNIQUE (organization_id, code);

alter table public.programme_offerings add constraint programme_offerings_code_check CHECK (length(btrim(code)) >= 2 AND length(btrim(code)) <= 40);

alter table public.programme_offerings add constraint programme_offerings_name_check CHECK (length(btrim(name)) >= 2 AND length(btrim(name)) <= 160);

alter table public.programme_offerings add constraint programme_offerings_pkey PRIMARY KEY (id);

alter table public.programme_offerings add constraint programme_offerings_organization_id_academic_year_id_code_key UNIQUE (organization_id, academic_year_id, code);

alter table public.fee_plan_versions add constraint fee_plan_versions_version_check CHECK (version > 0);

alter table public.fee_plan_versions add constraint fee_plan_versions_billing_cycle_check CHECK (billing_cycle = ANY (ARRAY['ONE_TIME'::text, 'MONTHLY'::text, 'TERM'::text]));

alter table public.fee_plan_versions add constraint fee_plan_versions_due_day_check CHECK (due_day >= 1 AND due_day <= 28);

alter table public.fee_plan_versions add constraint fee_plan_versions_currency_code_check CHECK (currency_code ~ '^[A-Z]{3}$'::text);

alter table public.fee_plan_versions add constraint fee_plan_versions_change_reason_check CHECK (length(btrim(change_reason)) >= 5);

alter table public.fee_plan_versions add constraint fee_plan_versions_check CHECK (effective_to IS NULL OR effective_to >= effective_from);

alter table public.fee_plan_versions add constraint fee_plan_versions_check1 CHECK (billing_cycle = 'MONTHLY'::text AND due_day IS NOT NULL OR billing_cycle <> 'MONTHLY'::text AND due_day IS NULL);

alter table public.fee_plan_versions add constraint fee_plan_versions_pkey PRIMARY KEY (id);

alter table public.fee_plan_versions add constraint fee_plan_versions_offering_id_version_key UNIQUE (offering_id, version);

alter table public.fee_plan_components add constraint fee_plan_components_code_check CHECK (code ~ '^[A-Z][A-Z0-9_]{1,39}$'::text);

alter table public.fee_plan_components add constraint fee_plan_components_name_check CHECK (length(btrim(name)) >= 2 AND length(btrim(name)) <= 100);

alter table public.fee_plan_components add constraint fee_plan_components_amount_check CHECK (amount >= 0::numeric);

alter table public.fee_plan_components add constraint fee_plan_components_charge_type_check CHECK (charge_type = ANY (ARRAY['TUITION'::text, 'ADMISSION'::text, 'EXAM'::text, 'MATERIAL'::text, 'OTHER'::text]));

alter table public.fee_plan_components add constraint fee_plan_components_recurrence_check CHECK (recurrence = ANY (ARRAY['PER_CYCLE'::text, 'ONE_TIME'::text]));

alter table public.fee_plan_components add constraint fee_plan_components_pkey PRIMARY KEY (id);

alter table public.fee_plan_components add constraint fee_plan_components_fee_plan_version_id_code_key UNIQUE (fee_plan_version_id, code);

alter table public.admission_cases add constraint admission_cases_pkey PRIMARY KEY (id);

alter table public.admission_cases add constraint admission_cases_admission_no_key UNIQUE (admission_no);

alter table public.admission_cases add constraint admission_cases_enrollment_id_key UNIQUE (enrollment_id);

alter table public.admission_invoices add constraint admission_invoices_total_check CHECK (total >= 0::numeric);

alter table public.admission_invoices add constraint admission_invoices_pkey PRIMARY KEY (id);

alter table public.admission_invoices add constraint admission_invoices_invoice_no_key UNIQUE (invoice_no);

alter table public.admission_invoice_lines add constraint admission_invoice_lines_amount_check CHECK (amount >= 0::numeric);

alter table public.admission_invoice_lines add constraint admission_invoice_lines_pkey PRIMARY KEY (id);

alter table public.admission_invoice_lines add constraint admission_invoice_lines_invoice_id_fee_component_id_key UNIQUE (invoice_id, fee_component_id);

alter table public.admission_command_keys add constraint admission_command_keys_pkey PRIMARY KEY (request_id);

alter table public.admission_payments add constraint admission_payments_amount_check CHECK (amount > 0::numeric);

alter table public.admission_payments add constraint admission_payments_pkey PRIMARY KEY (id);

alter table public.admission_payments add constraint admission_payments_receipt_no_key UNIQUE (receipt_no);

alter table public.admission_payment_allocations add constraint admission_payment_allocations_amount_check CHECK (amount > 0::numeric);

alter table public.admission_payment_allocations add constraint admission_payment_allocations_pkey PRIMARY KEY (payment_id);

alter table public.admission_invoices add constraint admission_invoices_invoice_kind_check CHECK (invoice_kind = ANY (ARRAY['INITIAL'::text, 'RECURRING'::text]));

alter table public.billing_terms add constraint billing_terms_name_check CHECK (length(btrim(name)) >= 2);

alter table public.billing_terms add constraint billing_terms_check CHECK (ends_on >= starts_on);

alter table public.billing_terms add constraint billing_terms_check1 CHECK (due_on >= starts_on);

alter table public.billing_terms add constraint billing_terms_pkey PRIMARY KEY (id);

alter table public.billing_terms add constraint billing_terms_academic_year_id_starts_on_key UNIQUE (academic_year_id, starts_on);

alter table public.admission_discounts add constraint admission_discounts_kind_check CHECK (kind = ANY (ARRAY['PERCENT'::text, 'FIXED'::text]));

alter table public.admission_discounts add constraint admission_discounts_value_check CHECK (value > 0::numeric);

alter table public.admission_discounts add constraint admission_discounts_check CHECK (ends_on >= starts_on);

alter table public.admission_discounts add constraint admission_discounts_check1 CHECK (kind <> 'PERCENT'::text OR value <= 100::numeric);

alter table public.admission_discounts add constraint admission_discounts_pkey PRIMARY KEY (id);

alter table public.invoice_credits add constraint invoice_credits_kind_check CHECK (kind = ANY (ARRAY['DISCOUNT'::text, 'CANCELLATION'::text]));

alter table public.invoice_credits add constraint invoice_credits_amount_check CHECK (amount > 0::numeric);

alter table public.invoice_credits add constraint invoice_credits_pkey PRIMARY KEY (id);

alter table public.refund_authorizations add constraint refund_authorizations_amount_check CHECK (amount > 0::numeric);

alter table public.refund_authorizations add constraint refund_authorizations_pkey PRIMARY KEY (id);

alter table public.refund_payouts add constraint refund_payouts_pkey PRIMARY KEY (id);

alter table public.refund_payouts add constraint refund_payouts_authorization_id_key UNIQUE (authorization_id);

alter table public.refund_payouts add constraint refund_payouts_refund_no_key UNIQUE (refund_no);

alter table public.admission_cancellations add constraint admission_cancellations_settlement_check CHECK (settlement = ANY (ARRAY['KEEP_CHARGES'::text, 'CREDIT_ALL'::text]));

alter table public.admission_cancellations add constraint admission_cancellations_pkey PRIMARY KEY (admission_id);

alter table public.billing_runs add constraint billing_runs_pkey PRIMARY KEY (id);

alter table public.students add constraint no_self_merge CHECK (merged_into_id IS NULL OR merged_into_id <> id);

alter table public.student_merges add constraint student_merges_check CHECK (source_id <> target_id);

alter table public.student_merges add constraint student_merges_pkey PRIMARY KEY (id);

alter table public.student_merges add constraint student_merges_source_id_key UNIQUE (source_id);

alter table public.enrollment_transfers add constraint enrollment_transfers_pkey PRIMARY KEY (id);

alter table public.enrollment_transfers add constraint enrollment_transfers_from_enrollment_id_key UNIQUE (from_enrollment_id);

alter table public.enrollment_transfers add constraint enrollment_transfers_to_enrollment_id_key UNIQUE (to_enrollment_id);

alter table public.academic_rooms add constraint academic_rooms_name_check CHECK (length(btrim(name)) >= 2);

alter table public.academic_rooms add constraint academic_rooms_capacity_check CHECK (capacity > 0);

alter table public.academic_rooms add constraint academic_rooms_pkey PRIMARY KEY (id);

alter table public.academic_rooms add constraint academic_rooms_branch_id_name_key UNIQUE (branch_id, name);

alter table public.curriculum_versions add constraint curriculum_versions_pkey PRIMARY KEY (id);

alter table public.curriculum_versions add constraint curriculum_versions_batch_id_subject_id_version_key UNIQUE (batch_id, subject_id, version);

alter table public.academic_routines add constraint academic_routines_weekday_check CHECK (weekday >= 0 AND weekday <= 6);

alter table public.academic_routines add constraint academic_routines_check CHECK (end_time > start_time);

alter table public.academic_routines add constraint academic_routines_check1 CHECK (ends_on >= starts_on);

alter table public.academic_routines add constraint academic_routines_pkey PRIMARY KEY (id);

alter table public.class_sessions add constraint class_sessions_status_check CHECK (status = ANY (ARRAY['SCHEDULED'::text, 'CANCELLED'::text]));

alter table public.class_sessions add constraint class_sessions_check CHECK (ends_at > starts_at);

alter table public.class_sessions add constraint class_sessions_pkey PRIMARY KEY (id);

alter table public.class_sessions add constraint class_sessions_routine_id_session_date_key UNIQUE (routine_id, session_date);

alter table public.attendance_submissions add constraint attendance_submissions_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.attendance_submissions add constraint attendance_submissions_pkey PRIMARY KEY (id);

alter table public.attendance_submissions add constraint attendance_submissions_approval_id_key UNIQUE (approval_id);

alter table public.attendance_submissions add constraint attendance_submissions_session_id_revision_key UNIQUE (session_id, revision);

alter table public.programme_offering_subjects add constraint programme_offering_subjects_pkey PRIMARY KEY (offering_id, subject_id);

alter table public.prospects add constraint prospects_submission_intent_check CHECK (submission_intent = ANY (ARRAY['interest'::text, 'admission'::text]));

alter table public.class_logs add constraint class_logs_revision_check CHECK (revision > 0);

alter table public.class_logs add constraint class_logs_check CHECK (status = 'DRAFT'::text AND submitted_at IS NULL OR status = 'SUBMITTED'::text AND submitted_at IS NOT NULL);

alter table public.class_logs add constraint class_logs_pkey PRIMARY KEY (id);

alter table public.class_logs add constraint class_logs_session_id_revision_key UNIQUE (session_id, revision);

alter table public.question_bank_items add constraint question_bank_items_revision_check CHECK (revision > 0);

alter table public.question_bank_items add constraint question_bank_items_topic_check CHECK (length(btrim(topic)) >= 2 AND length(btrim(topic)) <= 180);

alter table public.question_bank_items add constraint question_bank_items_difficulty_check CHECK (difficulty = ANY (ARRAY['FOUNDATION'::text, 'STANDARD'::text, 'ADVANCED'::text]));

alter table public.question_bank_items add constraint question_bank_items_question_type_check CHECK (question_type = ANY (ARRAY['MCQ'::text, 'SHORT_ANSWER'::text]));

alter table public.question_bank_items add constraint question_bank_items_prompt_check CHECK (length(btrim(prompt)) >= 10 AND length(btrim(prompt)) <= 3000);

alter table public.question_bank_items add constraint question_bank_items_answer_key_check CHECK (length(btrim(answer_key)) >= 1 AND length(btrim(answer_key)) <= 1500);

alter table public.question_bank_items add constraint question_bank_items_explanation_check CHECK (explanation IS NULL OR length(explanation) <= 3000);

alter table public.question_bank_items add constraint question_bank_items_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.question_bank_items add constraint question_bank_items_check CHECK ((status = ANY (ARRAY['APPROVED'::text, 'REJECTED'::text])) = (reviewer_id IS NOT NULL));

alter table public.question_bank_items add constraint question_bank_items_pkey PRIMARY KEY (id);

alter table public.question_bank_items add constraint question_bank_items_root_id_revision_key UNIQUE (root_id, revision);

alter table public.homework_checks add constraint homework_checks_revision_check CHECK (revision > 0);

alter table public.homework_checks add constraint homework_checks_status_check CHECK (status = ANY (ARRAY['NOT_SUBMITTED'::text, 'NEEDS_WORK'::text, 'COMPLETE'::text]));

alter table public.homework_checks add constraint homework_checks_feedback_check CHECK (length(feedback) <= 1000);

alter table public.homework_checks add constraint homework_checks_pkey PRIMARY KEY (id);

alter table public.homework_checks add constraint homework_checks_class_log_id_enrollment_id_revision_key UNIQUE (class_log_id, enrollment_id, revision);

alter table public.academic_assessments add constraint academic_assessments_title_check CHECK (length(btrim(title)) >= 3 AND length(btrim(title)) <= 180);

alter table public.academic_assessments add constraint academic_assessments_max_marks_check CHECK (max_marks > 0::numeric AND max_marks <= 1000::numeric);

alter table public.academic_assessments add constraint academic_assessments_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'PUBLISHED'::text, 'CANCELLED'::text]));

alter table public.academic_assessments add constraint academic_assessments_check CHECK ((status = 'DRAFT'::text) = (published_at IS NULL) OR status = 'CANCELLED'::text);

alter table public.academic_assessments add constraint academic_assessments_pkey PRIMARY KEY (id);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_revision_check CHECK (revision > 0);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.assessment_result_submissions add constraint assessment_result_submissions_check CHECK ((status = ANY (ARRAY['APPROVED'::text, 'REJECTED'::text])) = (reviewer_id IS NOT NULL));

alter table public.assessment_result_submissions add constraint assessment_result_submissions_pkey PRIMARY KEY (id);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_assessment_id_revision_key UNIQUE (assessment_id, revision);

alter table public.finance_accounts add constraint finance_accounts_account_type_check CHECK (account_type = ANY (ARRAY['ASSET'::text, 'LIABILITY'::text, 'EQUITY'::text, 'REVENUE'::text, 'CONTRA_REVENUE'::text, 'EXPENSE'::text]));

alter table public.finance_accounts add constraint finance_accounts_pkey PRIMARY KEY (id);

alter table public.finance_accounts add constraint finance_accounts_organization_id_code_key UNIQUE (organization_id, code);

alter table public.finance_cost_centres add constraint finance_cost_centres_pkey PRIMARY KEY (id);

alter table public.finance_cost_centres add constraint finance_cost_centres_organization_id_code_key UNIQUE (organization_id, code);

alter table public.general_ledger_journals add constraint general_ledger_journals_journal_type_check CHECK (journal_type = ANY (ARRAY['INVOICE'::text, 'INVOICE_CREDIT'::text, 'PAYMENT'::text, 'REFUND'::text, 'ADVANCE_PAYMENT'::text, 'ADVANCE_SETTLEMENT'::text, 'ADVANCE_REFUND'::text, 'EXPENSE'::text, 'PAYABLE_SETTLEMENT'::text, 'COMPENSATION_RUN'::text, 'COMPENSATION_SETTLEMENT'::text, 'MANUAL'::text]));

alter table public.general_ledger_journals add constraint general_ledger_journals_status_check CHECK (status = ANY (ARRAY['POSTED'::text, 'VOIDED'::text]));

alter table public.general_ledger_journals add constraint general_ledger_journals_pkey PRIMARY KEY (id);

alter table public.general_ledger_journals add constraint general_ledger_journals_journal_no_key UNIQUE (journal_no);

alter table public.general_ledger_journals add constraint general_ledger_journals_source_type_source_id_key UNIQUE (source_type, source_id);

alter table public.general_ledger_lines add constraint general_ledger_lines_debit_check CHECK (debit >= 0::numeric);

alter table public.general_ledger_lines add constraint general_ledger_lines_credit_check CHECK (credit >= 0::numeric);

alter table public.general_ledger_lines add constraint general_ledger_lines_check CHECK (debit = 0::numeric AND credit > 0::numeric OR credit = 0::numeric AND debit > 0::numeric);

alter table public.general_ledger_lines add constraint general_ledger_lines_pkey PRIMARY KEY (id);

alter table public.general_ledger_lines add constraint general_ledger_lines_journal_id_line_no_key UNIQUE (journal_id, line_no);

alter table public.vendors add constraint vendors_pkey PRIMARY KEY (id);

alter table public.vendors add constraint vendors_vendor_no_key UNIQUE (vendor_no);

alter table public.vendors add constraint vendors_organization_id_name_key UNIQUE (organization_id, name);

alter table public.finance_payment_account_map add constraint finance_payment_account_map_pkey PRIMARY KEY (payment_method_id);

alter table public.finance_fee_revenue_map add constraint finance_fee_revenue_map_pkey PRIMARY KEY (id);

alter table public.finance_fee_revenue_map add constraint finance_fee_revenue_map_organization_id_charge_type_key UNIQUE (organization_id, charge_type);

alter table public.finance_payables add constraint finance_payables_payable_type_check CHECK (payable_type = ANY (ARRAY['TEACHER_COMPENSATION'::text, 'VENDOR'::text, 'STAFF_REIMBURSEMENT'::text, 'OTHER'::text]));

alter table public.finance_payables add constraint finance_payables_original_amount_check CHECK (original_amount > 0::numeric);

alter table public.finance_payables add constraint finance_payables_status_check CHECK (status = ANY (ARRAY['OPEN'::text, 'PARTIALLY_SETTLED'::text, 'SETTLED'::text, 'VOIDED'::text]));

alter table public.finance_payables add constraint finance_payables_pkey PRIMARY KEY (id);

alter table public.finance_payables add constraint finance_payables_payable_no_key UNIQUE (payable_no);

alter table public.finance_payables add constraint finance_payables_source_type_source_id_key UNIQUE (source_type, source_id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_amount_check CHECK (amount > 0::numeric);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_pkey PRIMARY KEY (id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_payable_id_id_key UNIQUE (payable_id, id);

alter table public.finance_advances add constraint finance_advances_beneficiary_type_check CHECK (beneficiary_type = ANY (ARRAY['STAFF'::text, 'VENDOR'::text, 'PROJECT'::text]));

alter table public.finance_advances add constraint finance_advances_requested_amount_check CHECK (requested_amount > 0::numeric);

alter table public.finance_advances add constraint finance_advances_status_check CHECK (status = ANY (ARRAY['REQUESTED'::text, 'APPROVED'::text, 'PAID'::text, 'PARTIALLY_SETTLED'::text, 'SETTLED'::text, 'REFUNDED'::text, 'OVERDUE'::text, 'REJECTED'::text]));

alter table public.finance_advances add constraint finance_advances_check CHECK (beneficiary_type = 'STAFF'::text AND staff_id IS NOT NULL AND vendor_id IS NULL OR beneficiary_type = 'VENDOR'::text AND vendor_id IS NOT NULL AND staff_id IS NULL OR beneficiary_type = 'PROJECT'::text AND staff_id IS NULL AND vendor_id IS NULL AND NULLIF(btrim(project_reference), ''::text) IS NOT NULL);

alter table public.finance_advances add constraint finance_advances_pkey PRIMARY KEY (id);

alter table public.finance_advances add constraint finance_advances_advance_no_key UNIQUE (advance_no);

alter table public.finance_advance_movements add constraint finance_advance_movements_movement_type_check CHECK (movement_type = ANY (ARRAY['PAYMENT'::text, 'SETTLEMENT'::text, 'REFUND'::text]));

alter table public.finance_advance_movements add constraint finance_advance_movements_amount_check CHECK (amount > 0::numeric);

alter table public.finance_advance_movements add constraint finance_advance_movements_pkey PRIMARY KEY (id);

alter table public.finance_advance_movements add constraint finance_advance_movements_source_type_source_id_key UNIQUE (source_type, source_id);

alter table public.finance_expense_categories add constraint finance_expense_categories_pkey PRIMARY KEY (id);

alter table public.finance_expense_categories add constraint finance_expense_categories_organization_id_code_key UNIQUE (organization_id, code);

alter table public.finance_expenses add constraint finance_expenses_payment_mode_check CHECK (payment_mode = ANY (ARRAY['PAID_NOW'::text, 'ON_ACCOUNT'::text]));

alter table public.finance_expenses add constraint finance_expenses_amount_check CHECK (amount > 0::numeric);

alter table public.finance_expenses add constraint finance_expenses_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'PENDING_APPROVAL'::text, 'APPROVED'::text, 'REJECTED'::text, 'POSTED'::text, 'RECONCILED'::text]));

alter table public.finance_expenses add constraint finance_expenses_check CHECK (payment_mode = 'PAID_NOW'::text AND payment_account_id IS NOT NULL OR payment_mode = 'ON_ACCOUNT'::text AND payment_account_id IS NULL);

alter table public.finance_expenses add constraint finance_expenses_pkey PRIMARY KEY (id);

alter table public.finance_expenses add constraint finance_expenses_expense_no_key UNIQUE (expense_no);

alter table public.finance_expense_reconciliations add constraint finance_expense_reconciliations_matched_amount_check CHECK (matched_amount > 0::numeric);

alter table public.finance_expense_reconciliations add constraint finance_expense_reconciliations_pkey PRIMARY KEY (id);

alter table public.finance_expense_reconciliations add constraint finance_expense_reconciliations_expense_id_key UNIQUE (expense_id);

alter table public.finance_account_reconciliations add constraint finance_account_reconciliations_status_check CHECK (status = ANY (ARRAY['OPEN'::text, 'RECONCILED'::text]));

alter table public.finance_account_reconciliations add constraint finance_account_reconciliations_pkey PRIMARY KEY (id);

alter table public.finance_account_reconciliations add constraint finance_account_reconciliatio_account_id_statement_date_sta_key UNIQUE (account_id, statement_date, statement_reference);

alter table public.teacher_referrals add constraint teacher_referrals_pkey PRIMARY KEY (id);

alter table public.teacher_referrals add constraint teacher_referrals_admission_id_key UNIQUE (admission_id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'PENDING_APPROVAL'::text, 'APPROVED'::text, 'SETTLED'::text, 'REJECTED'::text]));

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_total_amount_check CHECK (total_amount >= 0::numeric);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_check CHECK (period_end >= period_start);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_run_no_key UNIQUE (run_no);

alter table public.teacher_compensation_events add constraint teacher_compensation_events_event_type_check CHECK (event_type = ANY (ARRAY['ACQUISITION_BONUS'::text, 'RETENTION_3_MONTH'::text, 'RETENTION_6_MONTH'::text]));

alter table public.teacher_compensation_events add constraint teacher_compensation_events_amount_check CHECK (amount >= 0::numeric);

alter table public.teacher_compensation_events add constraint teacher_compensation_events_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_events add constraint teacher_compensation_events_event_key_key UNIQUE (event_key);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_amount_check CHECK (amount > 0::numeric);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_adjustment_type_check CHECK (adjustment_type = ANY (ARRAY['GROWTH_BONUS'::text, 'ADJUSTMENT'::text]));

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_status_check CHECK (status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_line_type_check CHECK (line_type = ANY (ARRAY['TEACHING_REMUNERATION'::text, 'ACQUISITION_BONUS'::text, 'RETENTION_3_MONTH'::text, 'RETENTION_6_MONTH'::text, 'GROWTH_BONUS'::text, 'ADJUSTMENT'::text]));

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_amount_check CHECK (amount > 0::numeric);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_run_id_source_type_source_id_key UNIQUE (run_id, source_type, source_id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_gross_amount_check CHECK (gross_amount > 0::numeric);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_advance_offset_check CHECK (advance_offset >= 0::numeric);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_cash_paid_check CHECK (cash_paid >= 0::numeric);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_check CHECK (cash_paid = 0::numeric OR payment_account_id IS NOT NULL);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_payable_id_key UNIQUE (payable_id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_run_id_teacher_id_key UNIQUE (run_id, teacher_id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_pkey PRIMARY KEY (id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_line_id_key UNIQUE (line_id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_teacher_id_source_type_source_i_key UNIQUE (teacher_id, source_type, source_id);

alter table public.referral_people add constraint referral_people_full_name_check CHECK (length(btrim(full_name)) >= 2);

alter table public.referral_people add constraint referral_people_check CHECK (staff_id IS NOT NULL OR mobile ~ '^01[3-9][0-9]{8}$'::text);

alter table public.referral_people add constraint referral_people_pkey PRIMARY KEY (id);

alter table public.referral_people add constraint referral_people_staff_id_key UNIQUE (staff_id);

alter table public.referral_people add constraint referral_people_organization_id_mobile_key UNIQUE (organization_id, mobile);

alter table public.admission_referrals add constraint admission_referrals_source_check CHECK (source = ANY (ARRAY['ORGANIC'::text, 'REFERRED'::text]));

alter table public.admission_referrals add constraint admission_referrals_check CHECK (source = 'ORGANIC'::text AND referrer_id IS NULL OR source = 'REFERRED'::text AND referrer_id IS NOT NULL);

alter table public.admission_referrals add constraint admission_referrals_pkey PRIMARY KEY (admission_id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_net_collected_check CHECK (net_collected > 0::numeric);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_bonus_percent_check CHECK (bonus_percent >= 0::numeric);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_amount_check CHECK (amount > 0::numeric);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_status_check CHECK (status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.referral_bonus_awards add constraint referral_bonus_awards_pkey PRIMARY KEY (id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_payable_id_key UNIQUE (payable_id);

alter table public.staff_admission_intake_requests add constraint staff_admission_intake_requests_pkey PRIMARY KEY (request_id);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_version_check CHECK (version > 0);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receip_physical_copy_reference_check CHECK (physical_copy_reference IS NULL OR length(physical_copy_reference) <= 160);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_reason_check CHECK (length(TRIM(BOTH FROM reason)) >= 5);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_pkey PRIMARY KEY (id);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_request_id_key UNIQUE (request_id);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_admission_id_version_key UNIQUE (admission_id, version);

alter table public.admission_cases add constraint admission_identity_source CHECK (origin = 'DIRECT_STAFF'::text AND NOT existing_student AND origin_prospect_id IS NULL OR (origin = ANY (ARRAY['PROSPECT_CONVERSION'::text, 'PUBLIC_APPLICATION'::text])) AND NOT existing_student AND prospect_id IS NOT NULL AND origin_prospect_id = prospect_id OR origin = 'EXISTING_STUDENT'::text AND existing_student AND student_id IS NOT NULL AND origin_prospect_id IS NULL);

alter table public.class_logs add constraint class_logs_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text, 'APPROVED'::text, 'REJECTED'::text]));

alter table public.class_logs add constraint class_logs_review_fields_check CHECK ((status = ANY (ARRAY['APPROVED'::text, 'REJECTED'::text])) AND reviewer_id IS NOT NULL AND reviewed_at IS NOT NULL OR (status = ANY (ARRAY['DRAFT'::text, 'SUBMITTED'::text])));

alter table public.programme_offerings add constraint valid_discount_percentages CHECK (allowed_discount_percentages <@ ARRAY[5, 10, 15, 20, 25, 30]);

alter table public.admission_cases add constraint admission_cases_selected_discount_percent_check CHECK (selected_discount_percent = ANY (ARRAY[0, 5, 10, 15, 20, 25, 30]));

alter table public.staff_access_requests add constraint staff_access_requests_requested_role_check CHECK (requested_role = ANY (ARRAY['ADMIN'::text, 'OPERATOR'::text, 'TEACHER'::text, 'ACCOUNTANT'::text]));

alter table public.staff_access_requests add constraint staff_access_requests_status_check CHECK (status = ANY (ARRAY['PENDING'::text, 'VERIFIED'::text, 'INVITED'::text, 'DECLINED'::text, 'INACTIVE'::text]));

alter table public.staff_access_requests add constraint staff_access_requests_assigned_role_check CHECK (assigned_role = ANY (ARRAY['ADMIN'::text, 'OPERATOR'::text, 'TEACHER'::text, 'ACCOUNTANT'::text]));

alter table public.staff_access_requests add constraint staff_access_requests_pkey PRIMARY KEY (id);

alter table public.admission_cases add constraint admission_cases_status_check CHECK (status = ANY (ARRAY['DRAFT'::text, 'READY'::text, 'ACCEPTED'::text, 'BILLING_POSTED'::text, 'PENDING_PAYMENT'::text, 'ACTIVE_ENROLLMENT'::text, 'CANCELLED'::text, 'CLOSED_ENROLLMENT'::text]));

alter table public.admission_discounts add constraint admission_discounts_authorization_actor_check CHECK (authorized_by IS NOT NULL);

alter table public.refund_authorizations add constraint refund_authorizations_authorization_actor_check CHECK (authorized_by IS NOT NULL);

alter table public.admission_cancellations add constraint admission_cancellations_authorization_actor_check CHECK (cancelled_by IS NOT NULL);

alter table public.branches add constraint branches_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table public.role_permissions add constraint role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES system_roles(id);

alter table public.role_permissions add constraint role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id);

alter table public.user_role_assignments add constraint user_role_assignments_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id);

alter table public.user_role_assignments add constraint user_role_assignments_role_id_fkey FOREIGN KEY (role_id) REFERENCES system_roles(id);

alter table public.user_role_assignments add constraint user_role_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.user_role_assignments add constraint user_role_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES profiles(id);

alter table public.staff add constraint staff_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id);

alter table public.staff add constraint staff_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.staff add constraint staff_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.staff_role_assignments add constraint staff_role_assignments_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.staff_role_assignments add constraint staff_role_assignments_staff_role_id_fkey FOREIGN KEY (staff_role_id) REFERENCES staff_roles(id);

alter table public.staff_role_assignments add constraint staff_role_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.staff_role_assignments add constraint staff_role_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES profiles(id);

alter table public.audit_events add constraint audit_events_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES profiles(id);

alter table public.audit_events add constraint audit_events_actor_staff_id_fkey FOREIGN KEY (actor_staff_id) REFERENCES staff(id);

alter table public.audit_events add constraint audit_events_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.approval_requests add constraint approval_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public.approval_requests add constraint approval_requests_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES profiles(id);

alter table public.business_rule_versions add constraint business_rule_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.academic_years add constraint academic_years_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.classes add constraint classes_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.programs add constraint programs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.subjects add constraint subjects_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.areas add constraint areas_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.areas add constraint areas_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES areas(id);

alter table public.schools add constraint schools_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.schools add constraint schools_area_id_fkey FOREIGN KEY (area_id) REFERENCES areas(id);

alter table public.schools add constraint schools_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.lead_sources add constraint lead_sources_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.guardian_relationships add constraint guardian_relationships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.payment_methods add constraint payment_methods_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.prospects add constraint prospects_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.prospects add constraint prospects_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.prospects add constraint prospects_guardian_relationship_id_fkey FOREIGN KEY (guardian_relationship_id) REFERENCES guardian_relationships(id);

alter table public.prospects add constraint prospects_current_class_id_fkey FOREIGN KEY (current_class_id) REFERENCES classes(id);

alter table public.prospects add constraint prospects_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id);

alter table public.prospects add constraint prospects_area_id_fkey FOREIGN KEY (area_id) REFERENCES areas(id);

alter table public.prospects add constraint prospects_source_id_fkey FOREIGN KEY (source_id) REFERENCES lead_sources(id);

alter table public.prospects add constraint prospects_assigned_to_staff_id_fkey FOREIGN KEY (assigned_to_staff_id) REFERENCES staff(id);

alter table public.prospect_program_interests add constraint prospect_program_interests_prospect_id_fkey FOREIGN KEY (prospect_id) REFERENCES prospects(id);

alter table public.prospect_program_interests add constraint prospect_program_interests_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.prospect_subject_interests add constraint prospect_subject_interests_prospect_id_fkey FOREIGN KEY (prospect_id) REFERENCES prospects(id);

alter table public.prospect_subject_interests add constraint prospect_subject_interests_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.prospect_followups add constraint prospect_followups_prospect_id_fkey FOREIGN KEY (prospect_id) REFERENCES prospects(id);

alter table public.prospect_followups add constraint prospect_followups_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES profiles(id);

alter table public.students add constraint students_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.students add constraint students_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.students add constraint students_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id);

alter table public.students add constraint students_created_from_prospect_id_fkey FOREIGN KEY (created_from_prospect_id) REFERENCES prospects(id);

alter table public.students add constraint students_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.prospects add constraint prospects_converted_student_fkey FOREIGN KEY (converted_student_id) REFERENCES students(id);

alter table public.guardians add constraint guardians_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.guardians add constraint guardians_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.student_guardians add constraint student_guardians_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.student_guardians add constraint student_guardians_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES guardians(id);

alter table public.student_guardians add constraint student_guardians_relationship_id_fkey FOREIGN KEY (relationship_id) REFERENCES guardian_relationships(id);

alter table public.batches add constraint batches_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.batches add constraint batches_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.batches add constraint batches_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);

alter table public.batches add constraint batches_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id);

alter table public.batches add constraint batches_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.batches add constraint batches_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.enrollments add constraint enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.enrollments add constraint enrollments_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.enrollments add constraint enrollments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.enrollments add constraint enrollments_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);

alter table public.enrollments add constraint enrollments_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id);

alter table public.enrollments add constraint enrollments_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.enrollments add constraint enrollments_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.enrollments add constraint enrollments_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.staff_subject_assignments add constraint staff_subject_assignments_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.staff_subject_assignments add constraint staff_subject_assignments_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.staff_subject_assignments add constraint staff_subject_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES profiles(id);

alter table public.academic_groups add constraint academic_groups_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.programme_offerings add constraint programme_offerings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.programme_offerings add constraint programme_offerings_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.programme_offerings add constraint programme_offerings_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);

alter table public.programme_offerings add constraint programme_offerings_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id);

alter table public.programme_offerings add constraint programme_offerings_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.programme_offerings add constraint programme_offerings_group_id_fkey FOREIGN KEY (group_id) REFERENCES academic_groups(id);

alter table public.programme_offerings add constraint programme_offerings_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.fee_plan_versions add constraint fee_plan_versions_offering_id_fkey FOREIGN KEY (offering_id) REFERENCES programme_offerings(id);

alter table public.fee_plan_versions add constraint fee_plan_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.fee_plan_components add constraint fee_plan_components_fee_plan_version_id_fkey FOREIGN KEY (fee_plan_version_id) REFERENCES fee_plan_versions(id);

alter table public.batches add constraint batches_offering_id_fkey FOREIGN KEY (offering_id) REFERENCES programme_offerings(id);

alter table public.batches add constraint batches_capacity_policy_version_id_fkey FOREIGN KEY (capacity_policy_version_id) REFERENCES business_rule_versions(id);

alter table public.admission_cases add constraint admission_cases_prospect_id_fkey FOREIGN KEY (prospect_id) REFERENCES prospects(id);

alter table public.admission_cases add constraint admission_cases_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.admission_cases add constraint admission_cases_fee_plan_version_id_fkey FOREIGN KEY (fee_plan_version_id) REFERENCES fee_plan_versions(id);

alter table public.admission_cases add constraint admission_cases_activation_policy_version_id_fkey FOREIGN KEY (activation_policy_version_id) REFERENCES business_rule_versions(id);

alter table public.admission_cases add constraint admission_cases_capacity_policy_version_id_fkey FOREIGN KEY (capacity_policy_version_id) REFERENCES business_rule_versions(id);

alter table public.admission_cases add constraint admission_cases_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.admission_cases add constraint admission_cases_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES enrollments(id);

alter table public.admission_cases add constraint admission_cases_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.admission_invoices add constraint admission_invoices_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.admission_invoices add constraint admission_invoices_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.admission_invoices add constraint admission_invoices_fee_plan_version_id_fkey FOREIGN KEY (fee_plan_version_id) REFERENCES fee_plan_versions(id);

alter table public.admission_invoices add constraint admission_invoices_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.admission_invoice_lines add constraint admission_invoice_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES admission_invoices(id);

alter table public.admission_invoice_lines add constraint admission_invoice_lines_fee_component_id_fkey FOREIGN KEY (fee_component_id) REFERENCES fee_plan_components(id);

alter table public.admission_command_keys add constraint admission_command_keys_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id);

alter table public.admission_payments add constraint admission_payments_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.admission_payments add constraint admission_payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id);

alter table public.admission_payments add constraint admission_payments_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.admission_payment_allocations add constraint admission_payment_allocations_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES admission_payments(id);

alter table public.admission_payment_allocations add constraint admission_payment_allocations_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES admission_invoices(id);

alter table public.billing_terms add constraint billing_terms_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES academic_years(id);

alter table public.billing_terms add constraint billing_terms_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.admission_discounts add constraint admission_discounts_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.invoice_credits add constraint invoice_credits_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES admission_invoices(id);

alter table public.invoice_credits add constraint invoice_credits_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES admission_discounts(id);

alter table public.refund_authorizations add constraint refund_authorizations_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES admission_payments(id);

alter table public.refund_authorizations add constraint refund_authorizations_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES admission_invoices(id);

alter table public.refund_payouts add constraint refund_payouts_authorization_id_fkey FOREIGN KEY (authorization_id) REFERENCES refund_authorizations(id);

alter table public.refund_payouts add constraint refund_payouts_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id);

alter table public.refund_payouts add constraint refund_payouts_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.admission_cancellations add constraint admission_cancellations_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.billing_runs add constraint billing_runs_term_id_fkey FOREIGN KEY (term_id) REFERENCES billing_terms(id);

alter table public.billing_runs add constraint billing_runs_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.students add constraint students_merged_into_id_fkey FOREIGN KEY (merged_into_id) REFERENCES students(id);

alter table public.student_merges add constraint student_merges_source_id_fkey FOREIGN KEY (source_id) REFERENCES students(id);

alter table public.student_merges add constraint student_merges_target_id_fkey FOREIGN KEY (target_id) REFERENCES students(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_from_enrollment_id_fkey FOREIGN KEY (from_enrollment_id) REFERENCES enrollments(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_to_enrollment_id_fkey FOREIGN KEY (to_enrollment_id) REFERENCES enrollments(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_from_batch_id_fkey FOREIGN KEY (from_batch_id) REFERENCES batches(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_to_batch_id_fkey FOREIGN KEY (to_batch_id) REFERENCES batches(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_capacity_policy_version_id_fkey FOREIGN KEY (capacity_policy_version_id) REFERENCES business_rule_versions(id);

alter table public.academic_rooms add constraint academic_rooms_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.academic_rooms add constraint academic_rooms_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.curriculum_versions add constraint curriculum_versions_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.curriculum_versions add constraint curriculum_versions_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.curriculum_versions add constraint curriculum_versions_published_by_fkey FOREIGN KEY (published_by) REFERENCES profiles(id);

alter table public.academic_routines add constraint academic_routines_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.academic_routines add constraint academic_routines_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.academic_routines add constraint academic_routines_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.academic_routines add constraint academic_routines_room_id_fkey FOREIGN KEY (room_id) REFERENCES academic_rooms(id);

alter table public.academic_routines add constraint academic_routines_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.class_sessions add constraint class_sessions_routine_id_fkey FOREIGN KEY (routine_id) REFERENCES academic_routines(id);

alter table public.class_sessions add constraint class_sessions_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.class_sessions add constraint class_sessions_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.class_sessions add constraint class_sessions_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.class_sessions add constraint class_sessions_room_id_fkey FOREIGN KEY (room_id) REFERENCES academic_rooms(id);

alter table public.class_sessions add constraint class_sessions_curriculum_version_id_fkey FOREIGN KEY (curriculum_version_id) REFERENCES curriculum_versions(id);

alter table public.class_sessions add constraint class_sessions_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES profiles(id);

alter table public.class_sessions add constraint class_sessions_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.attendance_submissions add constraint attendance_submissions_session_id_fkey FOREIGN KEY (session_id) REFERENCES class_sessions(id);

alter table public.attendance_submissions add constraint attendance_submissions_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES profiles(id);

alter table public.attendance_submissions add constraint attendance_submissions_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES approval_requests(id);

alter table public.programme_offering_subjects add constraint programme_offering_subjects_offering_id_fkey FOREIGN KEY (offering_id) REFERENCES programme_offerings(id) ON DELETE CASCADE;

alter table public.programme_offering_subjects add constraint programme_offering_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.prospects add constraint prospects_interested_offering_id_fkey FOREIGN KEY (interested_offering_id) REFERENCES programme_offerings(id);

alter table public.class_logs add constraint class_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES class_sessions(id);

alter table public.class_logs add constraint class_logs_previous_log_id_fkey FOREIGN KEY (previous_log_id) REFERENCES class_logs(id);

alter table public.class_logs add constraint class_logs_authored_by_fkey FOREIGN KEY (authored_by) REFERENCES profiles(id);

alter table public.question_bank_items add constraint question_bank_items_root_id_fkey FOREIGN KEY (root_id) REFERENCES question_bank_items(id);

alter table public.question_bank_items add constraint question_bank_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.question_bank_items add constraint question_bank_items_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.question_bank_items add constraint question_bank_items_curriculum_version_id_fkey FOREIGN KEY (curriculum_version_id) REFERENCES curriculum_versions(id);

alter table public.question_bank_items add constraint question_bank_items_author_id_fkey FOREIGN KEY (author_id) REFERENCES profiles(id);

alter table public.question_bank_items add constraint question_bank_items_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table public.homework_checks add constraint homework_checks_class_log_id_fkey FOREIGN KEY (class_log_id) REFERENCES class_logs(id);

alter table public.homework_checks add constraint homework_checks_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES enrollments(id);

alter table public.homework_checks add constraint homework_checks_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES profiles(id);

alter table public.academic_assessments add constraint academic_assessments_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.academic_assessments add constraint academic_assessments_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects(id);

alter table public.academic_assessments add constraint academic_assessments_author_id_fkey FOREIGN KEY (author_id) REFERENCES profiles(id);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_assessment_id_fkey FOREIGN KEY (assessment_id) REFERENCES academic_assessments(id);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_author_id_fkey FOREIGN KEY (author_id) REFERENCES profiles(id);

alter table public.assessment_result_submissions add constraint assessment_result_submissions_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table public.finance_accounts add constraint finance_accounts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_accounts add constraint finance_accounts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES finance_accounts(id);

alter table public.finance_accounts add constraint finance_accounts_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.finance_cost_centres add constraint finance_cost_centres_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_cost_centres add constraint finance_cost_centres_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.finance_cost_centres add constraint finance_cost_centres_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.finance_cost_centres add constraint finance_cost_centres_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.finance_cost_centres add constraint finance_cost_centres_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.general_ledger_journals add constraint general_ledger_journals_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.general_ledger_journals add constraint general_ledger_journals_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES general_ledger_journals(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_cost_centre_id_fkey FOREIGN KEY (cost_centre_id) REFERENCES finance_cost_centres(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_program_id_fkey FOREIGN KEY (program_id) REFERENCES programs(id);

alter table public.general_ledger_lines add constraint general_ledger_lines_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES batches(id);

alter table public.vendors add constraint vendors_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.vendors add constraint vendors_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.finance_payment_account_map add constraint finance_payment_account_map_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id);

alter table public.finance_payment_account_map add constraint finance_payment_account_map_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id);

alter table public.finance_fee_revenue_map add constraint finance_fee_revenue_map_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_fee_revenue_map add constraint finance_fee_revenue_map_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id);

alter table public.finance_payables add constraint finance_payables_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_payables add constraint finance_payables_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.finance_payables add constraint finance_payables_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id);

alter table public.finance_payables add constraint finance_payables_payable_account_id_fkey FOREIGN KEY (payable_account_id) REFERENCES finance_accounts(id);

alter table public.finance_payables add constraint finance_payables_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_payable_id_fkey FOREIGN KEY (payable_id) REFERENCES finance_payables(id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_payment_account_id_fkey FOREIGN KEY (payment_account_id) REFERENCES finance_accounts(id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_settled_by_fkey FOREIGN KEY (settled_by) REFERENCES profiles(id);

alter table public.finance_advances add constraint finance_advances_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_advances add constraint finance_advances_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.finance_advances add constraint finance_advances_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id);

alter table public.finance_advances add constraint finance_advances_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public.finance_advance_movements add constraint finance_advance_movements_advance_id_fkey FOREIGN KEY (advance_id) REFERENCES finance_advances(id);

alter table public.finance_advance_movements add constraint finance_advance_movements_payment_account_id_fkey FOREIGN KEY (payment_account_id) REFERENCES finance_accounts(id);

alter table public.finance_advance_movements add constraint finance_advance_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.finance_expense_categories add constraint finance_expense_categories_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_expense_categories add constraint finance_expense_categories_expense_account_id_fkey FOREIGN KEY (expense_account_id) REFERENCES finance_accounts(id);

alter table public.finance_expense_categories add constraint finance_expense_categories_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.finance_expenses add constraint finance_expenses_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.finance_expenses add constraint finance_expenses_category_id_fkey FOREIGN KEY (category_id) REFERENCES finance_expense_categories(id);

alter table public.finance_expenses add constraint finance_expenses_expense_account_id_fkey FOREIGN KEY (expense_account_id) REFERENCES finance_accounts(id);

alter table public.finance_expenses add constraint finance_expenses_payment_account_id_fkey FOREIGN KEY (payment_account_id) REFERENCES finance_accounts(id);

alter table public.finance_expenses add constraint finance_expenses_payable_id_fkey FOREIGN KEY (payable_id) REFERENCES finance_payables(id);

alter table public.finance_expenses add constraint finance_expenses_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES vendors(id);

alter table public.finance_expenses add constraint finance_expenses_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.finance_expenses add constraint finance_expenses_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);

alter table public.finance_expenses add constraint finance_expenses_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES profiles(id);

alter table public.finance_expense_reconciliations add constraint finance_expense_reconciliations_expense_id_fkey FOREIGN KEY (expense_id) REFERENCES finance_expenses(id);

alter table public.finance_expense_reconciliations add constraint finance_expense_reconciliations_reconciled_by_fkey FOREIGN KEY (reconciled_by) REFERENCES profiles(id);

alter table public.finance_account_reconciliations add constraint finance_account_reconciliations_account_id_fkey FOREIGN KEY (account_id) REFERENCES finance_accounts(id);

alter table public.finance_account_reconciliations add constraint finance_account_reconciliations_reconciled_by_fkey FOREIGN KEY (reconciled_by) REFERENCES profiles(id);

alter table public.teacher_referrals add constraint teacher_referrals_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.teacher_referrals add constraint teacher_referrals_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_referrals add constraint teacher_referrals_captured_by_fkey FOREIGN KEY (captured_by) REFERENCES profiles(id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_policy_version_id_fkey FOREIGN KEY (policy_version_id) REFERENCES business_rule_versions(id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES profiles(id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);

alter table public.teacher_compensation_events add constraint teacher_compensation_events_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_compensation_events add constraint teacher_compensation_events_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_run_id_fkey FOREIGN KEY (run_id) REFERENCES teacher_compensation_runs(id);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_run_id_fkey FOREIGN KEY (run_id) REFERENCES teacher_compensation_runs(id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_payable_id_fkey FOREIGN KEY (payable_id) REFERENCES finance_payables(id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_payment_account_id_fkey FOREIGN KEY (payment_account_id) REFERENCES finance_accounts(id);

alter table public.teacher_compensation_settlements add constraint teacher_compensation_settlements_settled_by_fkey FOREIGN KEY (settled_by) REFERENCES profiles(id);

alter table public.teacher_compensation_lines add constraint teacher_compensation_lines_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES staff(id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_line_id_fkey FOREIGN KEY (line_id) REFERENCES teacher_compensation_lines(id);

alter table public.teacher_compensation_claims add constraint teacher_compensation_claims_run_id_fkey FOREIGN KEY (run_id) REFERENCES teacher_compensation_runs(id);

alter table public.finance_advance_movements add constraint finance_advance_movements_payable_id_fkey FOREIGN KEY (payable_id) REFERENCES finance_payables(id);

alter table public.finance_payable_settlements add constraint finance_payable_settlements_advance_id_fkey FOREIGN KEY (advance_id) REFERENCES finance_advances(id);

alter table public.referral_people add constraint referral_people_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id);

alter table public.referral_people add constraint referral_people_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id);

alter table public.referral_people add constraint referral_people_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);

alter table public.admission_referrals add constraint admission_referrals_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.admission_referrals add constraint admission_referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES referral_people(id);

alter table public.admission_referrals add constraint admission_referrals_captured_by_fkey FOREIGN KEY (captured_by) REFERENCES profiles(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES referral_people(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_policy_version_id_fkey FOREIGN KEY (policy_version_id) REFERENCES business_rule_versions(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_payable_id_fkey FOREIGN KEY (payable_id) REFERENCES finance_payables(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id);

alter table public.referral_bonus_awards add constraint referral_bonus_awards_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES profiles(id);

alter table public.finance_payables add constraint finance_payables_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES referral_people(id);

alter table public.staff_admission_intake_requests add constraint staff_admission_intake_requests_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id);

alter table public.staff_admission_intake_requests add constraint staff_admission_intake_requests_prospect_id_fkey FOREIGN KEY (prospect_id) REFERENCES prospects(id);

alter table public.staff_admission_intake_requests add constraint staff_admission_intake_requests_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_admission_id_fkey FOREIGN KEY (admission_id) REFERENCES admission_cases(id);

alter table public.admission_physical_consent_receipts add constraint admission_physical_consent_receipts_received_by_fkey FOREIGN KEY (received_by) REFERENCES profiles(id);

alter table public.admission_cases add constraint admission_cases_origin_prospect_id_fkey FOREIGN KEY (origin_prospect_id) REFERENCES prospects(id);

alter table public.class_logs add constraint class_logs_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table public.admission_discounts add constraint admission_discounts_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.invoice_credits add constraint invoice_credits_applied_by_fkey FOREIGN KEY (applied_by) REFERENCES profiles(id);

alter table public.refund_authorizations add constraint refund_authorizations_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.admission_cancellations add constraint admission_cancellations_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES profiles(id);

alter table public.finance_advances add constraint finance_advances_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.finance_expenses add constraint finance_expenses_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.teacher_compensation_runs add constraint teacher_compensation_runs_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.teacher_compensation_adjustments add constraint teacher_compensation_adjustments_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES profiles(id);

alter table public.attendance_submissions add constraint attendance_submissions_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table public.prospects add constraint prospects_application_verified_by_fkey FOREIGN KEY (application_verified_by) REFERENCES profiles(id);

alter table public.organizations add constraint organizations_setup_completed_by_fkey FOREIGN KEY (setup_completed_by) REFERENCES profiles(id);

alter table public.staff_access_requests add constraint staff_access_requests_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id);

alter table public.staff_access_requests add constraint staff_access_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES profiles(id);

alter table public.student_merges add constraint student_merges_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES public.profiles(id);

alter table public.enrollment_transfers add constraint enrollment_transfers_authorized_by_fkey FOREIGN KEY (authorized_by) REFERENCES public.profiles(id);

CREATE UNIQUE INDEX one_active_business_rule ON public.business_rule_versions USING btree (domain, rule_key) WHERE (status = 'ACTIVE'::rule_status);

CREATE UNIQUE INDEX programme_offering_context_uniq ON public.programme_offerings USING btree (academic_year_id, branch_id, class_id, program_id, COALESCE(group_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE INDEX audit_events_correlation_idx ON public.audit_events USING btree (correlation_id);

CREATE INDEX admission_student_history ON public.admission_cases USING btree (student_id, created_at);

CREATE INDEX general_ledger_lines_account_idx ON public.general_ledger_lines USING btree (account_id, journal_id);

CREATE INDEX finance_advances_status_idx ON public.finance_advances USING btree (organization_id, status, expected_settlement_date);

CREATE INDEX admission_cases_origin_idx ON public.admission_cases USING btree (origin, created_at DESC);

CREATE UNIQUE INDEX assessment_one_pending ON public.assessment_result_submissions USING btree (assessment_id) WHERE (status = 'SUBMITTED'::text);

CREATE INDEX schools_search_idx ON public.schools USING btree (lower(name));

CREATE INDEX attendance_reviewed_idx ON public.attendance_submissions USING btree (session_id, status, revision DESC);

CREATE UNIQUE INDEX fee_plan_one_active_per_offering ON public.fee_plan_versions USING btree (offering_id) WHERE (status = 'ACTIVE'::rule_status);

CREATE UNIQUE INDEX invoice_credit_cancellation_unique ON public.invoice_credits USING btree (invoice_id) WHERE (kind = 'CANCELLATION'::text);

CREATE UNIQUE INDEX staff_primary_open_role_uniq ON public.staff_role_assignments USING btree (staff_id) WHERE (is_primary AND (effective_to IS NULL));

CREATE UNIQUE INDEX staff_access_open_email ON public.staff_access_requests USING btree (lower(email)) WHERE (status = ANY (ARRAY['PENDING'::text, 'VERIFIED'::text, 'INVITED'::text]));

CREATE UNIQUE INDEX admission_open_prospect ON public.admission_cases USING btree (prospect_id) WHERE (status <> 'CANCELLED'::text);

CREATE INDEX sessions_schedule ON public.class_sessions USING btree (starts_at, ends_at) WHERE (status = 'SCHEDULED'::text);

CREATE INDEX guardians_mobile_idx ON public.guardians USING btree (regexp_replace(mobile, '\D'::text, ''::text, 'g'::text));

CREATE UNIQUE INDEX student_academy_roll_unique ON public.students USING btree (academy_roll);

CREATE INDEX academic_assessments_scope ON public.academic_assessments USING btree (batch_id, subject_id, assessment_date DESC);

CREATE INDEX prospects_status_idx ON public.prospects USING btree (status, created_at DESC);

CREATE INDEX admission_physical_consent_case_idx ON public.admission_physical_consent_receipts USING btree (admission_id, version DESC);

CREATE UNIQUE INDEX assessment_one_draft ON public.assessment_result_submissions USING btree (assessment_id) WHERE (status = 'DRAFT'::text);

CREATE UNIQUE INDEX question_bank_one_draft ON public.question_bank_items USING btree (COALESCE(root_id, id)) WHERE (status = 'DRAFT'::text);

CREATE UNIQUE INDEX one_pending_attendance ON public.attendance_submissions USING btree (session_id) WHERE (status = 'SUBMITTED'::text);

CREATE UNIQUE INDEX admission_invoice_period ON public.admission_invoices USING btree (admission_id, billing_period);

CREATE UNIQUE INDEX one_primary_guardian_per_student ON public.student_guardians USING btree (student_id) WHERE is_primary;

CREATE UNIQUE INDEX admission_payment_external_reference ON public.admission_payments USING btree (payment_method_id, external_reference) WHERE (external_reference IS NOT NULL);

CREATE INDEX finance_payables_open_idx ON public.finance_payables USING btree (organization_id, status, due_on);

CREATE INDEX finance_expenses_status_idx ON public.finance_expenses USING btree (organization_id, status, expense_date DESC);

CREATE INDEX programme_offerings_website_visible_idx ON public.programme_offerings USING btree (showcase_sort_order, created_at) WHERE ((is_website_visible = true) AND (status = 'ACTIVE'::offering_status));

CREATE INDEX prospects_interested_offering_idx ON public.prospects USING btree (interested_offering_id) WHERE (interested_offering_id IS NOT NULL);

CREATE UNIQUE INDEX invoice_credit_discount_unique ON public.invoice_credits USING btree (invoice_id, discount_id) WHERE ((kind = 'DISCOUNT'::text) AND (discount_id IS NOT NULL));

CREATE INDEX prospects_followup_idx ON public.prospects USING btree (next_follow_up_at) WHERE (next_follow_up_at IS NOT NULL);

CREATE INDEX students_merged_into ON public.students USING btree (merged_into_id) WHERE (merged_into_id IS NOT NULL);

CREATE INDEX general_ledger_journals_date_idx ON public.general_ledger_journals USING btree (organization_id, journal_date DESC);

CREATE UNIQUE INDEX referral_bonus_one_live_award ON public.referral_bonus_awards USING btree (admission_id) WHERE (status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text]));

CREATE INDEX homework_checks_history ON public.homework_checks USING btree (class_log_id, enrollment_id, revision DESC);

CREATE UNIQUE INDEX staff_subject_open_assignment_uniq ON public.staff_subject_assignments USING btree (staff_id, subject_id) WHERE (effective_to IS NULL);

CREATE UNIQUE INDEX class_logs_one_pending_per_session ON public.class_logs USING btree (session_id) WHERE (status = 'SUBMITTED'::text);

CREATE INDEX finance_accounts_type_idx ON public.finance_accounts USING btree (organization_id, account_type, is_active);

CREATE INDEX admission_cases_consent_gate_idx ON public.admission_cases USING btree (consent_required, status);

CREATE UNIQUE INDEX areas_name_parent_uniq ON public.areas USING btree (organization_id, lower(name), COALESCE(parent_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE UNIQUE INDEX admission_one_initial_invoice ON public.admission_invoices USING btree (admission_id) WHERE (invoice_kind = 'INITIAL'::text);

CREATE UNIQUE INDEX one_class_log_draft_per_session ON public.class_logs USING btree (session_id) WHERE (status = 'DRAFT'::text);

CREATE INDEX approval_requests_pending_idx ON public.approval_requests USING btree (status, requested_at) WHERE (status = 'PENDING'::approval_status);

CREATE INDEX question_bank_scope_idx ON public.question_bank_items USING btree (batch_id, subject_id, created_at DESC);

CREATE INDEX class_logs_session_history ON public.class_logs USING btree (session_id, revision DESC);

CREATE UNIQUE INDEX user_role_open_assignment_uniq ON public.user_role_assignments USING btree (profile_id, role_id, COALESCE(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE (is_active AND (effective_to IS NULL));

CREATE INDEX audit_events_entity_idx ON public.audit_events USING btree (entity_type, entity_id, occurred_at DESC);

CREATE UNIQUE INDEX one_active_enrollment_per_student_year ON public.enrollments USING btree (student_id, academic_year_id) WHERE (status = 'ACTIVE'::enrollment_status);

CREATE INDEX prospects_mobile_idx ON public.prospects USING btree (regexp_replace(mobile, '\D'::text, ''::text, 'g'::text));

CREATE UNIQUE INDEX refund_external_reference ON public.refund_payouts USING btree (payment_method_id, external_reference) WHERE (external_reference IS NOT NULL);
