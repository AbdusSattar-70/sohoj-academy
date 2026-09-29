# Sohoj Academy ERP — No Business Version Control

**Status:** Product and architecture requirement  
**Date:** 2026-09-29  
**Applies to:** The entire Sohoj Academy application

## 1. Fundamental requirement

Sohoj Academy does **not** need business version control.

This is a product requirement, not a Fee Plan-specific rule.

The application must be designed around the simple operating model:

**Open the current record → Edit it → Save it → Audit the change**

Users should work with the current state of the business, not with Version 1, Version 2, Version 3, published versions, retired versions, or superseding versions.

Git/GitHub source-code version control is separate and is not affected by this requirement.

## 2. What “no version control” means

Business users must not be required to:

- create a new version to change a record;
- publish a new version to make a change active;
- retire an old version;
- choose between business versions;
- maintain Version 1 / Version 2 / Version 3;
- provide a “next version” effective date;
- manage a version history as part of normal operations;
- understand database version numbers in order to use the system.

The application should not present business configuration as a collection of competing versions.

Instead, there is one **current business record** wherever the domain requires a current record.

## 3. What happens when something changes

For a normal editable master or configuration record:

1. User opens the current record.
2. User changes the required fields.
3. User provides a reason when the domain requires one.
4. User saves.
5. The current record is updated.
6. The system automatically creates an audit event.

The user's job is to manage the current business state.

The system's job is to preserve evidence of how that state changed.

## 4. Audit is not version control

The application still requires a strong audit trail.

Audit should record, where applicable:

- who made the change;
- when it happened;
- what record was changed;
- what the previous values were;
- what the new values are;
- why the change was made;
- which workflow or request caused the change;
- correlation/request identifiers;
- relevant approval information.

This history exists for accountability, investigation, reporting and compliance.

It must **not** turn into a user-managed version-control workflow.

The distinction is:

**Version control:** “Create Version 2 and publish it.”

**Audit:** “The current record changed from A to B at this time, by this user, for this reason.”

Sohoj Academy requires the second model.

## 5. Fee Plans

Fee Plans are current commercial settings for a Programme Offering.

The intended model is:

**Programme Offering → Current Fee Plan → Current Fee Components**

A user edits the existing Fee Plan and saves the changes.

There should be no routine:

- Version 1;
- Version 2;
- Publish Version;
- Retire Version;
- Next Fee Plan;
- Previous Fee Plan;
- Published Versions list;
- version selector;
- rule saying the next Fee Plan must start after the previous version.

When a Fee Plan changes, the system updates the current Fee Plan and records the change in the audit trail.

If an invoice or other financial transaction has already been finalized, that transaction remains unchanged. It keeps the fee information needed to explain what was charged.

Changing the current Fee Plan must not rewrite finalized financial history.

## 6. Business rules and settings

Operating rules are also current settings.

Examples include:

- admission rules;
- batch capacity;
- billing defaults;
- compensation settings;
- operational limits;
- other management configuration.

Authorized users edit the current setting and save it.

Do not create a new “policy version” merely because a setting changes.

If a finalized transaction depends on a value, the finalized transaction should retain the facts needed to explain its original calculation.

The current setting can then change independently.

## 7. Programme Offerings and public content

Programme Offering information is current information.

Public-facing content belongs to the current Programme Offering.

Normal editing should therefore be:

**Open offering → Edit content → Save → Audit**

Do not create a public-content version merely because the title, description, schedule, requirements or other content changes.

If approval or website publication is required, that is a **workflow state**, not version control.

For example:

- Draft
- Pending Review
- Approved
- Published
- Unpublished

These states describe what is happening to the current record. They do not mean Version 1, Version 2, or Version 3.

If a legal or compliance requirement later requires preservation of exactly what was published at a particular time, the system may keep an internal snapshot. That snapshot is historical evidence, not a user-managed content-version system.

## 8. Academic plans and teacher work

Academic work may legitimately require workflow states.

For example:

**Draft → Submitted → Approved / Rejected → Corrected Submission**

This is not business version control.

The states represent a workflow and responsibility.

When work is submitted or finalized, the system may preserve the submitted/finalized snapshot so that the institution can later establish exactly what was approved.

