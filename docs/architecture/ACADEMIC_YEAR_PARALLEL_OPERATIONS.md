# Parallel academic years

Academic years are explicit context on programme offerings and batches. Multiple years may be active for the same organisation so current teaching and next-year preparation can run concurrently. An academic year being active does not publish an offering or open public applications: the offering still requires a published Fee Plan, website visibility, and its own application window and accepting-applications controls.

Migration `0046_v2_parallel_academic_years.sql` removes the single-active-year database index and stops the Manage CRM command from deactivating other years when one year is activated. The Create command now honours the chosen active flag. Existing years keep their recorded statuses; operators may activate 2027 while leaving 2026 active. Deactivation affects the chosen year only, without deleting historical offerings, admissions or invoices.

The rollback SQL regression `0023_v2_manage_crm_identity.sql` covers creation, two simultaneously active future years, a still-active existing year, and deactivation of one year without changing the other. The ERP Manage CRM date column uses plain `to` text for readable date ranges.
