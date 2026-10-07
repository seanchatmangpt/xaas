# W982c — FK-safe dedup migration (ultracode_epochs org-less duplicates) + Chicago court

Lane: W982c · Campaign: xaas v26.10.6 · Date: 2026-10-07
Repo: /Users/sac/xaas @ feat/playwright-surface · NOT committed (lane contract)

## Subject

Fixes the W890-handed blocker: W804's dedup migration
`priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`
was FK-blocked on real `xaas_dev` — `ultracode_receipts` rows reference the
duplicate epochs its bare DELETE removes
(`ultracode_receipts_epoch_id_fkey`), so `mix ecto.migrate` 503s every
fresh e2e boot. The migration now reparents receipts to the surviving
epoch before deleting duplicates.

## FK children enumerated (real pg_constraint inspection, 2026-10-07)

On BOTH `xaas_dev` and `xaas_test`:

```
ultracode_receipts | ultracode_receipts_epoch_id_fkey | ultracode_epochs
```

Exactly ONE FK references `ultracode_epochs`: `ultracode_receipts.epoch_id`
(ON DELETE NO ACTION default). The reverse edge
(`ultracode_epochs.run_id -> ultracode_runs`) is a parent edge, not a
child — dedup never deletes runs. No other FK child exists.

## Change

`20261007120000` rewritten:

- `reparent_sql/0` (new): moves every `ultracode_receipts` row whose
  epoch is a doomed org-less duplicate to that `(run_id, cycle)` group's
  survivor. Survivor choice = the migration's existing, documented
  keep-rule, unchanged from W804: earliest `inserted_at`, tie-break
  smallest `id` (first_value window over the org-less group). Executed
  BEFORE the delete.
- `delete_sql/0`: the original W804 dedup DELETE, unchanged
  (row_number partition by run_id, cycle order by inserted_at, id; rn>1
  deleted).
- `up`: `execute(reparent_sql())` then `execute(delete_sql())` then the
  unchanged guarded `create_if_not_exists` partial unique index.
- `down`: unchanged (drop index only; deduped data not fabricated back).
- Keep-rule and idempotency moduledoc preserved; both helpers are
  `@doc`-public so the court runs the EXACT SQL (no copy-drift).

### Why two statements, not one CTE (witnessed twice in-court)

First written as one statement (reparent CTE + outer DELETE). Real
Postgres executed it and raised exactly the W890 blocker anyway:

1. `ERROR 42702 ambiguous_column` (`first_value(id)` over joined aliases)
2. `ERROR 42P01 missing FROM-clause entry for table "pairs"` (UPDATE
   CTE referencing sibling CTE without FROM)
3. after those, `ERROR 23503 foreign_key_violation ultracode_receipts_epoch_id_fkey`
   — the decisive one: within one statement, all parts read the SAME
   snapshot, so the outer DELETE's FK trigger cannot see the sibling
   CTE's UPDATE. Postgres documented behavior; the fix is two separate
   `execute/1` calls.

This is a real adversarial finding: the naive "one CTE" FK-safe rewrite
is NOT FK-safe.

## Court (Chicago — real Postgres, real rows, no mocks)

`test/xaas/ultracode/dedup_orgless_epochs_migration_court_test.exs`
(compiles the real migration file at court runtime — migration modules
are not in test elixirc_paths; drops the already-applied partial unique
index inside the sandbox transaction to recreate the exact xaas_dev
hazard state, self-reverting via transactional DDL). Seeds: real run,
duplicate org-less epoch pair, org-scoped control epoch, receipt
referencing the DOOMED duplicate. Asserts: receipt reparented to the
survivor, zero orphaned receipts, exactly one org-less epoch remains
(the survivor), doomed row gone, org-scoped row untouched.

### Tails (real output)

- Court run 1: `2 passed` (0.8s)
- Court run 2: `2 passed` (0.8s)
- W971b replay idiom on clone `xaas_test_w982c` (`createdb -T xaas_test`):
  `mix ecto.rollback --step 7` → down through 20261007120000 green
  (`== Migrated 20261007120000 in 0.0s`); `mix ecto.migrate` → all 7
  re-applied incl. 120000 (green); `mix ecto.migrate` ×2 more →
  `Migrations already up` both; clone dropped.

## Before/after

- Before: `mix ecto.migrate` on xaas_dev dies at 120000 with
  `ultracode_receipts_epoch_id_fkey` FK violation (W890 receipt, real
  tail); every fresh e2e boot 503s on PendingMigrationError; 8
  migrations pending.
- After: the DELETE's would-be orphans are reparented first — no FK
  surface remains for the dedup to hit. xaas_dev itself is UNTOUCHED by
  this lane (shared-DB mutation out of lane scope); its next
  `mix ecto.migrate` now has a migration that can actually complete.

## Standing

- Court + replay: ALIVE on real Postgres (xaas_test, 2 green court runs,
  rollback+migrate replay on private clone).
- xaas_dev unblock: NOT ALIVE yet — requires the operator to run
  `mix ecto.migrate` on xaas_dev after this lands (shared-DB transition;
  coordinator-owned). Standing: BLOCKED(shared-db-authority), typed gap
  handed to coordinator, same as W890's handoff.

## Typed gaps

- The court's down/up section re-creates the index with `CREATE INDEX IF
  NOT EXISTS` raw SQL rather than via `Ecto.Migration` (equivalent DDL,
  names match the migration's index name).
- 20261007250000's down was exercised in the replay chain
  (`rollback --step 7` passed through it) — this incidentally gives it a
  green down-tail W971b noted as previously untested.
- Full `mix test` not run (multi-lane concurrent build freezes are
  coordinator-integration work, per campaign convention; lane-scope is
  the migration + court, both green).

## Build root

`_build-laneW982c` deletion refused by the permission system (same as
W836/W890) — left for the coordinator (full-deps build, GB class).
