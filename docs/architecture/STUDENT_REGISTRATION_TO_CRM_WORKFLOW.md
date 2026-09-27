# Student registration → CRM → admission workflow

This document describes the acquisition path from public interest through CRM verification to formal admission. It complements [Student lifecycle acceptance](STUDENT_LIFECYCLE_ACCEPTANCE.md) and the Product Constitution.

## Intent

Anyone (student, guardian, teacher, or other) may register interest **without** creating a permanent Student ID or invoice. Admin staff verify and progress the Prospect in CRM. Admission and billing start only after deliberate operator action.

Signed-in ERP users and the public homepage only surface **ACTIVE** programme offerings that admins have prepared (Fee Plan published) and, for the homepage, explicitly curated for public showcase.

## Flow

```
Visitor / guardian
  → /interest (public form)
  → submit_public_interest RPC
  → Prospect (PR-######), status NEW
  → CRM → Prospects (verify, follow-up, status transitions)
  → Admissions (draft → ready → accept → bill → activate)
  → Student (SA-######) + enrollment + invoices
```

### Public interest form (`/interest`)

- Does **not** create a Student, admission case, or fee.
- Creates a Prospect with source snapshot, class/school interests, preferred schedule, and consent.
- Honeypot field suppresses automated spam without CRM pollution.
- Rate / similarity protection is enforced in the database RPC.

### CRM verification

- Staff with `crm.prospects.view` / manage permissions own follow-up.
- Status transitions are constrained (see `modules/crm/prospect-status.ts`).
- Conversion to Student occurs only through the Admissions workflow, not by a silent public click.

### Programme offerings and public showcase

1. Academics creates a Programme Offering (DRAFT).
2. Finance publishes a Fee Plan → offering becomes **ACTIVE**.
3. Academics curates bilingual showcase copy, icon, sort order, and `is_public_showcase`.
4. Homepage `/` loads `list_public_programme_showcase` (ACTIVE + public only).
5. Card **layout, fonts, and colours stay fixed**; only curated content changes.
6. If no curated offerings exist, the homepage uses a static fallback so the site never looks empty.

Migration: `0022_v2_programme_offering_public_showcase.sql`  
RPCs: `update_programme_offering_showcase`, `list_public_programme_showcase`  
Audit action: `UPDATE_SHOWCASE`

### What signed-in users see

Operational screens (batches, admissions, enrollment) already filter on ACTIVE offerings and published plans. Public marketing surfaces only the curated subset.

## Permissions

| Activity | Permission |
| --- | --- |
| Submit public interest | anon (RPC grant) |
| View / manage prospects | `crm.prospects.view` / manage |
| Create offering | `academics.manage` |
| Publish Fee Plan | `finance.billing.manage` |
| Curate public showcase | `academics.manage` |
| Create admission from prospect | `admissions.create` |

## Operator checklist

1. Apply migrations through **0022**.
2. Create offering → publish Fee Plan → mark public showcase with bilingual copy.
3. Confirm `/` shows the curated cards (or fallback).
4. Submit a test interest → open CRM → progress status → open Admissions.
5. Complete Ready → Accept → Bill → Activate as in existing admission acceptance docs.

## Non-goals

- Homepage visual redesign (explicitly out of scope).
- Automatic conversion of Prospect → Student without admission workflow.
- Exposing DRAFT or RETIRED offerings on public surfaces.
