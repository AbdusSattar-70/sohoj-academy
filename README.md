# Sohoj Academy ERP

A coaching academy operating system built with Next.js, TypeScript and Supabase/PostgreSQL.

## Current state

`feature/refactor` is the active V3 transition branch. The working tree now contains the first V3 operator slice, while the linked database and remaining migration chain are still V2. **Do not treat this branch as a completed V3 cutover.** The existing linked database contains test data, which the owner has authorized resetting once the new baseline and verification path are ready. Do not treat a build or the new docs as proof that V3 is live.

Start with the [V3 documentation](docs/README.md): product and operator workflow, architecture/integrity, then delivery/database transition. The Google Drive [Product Constitution & Master Blueprint v1.1](https://docs.google.com/document/d/178UvETYjbLQchhWWSN1o5oSKTHOiWwSCmwReStbM7BI/edit) is a long-term reference; the repository V3 decisions set this phase's admin/teacher scope.

## Development

```bash
pnpm install
pnpm dev
```

Provide `.env.local` with `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` for a development project. Do not commit secrets or a service-role key. The current V2 application requires the matching V2 database schema; **do not push its migrations to a newly prepared V3 database**. The delivery guide will document the exact reset/bootstrap commands after the V3 baseline exists.

```bash
pnpm lint
pnpm typecheck
pnpm build
```

The current CI runs these three checks. Database tests and signed-in workflow acceptance remain V3 delivery requirements.

## Phase scope

Bootstrap admin completes admissions and Finance from an actionable case workspace without a general second-person approval step. Teachers work on assigned classes and submit attendance, results, questions and logs for admin approval. Students and guardians do not create accounts; the public homepage design remains intact and its programme content comes from ERP publishing.
