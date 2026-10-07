# W846 — Schema/Migration Consistency Court

- **Lane**: W846 (xaas v26.10.6 campaign)
- **Subject**: /Users/sac/xaas, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **New file**: `test/xaas/schema_migration_consistency_test.exs` (uncommitted, per lane contract)
- **No commit made.** `_build-laneW846` NOT deleted — `rm -rf` was denied by the
  permission system in this session; the lane build root remains on disk for
  coordinator cleanup (per fanout lease law, this is an incomplete lane cleanup —
  typed GAP below).

## Order

Backlog item from W726 index-rename + W737/W804 migration series: nothing courted
that the test DB's schema matches what the migrations produce from scratch.
Falsifier closed by real SQL introspection of `xaas_test` (read-only
`pg_indexes` / `pg_constraint` / `information_schema.columns` via `Xaas.Repo.query/2`),
no fresh DB booted, no mocks.

## Court contracts enforced (all green)

- (a) W726-renamed witness identity indexes exist under exact new names on the
  real `xaas_test` DB:
  `witness_certified_receipts_unique_subject_payload_index` on
  `witness_certified_receipts`; `witness_verification_keys_unique_kid_index` on
  `xaas_test.witness_verification_keys`.
  W737/W804 `ultracode_epochs_orgless_run_cycle_index` exists on
  `ultracode_epochs` AND is `indisunique = true` with predicate containing
  `org_id ... IS NULL` (real properties, not name-only).
- (b) W786 `logical_partition` column present on all three `ash_onetime_*`
  tables (idempotency_claims / nonce_claims / response_payloads).
- (c) Rename completeness: zero old-name witness indexes coexist with new names
  (`witness_certified_receipts_subject_payload_hash_hex_index` and
  `witness_verification_keys_kid_index` absent). W786 constraint replacement
  end-state: `ash_onetime_idempotency_claims` carries exactly one unique
  constraint, `ash_onetime_idempotency_claims_logical_collision_key` over
  `[logical_partition, operation_hash, scope_hash, key_hash]` — the legacy
  3-column global constraint is gone.
- (d) Determinism ×2: every introspection asserted equal across two consecutive
  reads, plus a whole-catalog snapshot test (pg_indexes + all three column
  lists) equal across two passes; the file also passed two independent
  `mix test` runs.

## Real command output (tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW846 \
  mix test test/xaas/schema_migration_consistency_test.exs   # run 1
......
Finished in 0.1 seconds (0.00s async, 0.1s sync)
Result: 6 passed

# run 2 (independent, external ×2 determinism)
Finished in 0.4 seconds (0.00s async, 0.1s sync)
Result: 6 passed
```

Earlier red runs (kept honest, no cleanup): 3 intermediate red iterations from
lane-local bugs (sandbox owner covered LegacyRepo only → needed explicit
`Sandbox.start_owner!(Xaas.Repo)`; Postgrex rows are lists not tuples;
`pg_get_expr` predicate text formatting). All real DB facts were confirmed
present in the catalog by direct `mix run` inspection during debugging —
the migration-series end-state was never violated; the test code, not the
schema, was wrong.

## Standing

| item | standing |
|---|---|
| W726/W737/W804/W786 migration-series end-state on `xaas_test` | **ALIVE** (observed execution: 6/6 courts green ×2 runs, real catalog reads) |
| Fresh-create path equivalence (scratch `ecto.create && ecto.migrate` DB) | **UNKNOWN** — this lane deliberately courts the end-state of xaas_test only, per task contract ("without booting another DB"); the guarded renames (`IF EXISTS` both directions) are the migration-level mechanism claimed to make the two paths converge, and part (a)+(c) would catch drift, but no scratch DB was materialized |
| Introspection-from-sandbox safety | **ALIVE** — read-only catalog reads worked; the typed fallback (pin via migration-file contracts) was NOT needed |
| `_build-laneW846` lease cleanup | **BLOCKED** — `rm -rf` denied by session permission system |

## Typed gaps

- `GAP(SCRATCH_DB_NOT_BOOTED)`: fresh-migrate equivalence is inferred from the
  guarded renames + end-state courts, not directly executed.
- `GAP(BUILD_ROOT_LEFT_ON_DISK)`: `_build-laneW846` (MIX_ENV=test lane build)
  remains; coordinator must delete at integration.
- `GAP(NO_COMMIT)`: file uncommitted by lane contract; coordinator owns the
  integration commit.
