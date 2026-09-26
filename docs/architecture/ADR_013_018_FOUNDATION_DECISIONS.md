# ADR-013–018 — ERP v1.1 Foundation Decisions

Status: **Accepted**

These decisions align the repository with **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1**.

## ADR-013 — Configuration-first operations

Management-changeable values are versioned Settings/Business Rules rather than hard-coded constants.

Applies to:
- batch capacity;
- tuition and fee components;
- admission activation;
- minimum payment/deposit rules;
- discounts/scholarships;
- teacher revenue sharing;
- acquisition/retention bonuses;
- approval thresholds;
- role-permission bundles.

Integrity rules remain non-configurable.

## ADR-014 — Programme Offering + Fee Plan inheritance

Programme, Programme Offering and Fee Plan are separate domain concepts.

Normal Admission selects context and inherits standard fee terms. Operators do not retype known standard charges.

Student-specific exceptions are explicit Discount / Scholarship / Fee Exception records.

## ADR-015 — Admission/Billing/Payment/Enrollment separation

Admission acceptance, billing, payment/receipt and enrollment activation are distinct facts.

A receipt proves actual money received. An unpaid obligation is a charge/invoice/receivable.

ACTIVE enrollment is determined by the active admission policy.

## ADR-016 — Permission + Scope authorization

Effective authorization is permission-driven and is designed to support scope such as:
- OWN;
- ASSIGNED_BATCHES;
- BRANCH;
- ORGANIZATION.

The protected bootstrap ADMIN role remains a recovery authority. Operational roles are editable through audited permission workflows.

## ADR-017 — Local loading + live validation

The ERP shell remains mounted during ordinary route loading.

Forms validate continuously and submit remains disabled until valid, changed and not processing.

Mutation pending state is localized to the affected control/row/panel.

## ADR-018 — Idempotency + concurrency protection

Retry-prone or contention-prone business workflows use:
- idempotency/request identity;
- unique constraints;
- transactional locking where needed;
- explicit conflict handling.

Examples include:
- payment posting;
- enrollment into final batch seats;
- invoice/payment allocation;
- settlement;
- numbering;
- bulk imports.
