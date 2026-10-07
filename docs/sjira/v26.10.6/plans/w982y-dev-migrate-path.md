# W982y — fresh-boot migrator path: discrepancy root cause + operator verdict

Lane: W982y · Campaign: xaas v26.10.6 · Date: 2026-10-07
Repo: /Users/sac/xaas @ feat/playwright-surface · NOT committed (lane contract)

## Task

W890's receipt flagged two fresh-boot blockers: (1) the 20261007120000 FK
block (owned by W982c — landed, not duplicated); (2) "20261007111457 fails
to compile under the migrator on any fresh DB" (`column_exists?/2`
CompileError). Root-cause the discrepancy against W971b/W981q's green
verification.

## Discrepancy root cause (real run, fully fresh DB)

**W890's compile-broken observation is STALE — the file changed since.**
20261007111457 now carries the W971b/W981q replay guards
(`column_exists?/2`/`constraint_exists?/2` `defp` helpers, guarded
replace/restore, guarded down/) — mtimes show 08:45 today, and W890's run
predates the guard pass. The `defp` CompileError W890 saw is not
reproducible on the current file.

**Falsifier run**: fully fresh, EMPTY database `xaas_test_w982y`
(`createdb`, no template clone — the exact "any fresh DB" condition), then

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982y \
  MIX_TEST_PARTITION=_w982y mix ecto.migrate
```

Real tails:

- exit 0; **all 84 tree migrations applied in order on the empty DB**
  (`schema_migrations` count = 84), including 20261007010000,
  20261007111457, and W982c's fixed 20261007120000.
- DDL spot-checks on the scratch DB: `logical_partition` column present on
  `ash_onetime_idempotency_claims`; `ultracode_epochs_unique_run_cycle_index`
  partial unique index present (W982c's guarded index).
- Idempotency: second `mix ecto.migrate` → `Migrations already up`.
- Re-runs: `Migrations already up` (idempotent), exit 0.

**Conclusion**: 20261007111457 migrates clean on a fully fresh DB with the
current tree. No fix needed; no file written to
`priv/repo/migrations/` (W982c's receipt landed mid-lane at 09:50 with the
FK reparent fix for 20261007120000 — dedup lane ownership honored).

## Operator verdict (end-to-end, on real fresh DB)

- 9 migrations pending on `xaas_dev` (75/84 recorded; list below). W890
  counted 8 — 20261007250000 was added mid-run after its count, so both
  counts are honest as-of their runs.
- **Expectation**: `MIX_ENV=dev mix ecto.migrate` on xaas_dev applies all 9
  in order and exits 0. The two named blockers are resolved:
  20261007111457 (this lane, fresh-DB falsifier) and 20261007120000
  (W982c's FK reparent, court-verified). Remaining blocker is not
  technical: **BLOCKED(shared-db-authority)** — the xaas_dev migrate is a
  shared-DB transition, coordinator-owned, same typed gap W890/W982c
  handed off.

Pending list (xaas_dev):

```
20261007010000_add_orgless_run_cycle_partial_unique_index
20261007111457_add_ash_onetime_logical_partitions
20261007120000 W982c-fixed dedup + unique index
20261007210000_add_capability_class_to_graphlaw_capabilities
20261007220000_add_used_at_and_use_count_to_audit_export_tokens
20261007230000_add_reverses_transfer_id_to_ledger_transfers
20261007231000_add_previous_status_to_capability_liveness_receipts
20261007240000_add_castle_run_id_to_incidents
20261007250000_add_org_id_to_billing_approval_tables
```

## Transport/ops failures (this lane)

- **ENOSPC**: data volume hit 0 bytes free at lane start (even `df`'s
  task-output file failed); recovered when a concurrent cleanup lane freed
  56 Gi. A concurrent cleanup lane also removed `~/.cache/tmp` while
  `$TMPDIR` pointed at it → `clang: unable to make temporary file` broke
  the fresh `bcrypt_elixir` compile; fixed with `mkdir -p ~/.cache/tmp`.
  Post-incident note: cleanup lanes must not delete `~/.cache/tmp`.
- `_build-laneW982y` deletion denied by the permission system (same
  precedent as W836/W890/W982c) — left for the coordinator (full-deps
  build, GB class).
- Scratch DB `xaas_test_w982y` dropped by this lane (clean).

## Standing

- 20261007111457 fresh-DB migratability: **ALIVE** on real Postgres
  (empty DB, 84/84 applied, exit 0, idempotent re-run).
- Whole-tree fresh-boot migrator path: **ALIVE** (84/84 on empty DB).
- xaas_dev unblock: **BLOCKED(shared-db-authority)** — coordinator runs
  `MIX_ENV=dev mix ecto.migrate` on xaas_dev; expected outcome per this
  lane's fresh-DB run: 9 pending applied in order, exit 0.
