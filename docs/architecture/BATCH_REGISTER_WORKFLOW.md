# Batch register workflow

The **Academics → Batches** page is a register first. Staff can scan each cohort's display name, code, programme offering, academic year, class, branch, enrolled count, seat capacity and active status. Batch creation opens from **Create batch**; **Edit** opens the same focused form with the current values.

Edits change only the batch code, name and capacity. Programme offering, year, class and branch remain fixed because admissions, enrollments, schedules and results refer to that context. A display name may include the timetable label (for example, `Morning A · 7:30–9:30 am`); session time and days are configured in Academic Operations, not in the batch identity.

The RPC validates the active capacity-policy maximum for create and edit. An edit cannot reduce capacity below the number of active enrollments. All changes use an idempotent request ID and create an audit event with before/after snapshots. Migration `0047_v2_batch_register_management.sql` adds the expanded read model and controlled edit command; rollback regression `0047_v2_batch_register_management.sql` verifies create, edit, policy enforcement, audit and register context.
