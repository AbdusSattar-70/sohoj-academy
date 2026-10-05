# Sohoj Academy

Fresh first-version foundation for School, Coaching and Preparation/Training operations. CRM visual design is retained. There is one ERP `/dashboard` and one deployable SQL baseline in `supabase/migrations/`.

[Setup/reset/bootstrap instructions](docs/SETUP.md) · [Architecture](docs/refactor/ARCHITECTURE.md) · [Implemented scope and remaining work](docs/refactor/DELIVERY_STATUS.md)

Implemented: secure academy access, shared People/responsibilities, searchable/editable directory, programme definitions, public catalogue and unverified public enquiries. Programme/offering/fees/batch backend exists; its full operational editor is pending. Admission, payment/receipt, teaching operations and simple finance are planned, not available in this foundation yet.

```bash
pnpm install --frozen-lockfile
pnpm dev
```

Use `pnpm db:baseline` after editing modular SQL sources; `pnpm db:rpc-types` generates RPC types. Generated migrations and types must match source. Essential seed is migration 04; no separate demo/legacy seed. Applied migrations become append-only after release. Before release this development baseline is installed by reset, not overlaid onto the previous schema.

Previous implementation is accessible on `master`; this branch contains no legacy ERP/schema runtime or parallel preview app. Never commit credentials.