Teachers and administrators should not have to manage “Academic Plan Version 1” and “Academic Plan Version 2” as normal operating concepts.

## 9. Finance

Removing business version control does **not** mean changing finalized financial records.

Once an invoice, charge, payment, receipt or other financial fact is finalized, it remains immutable.

Corrections use the appropriate financial mechanism:

- reversal;
- refund;
- adjustment;
- compensating entry;
- other controlled correction workflow.

For example, if the current Fee Plan changes after an invoice was issued, editing the Fee Plan must not silently change that existing invoice.

The current configuration and finalized financial history are separate concerns.

## 10. Master data

Master data should normally have one current record.

Examples:

- students;
- guardians;
- staff;
- programmes;
- offerings;
- batches;
- subjects;
- Fee Plans;
- vendors;
- assets;
- operating settings.

Where deletion would break historical relationships, use appropriate archive/inactive/retired states rather than creating replacement versions.

An inactive record is not a version.

It simply means the current record is no longer operational.

## 11. User-interface requirement

The UI must be understandable without knowledge of internal database architecture.

Avoid product labels such as:

- Version;
- Version 1;
- Version 2;
- Version History;
- Published Versions;
- Create Version;
- Publish Version;
- Retire Version;
- Supersede;
- Next Version;
- Previous Version;
- Start after previous version.

Prefer:

- Current;
- Active;
- Edit;
- Save;
- Submit;
- Approve;
- Reject;
- Archive;
- Restore;
- Audit History;
- Change History.

**Audit History** is acceptable because it explains changes to the current record. It must not become a version-selection interface.

## 12. API and domain language

Application APIs should describe business actions, not version management.

Preferred examples:

- `getFeePlan`
- `saveFeePlan`
- `updateOperatingRule`
- `saveProgrammeOffering`
- `updateProgrammePublicContent`
- `submitTeacherWork`
- `approveTeacherWork`
- `archiveRecord`

Avoid introducing new business APIs such as:

- `createFeePlanVersion`
- `publishFeePlan`
- `retireFeePlanVersion`
- `createPolicyVersion`
- `publishPolicyVersion`
- `createPublicContentVersion`

Legacy database objects may temporarily contain names associated with old architecture during migration. Those are implementation details and must not define the product model.

## 13. Database principle

The database should ultimately represent the current-state business model directly.

Where historical evidence is needed, use:

- audit events;
- before/after data;
- finalized transaction snapshots;
- approval records;
- immutable financial records;
- effective dates when the date itself is a business fact.

Do not use a generic version table as the default solution for every editable business object.

A historical record should answer:

**Who changed it? When? What changed? Why? What was finalized?**

It should not force the user to manage:

**Which version should I publish?**

## 14. Migration principle

Existing version-oriented tables or functions may exist because of earlier architecture.

They should be treated as migration/compatibility concerns, not as the product design.

The long-term direction is:

1. Define the current business record.
2. Move active/current data into the current-state model.
3. Preserve audit history.
4. Preserve finalized transaction facts.
5. Preserve required workflow snapshots.
6. Update application commands and queries to operate on current records.
7. Remove obsolete version-management dependencies once nothing depends on them.
8. Verify that no version-control workflow remains in the user experience.

## 15. Acceptance criteria

The architecture is aligned with this requirement only when:

- a normal business change can be made by editing the current record;
- saving does not require creating a new business version;
- users do not manage Version 1 / Version 2 / Version 3;
- there is no routine publish-new-version workflow;
- there is no routine retire-old-version workflow;
- current configuration is clearly identifiable;
- audit history remains available;
- finalized financial records remain immutable;
- workflow approval remains where the business process requires it;
- historical finalized facts remain explainable;
- version terminology does not appear in normal product workflows;
- internal legacy versioning does not leak into the product contract.

## 16. Final product principle

Sohoj Academy should operate on one simple rule:

> **Manage the current business state. Save changes. Audit automatically.**

Approval is used where a business workflow requires approval.

Snapshots are used where finalized historical facts must be preserved.

Financial corrections use controlled financial entries.

But **business version control is not part of the operating model of Sohoj Academy.**
