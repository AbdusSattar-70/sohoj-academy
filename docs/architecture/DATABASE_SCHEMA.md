# Fresh database schema

## Ordered installation

| Migration | Responsibility |
| --- | --- |
| 01 | Organization, identity, roles and permissions |
| 02 | Academic directory, offerings, standard fee terms |
| 03 | CRM, admissions, permanent students and lifecycle |
| 04 | Billing, payments and adjustments |
| 05 | Ledger, advances, expenses, referrals and compensation |
| 06 | Teacher academic records |
| 07 | Constraints and indexes |
| 08 | Platform, public CRM, setup and access workflows |
| 09 | Admission and billing commands |
| 10 | Accounting and settlement commands |
| 11 | Teacher academic commands |
| 12 | RLS, grants, audit and integrity triggers |
| 13 | Essential system seed and Auth profile synchronization |

The baseline contains 90 application tables and 113 functions. It installs final definitions directly: no dynamic pg_get_functiondef rewriting or historical rename-and-wrap chain. Private helpers implement transactional stages; only intended RPC entry points receive client execution grants.

## Removed duplication

Removed public_admission_applications, admission_requirement_reviews, public_admission_corrections, admission_consent_documents, programme_offering_public_versions, setting_definitions and setting_versions. Public intake uses Prospects plus its original application snapshot. Consent uses physical receipt evidence. Website controls edit current content. Operational rules use the existing business-rule model.

Obsolete publish_fee_plan and legacy wrapper/approval paths are removed. Admin Finance, transfer and duplicate correction now retain direct authorization evidence. Teacher academic approvals remain. Removed obsolete frontend consumers and regenerated types/database.ts from the new contract.

## Initial data

Seed only organization/campus placeholders, staff roles/permissions, essential payment methods, relationship/source choices, chart of accounts and editable operating defaults. There are no demo students, staff, prospects, academic years, classes, subjects or programmes. Setup creates the actual academic directory. Existing Auth identities can acquire profiles without automatically receiving privileges.

## Integrity and evolution

No direct application INSERT/UPDATE/DELETE grants for anonymous/authenticated clients. Controlled RPCs enforce permission, scope, business transitions and audit. Financial corrections preserve posted evidence; journals remain balanced. Internal fee/policy snapshots preserve historical agreements without exposing version queues to administrators.

After a deployed fresh baseline, append migration 14_<task>.sql and subsequent files. Update generated types and contract consumers together. Do not introduce a second financial/admission model.
