# Sohoj Academy V3 documentation

Status: **design agreed; V3 code and database are not implemented**. Last updated 2026-09-29. Work branch: `feature/refactor`.

Read in this order:

1. [Product and operator workflow](PRODUCT_V3.md) — who uses the ERP, what each person does, navigation, admission and teacher work.
2. [Architecture and data rules](ARCHITECTURE_V3.md) — domain ownership, security, settings, finance, history and interfaces.
3. [Build and database transition](DELIVERY_V3.md) — clean V3 baseline, removal of old code, verification and cutover.
4. [Implementation status](STATUS_V3.md) — what is implemented now, what remains V2, and which verification gates are still pending.

These are the repository's current V3 decisions. The [Product Constitution & Master Blueprint v1.1](https://docs.google.com/document/d/178UvETYjbLQchhWWSN1o5oSKTHOiWwSCmwReStbM7BI/edit) remains a long-term product reference. Where it describes a broader role or approval structure than the current phase, the specific V3 decisions here govern this build.

The repository still contains the **V2 application and migration chain** while V3 is designed. A clean documentation set does not mean the current code or linked database has already been converted. Do not apply the current `supabase/migrations` folder as a V3 baseline or reset the linked database until the new baseline and acceptance tests are ready.
