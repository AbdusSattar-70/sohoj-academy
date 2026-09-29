# Current implementation status — Architecture Reset

Updated 2026-09-29.

The repository is being reset from a version-oriented business architecture to a current-state ERP architecture.

## Architecture authority
docs/ARCHITECTURE_NO_VERSIONING.md is the implementation contract for this reset.
The uploaded Product Constitution remains useful for product scope, auditability, accessibility, workflow separation and modular-monolith principles, but version-control behavior is explicitly superseded by the current-state architecture.

## Reset status

| Area | Status | Direction |
| --- | --- | --- |
| Product architecture | Resetting | Current-state records, workflow approvals and audit evidence |
| Fee Plans | Resetting | One editable current Fee Plan per Programme Offering |
| Operating rules | Resetting | Current editable settings; finalized transactions retain needed calculation facts |
| Programme public content | Resetting | Current offering content; approval is workflow state |
| Teacher academic work | In transition | Draft/submission/approval workflow, no user-managed versions |
| Admissions | In transition | Admission inherits current Fee Plan and stores finalized financial facts |
| Finance | In transition | Immutable posted facts + reversal/refund/adjustment |
| Audit | Preserved | Before/after evidence remains mandatory |
| Permissions/RLS | Preserved | Database remains the security boundary |
| Concurrency/idempotency | Preserved | Critical commands remain transaction-safe |
| UI terminology | Resetting | Remove Version N, publish-new-version and retire-version language |
| Database | Planned reset | Replace legacy version-oriented tables/RPCs with current-state contracts |

## Implementation order
1. Freeze the current-state domain contracts.
2. Remove versioning language and controls from all product surfaces.
3. Introduce canonical current-state database tables and commands.
4. Migrate admission/finance dependencies from version IDs to current-state IDs/snapshots.
5. Remove legacy version tables/functions after dependency migration.
6. Run lint, typecheck, build, database/RLS tests and browser acceptance.

## Definition of done
- a normal user never has to create or select a business version;
- editing a current record updates that record directly;
- audit history still shows who/when/why/before/after;
- finalized financial and academic facts remain explainable;
- approval workflows still protect teacher-submitted work;
- admission always reads the current Fee Plan;
- no legacy version terminology leaks into the UI;
- database constraints, RLS, idempotency and concurrency protections still pass.