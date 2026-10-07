# W983i — Migration-set integration receipt

Date: 2026-10-07. Lane W983i, xaas v26.10.6 campaign, branch `feat/playwright-surface`.

## Subject

Six owner lanes' migration corpus landed as one atomic commit. Enumeration was
fresh via `git status --porcelain priv/repo/migrations/`:

| file | status | owner lane | owner receipt |
|---|---|---|---|
| `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs` | untracked | W971b (guards) / W981q (down hardening) | `docs/sjira/v26.10.6/plans/w971b-migration-replay.md`, `w981q-migration-down-idempotency.md` |
| `priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs` | untracked | W982c (FK-safe rewrite) | `docs/sjira/v26.10.6/plans/w982c-dedup-fk-remediation.md` |
| `priv/repo/migrations/20261007250000_add_org_id_to_billing_approval_tables.exs` | untracked at lane start; landed mid-lane by another lane at ddb19522 (w982b) — nothing to stage | W970a | `docs/sjira/v26.10.6/plans/w970a-design-wave6.md` |
| `20261007210000`, `20261007220000` | already committed | W971b | `w971b-migration-replay.md` |
| `20261007230000`, `20261007231000` | already committed | W968c | `w968c-design-wave1.md` |
| `20261007240000_add_castle_run_id_to_incidents.exs` | already committed | W970b | `w970b-open-sweep.md` |

Version uniqueness verified against committed migrations: 111457 / 120000 / 250000
collide with nothing. All six owner receipts exist on disk.

## Gate + courts

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983i mix compile --force --warnings-as-errors` → EXIT=0
  (full fresh-lane compile, 212 lib artifacts).
- `mix test test/xaas/migrations/w981q_add_ash_onetime_logical_partitions_replay_test.exs
  test/xaas/ultracode/dedup_orgless_epochs_migration_court_test.exs
  test/xaas/schema_migration_consistency_test.exs` → `Result: 9 passed`
  (court tail verbatim; schema_migration_consistency court was already committed at d9f31c3d).
- Disclosed pre-existing warnings in the dedup court (module-resolution warnings for
  `reparent_sql/0` / `delete_sql/0` via `migration_module()`, runtime-resolved) — tests pass;
  not introduced by this lane.

## Staged files

- `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs`
- `priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`
- `test/xaas/migrations/w981q_add_ash_onetime_logical_partitions_replay_test.exs`
- `test/xaas/ultracode/dedup_orgless_epochs_migration_court_test.exs`
- `docs/sjira/v26.10.6/plans/w983i-migration-integration.md` (this receipt)

## Standing

ALIVE at the exact commit SHA named in the commit message. Commit via `git commit -F`, not pushed.

## Operator note

`xaas_dev` migrate remains operator-owned (W982c handoff): the 2026-10-07 chain
(111457 → 250000) has not been applied to the live dev database by this lane.
