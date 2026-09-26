# Dashboard Initialization — Feature Contract

Branch: `feature/dashboard_initialization`

Authoritative product source: **Sohoj Academy ERP — Product Constitution & Master Blueprint v1.1**.

This branch initializes the internal ERP shell and platform behavior before domain-heavy modules are expanded.

## Goals

1. Keep the ERP shell stable while route content loads or mutates.
2. Drive navigation and route metadata from one registry.
3. Make navigation permission-aware without treating menu hiding as security.
4. Keep Dashboard English-only; public Home, Interest and Auth remain English/Bangla.
5. Establish Settings / Control Center as the source for operational configuration.
6. Keep local loading/error/pending state scoped to the affected route, card, row or button.
7. Use live client validation plus server/database revalidation.
8. Prevent hard-coded operational values from leaking into UI/domain code.

## Dashboard information architecture

```text
Workspace
  Dashboard
  Action Center

CRM & Student Bank
  Prospects
  Students
  Admissions

Academics
  Curriculum
  Routine & Sessions
  Attendance
  Homework
  Assessments
  Coverage & Recovery

Finance
  Fee Plans
  Billing & Dues
  Payments & Receipts
  Discounts / Scholarships
  Advances

People
  Staff
  Leave & Availability
  Workload
  Compensation

Operations
  Procurement
  Assets

Governance
  Approvals
  Audit Trail
  Business Rules
  Settings
```

Only routes whose workflows are actually implemented should be visible. Placeholder modules should not appear as if operational.

## Route registry contract

Each route declares:
- stable route id;
- title;
- eyebrow/group;
- href;
- permission code;
- icon key;
- navigation group;
- optional feature status.

The same registry drives Sidebar, Header and future breadcrumbs/command palette to prevent duplicate route-title logic.

## Access contract

UI access is based on effective ERP context:
- authenticated Profile;
- active Staff identity where applicable;
- active role assignments;
- effective permissions;
- future scope such as OWN / ASSIGNED_BATCHES / BRANCH / ORGANIZATION.

RLS/database authorization remains authoritative.

## Loading contract

- Layout/sidebar/header remain mounted.
- Route `loading.tsx` renders content skeletons only.
- Tables may use row skeletons.
- Forms use button/section pending state.
- No full-page “syncing database” takeover for ordinary mutations.
- Long-running work becomes a background job with progress.

## Form contract

Every ERP form uses:
- React Hook Form;
- shared Zod schema;
- `mode: "onChange"` or suitable onBlur checks;
- visible labels;
- Required/Optional state;
- helper text;
- field/cross-field validation;
- async debounced availability/duplicate checks where needed;
- submit disabled until valid + dirty + not pending;
- server/database validation repeated for trust;
- server field-error mapping where possible.

## Configuration contract

No operational value is hard-coded where management may reasonably change it.

Examples:
- Batch capacity
- Programme/Fee Plan amounts
- Admission activation requirements
- Minimum payment/deposit threshold
- Billing due-day rules
- Teacher teaching-pool %
- Acquisition/retention bonus %
- Discount/scholarship approval thresholds
- Role-permission bundles
- Numbering/document preferences

Integrity rules remain fixed.

## Admission initialization decision

Admission is not “save student + payment”.

```text
Prospect
→ Admission Case
→ Student/Guardian validation
→ Programme Offering
→ Batch
→ Fee Plan Version
→ Initial Billing
→ Activation Policy
→ Active Enrollment / Pending Payment
```

A receipt is created only for real posted payment. An unpaid charge remains due/receivable.

## Initial implementation slices

### Slice A — Shell and registry
- central route registry;
- Sidebar/Header consume same metadata;
- permission filtering;
- active-route matching;
- stable loading behavior;
- access-denied state.

### Slice B — Settings Control Center
- active policy cards;
- role/permission matrix;
- audited publish workflows;
- configuration history.

### Slice C — Action Center
- pending approvals;
- due CRM follow-ups;
- future academic/finance exception feeds.

### Slice D — CRM/Student Bank
- Prospect list;
- Prospect detail/timeline;
- controlled follow-up transitions.

### Slice E — Admission foundation
- Programme Offering;
- Fee Plan;
- Admission Case state machine;
- initial billing;
- enrollment activation.

## Acceptance gate

Dashboard initialization is not complete until:
- Sidebar/Header titles come from one registry;
- unauthorized routes are not shown and are rejected server-side;
- shell remains stable during route loading;
- current forms validate live;
- submit gating is consistent;
- no current operational policy depends on a hidden literal constant;
- Settings is the visible home for configurable behavior;
- CI and database verification pass.
