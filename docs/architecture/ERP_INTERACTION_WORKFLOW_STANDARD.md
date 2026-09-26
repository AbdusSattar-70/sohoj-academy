# ERP v2 Interaction, Workflow and Configuration Standard

This document is normative for every internal Sohoj Academy ERP module.

## 1. Configuration over hard-coded operations

Operational values must not be embedded in React components, server actions or SQL trigger fallbacks.

Examples:
- Batch capacity
- Teacher teaching-pool percentage
- Acquisition and retention bonus percentages
- Admission activation requirements
- Payment/deposit requirements
- Due-day rules
- Discount/scholarship thresholds
- Approval requirements and thresholds
- Role/permission bundles
- Communication/document preferences

Seed values are initial policy versions only. Changes are versioned, effective-dated, reasoned and audited.

Structural integrity is not configurable:
- Immutable audit history
- Unique permanent identities
- Receipt only for an actual posted payment
- Posted financial corrections by reversal/adjustment rather than deletion
- Maker-checker separation where the workflow requires approval
- Database authorization and RLS
- Accounting balance/integrity
- Referential integrity

## 2. Form behavior

Internal ERP forms use one shared standard:

1. Persistent visible label for every control.
2. Required / Optional state is explicit.
3. Contextual helper text explains business meaning, not obvious UI mechanics.
4. Zod is the shared validation contract; React Hook Form uses it client-side.
5. Validation mode is onChange / onBlur as appropriate. Do not wait for submit to reveal known validation errors.
6. Cross-field rules update immediately as dependent fields change.
7. Async uniqueness/availability checks are debounced and field-scoped when needed.
8. Submit is disabled until:
   - required fields are satisfied,
   - the form is valid,
   - a meaningful change exists,
   - no submission is already running.
9. Server validation and database constraints repeat critical validation; client validation is never a trust boundary.
10. On server rejection, return a field error when possible and focus/scroll to the first invalid field.
11. Sensitive actions show impact, require a reason and, where appropriate, explicit confirmation.

## 3. Loading and mutation feedback

The ERP shell does not disappear during normal data loading.

- Sidebar and header remain stable.
- Route content uses section/table/card skeletons.
- A mutation shows pending state on its button, row, dialog or affected panel.
- Background refresh must not replace the entire screen with a loader.
- Use targeted path/tag invalidation rather than refreshing unrelated modules.
- Use optimistic/local updates only when rollback semantics are clear.
- Long-running jobs become tracked jobs with progress/status rather than a blocking request.

## 4. Admission lifecycle

Prospect, Admission Case, Student identity, Enrollment, Billing and Payment are separate business facts.

Recommended default state machine:

```text
PROSPECT
  → ADMISSION_DRAFT
  → ADMISSION_READY
  → ADMISSION_ACCEPTED
  → BILLING_POSTED
  → PENDING_PAYMENT (only when policy requires payment/deposit)
  → ACTIVE_ENROLLMENT
```

The activation policy is configurable.

Default Sohoj policy:
- admission must be accepted;
- initial billing must be posted;
- an invoice/charge/receivable must exist;
- payment is not inherently required for activation unless management configures a deposit/minimum-payment rule;
- if payment is not received, the amount remains due;
- a receipt is generated only when money is actually posted;
- dashboard Active Student counts use ACTIVE enrollment, never a draft/admission-only record.

If management later configures "minimum 25% initial payment before activation", the Admission workflow uses that active policy version without changing code.

## 5. State machines instead of free-form status edits

Every important domain has explicit allowed transitions.

Examples:
- Prospect
- Admission
- Enrollment
- Invoice / charge
- Payment
- Approval
- Attendance finalization
- Assessment/result finalization
- Staff employment
- Leave/substitution
- Advance settlement
- Procurement
- Asset lifecycle

The UI shows only allowed actions; server and database recheck them.

## 6. Policy-version pinning

Any transaction whose result depends on a policy stores the policy/rule version used.

Examples:
- Batch capacity decision
- Admission activation
- Discount approval
- Teacher revenue share
- Retention/acquisition bonus
- Advance settlement

Changing a policy tomorrow must not change the meaning of yesterday's finalized transaction.

## 7. Concurrency and duplicate prevention

Critical workflows require:
- idempotency key/request identity where retries can duplicate business events;
- row locking or equivalent concurrency protection for capacity, payment allocation and numbering;
- unique constraints for permanent identity/reference numbers;
- duplicate-person/prospect detection with explicit merge/review workflows.

## 8. Settings / Control Center

Admin Control Center groups settings by domain:
- Organization & branches
- Master data
- Admissions
- Academics
- CRM
- Finance
- Staff & compensation
- Approvals
- Roles & permissions
- Documents/numbering
- Communication
- Security/operations

Permission changes and policy publications require a reason and audit event. The protected bootstrap ADMIN authority cannot be accidentally stripped of recovery access.

## 9. Operational acceptance

A workflow is not production-ready until:
- new staff can understand it without verbal explanation;
- management can trust the business meaning;
- an auditor can reconstruct the change;
- invalid actions are prevented at UI, server and database layers;
- loading/errors are localized to the affected area;
- keyboard/screen-reader use is viable;
- mock-data and database verification pass.
