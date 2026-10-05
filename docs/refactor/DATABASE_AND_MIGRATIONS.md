# Database and migrations

One fresh schema only. `supabase/schema/` holds modular current definitions; deterministic generator writes `supabase/migrations/`. Types are generated from RPC signatures, with parsed runtime JSON read contracts. No old schema, adapters, history backfill, alternative preview migration chain or legacy seed.

Current dependency sequence: 01 academy/access → 02 People → 03 academic directory → 04 essential seed → 05 offering/fees/batch/year → 06 workspace contracts → 07 public enquiries → 08 persistent starter setup → 09 advisory People identity matching → 10 reviewed access requests and workflow-owned identity entry → 11 complete offering setup/history guards.

Each table enables RLS and revokes client direct mutations. Explicit RPC grants and academy/permission checks are the security boundary. Verified Auth identity is required for staff access; selecting Person responsibility cannot grant permissions. Public submissions remain unverified JSON claims. Operator review will attach verified identity/placement later.

School Play–8; Coaching 9–12; adult Training does not require school class/year. Multiple active years supported. Directory school sources must be verified before marked verified. No fabricated real-school seed.

Before first release the disposable development DB is reset from this baseline. After a released baseline, add ordered migrations; do not rewrite applied history. No migration repair trick to overlay old/new incompatible schemas. See ../SETUP.md for exact commands.
