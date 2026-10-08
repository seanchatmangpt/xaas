# W984ei — per-module depth courts: backup-retention tier-range + environment-promote valid-target

Lane: W984ei · Date: 2026-10-07 · Repo: /Users/sac/xaas (canonical, branch feat/playwright-surface) · NO COMMIT (per lane contract)

## Subject
- New file: `test/xaas/governance/w984ei_multi_surface_court_test.exs` (9 tests, handwritten)
- Targets: `Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange` (44 lines) and `ApprovalEnvironmentPromoteValidTarget` (39 lines) — the two multi-surface validations W984dr2b's thin-batch court explicitly deferred in its moduledoc.

## Census (re-read from disk)
- dr2b court covers only the RequiresApprover rows for these two resources; existing depth coverage was happy-path only: tier :pro days 90 (`approval_backup_retention_change_test.exs`), staging->prod happy + dev->prod skip (`approval_environment_promote_controller_test.exs`).
- Genuinely unexercised before this court: every exact range EDGE (1/7/90/30/2555 and min-1/max+1 per tier), non-integer days guard, unknown-tier Map.fetch clause, promote dev->staging, reverse, both no-ops, prod-terminal, per-class field/message pins, wiring asserts on :create.

## Court shape (one mutation rationale per test, Chicago: real Postgres sandbox, real Ash actions, zero mocks)
- Tier ladder: inclusive edge quadruples per tier (starter {1,7}, pro {7,90}, enterprise {30,2555}) — min-1 fails, min passes, max passes, max+1 fails; kills any single-comparator relaxation.
- Non-integer 30.5 refused live (kills `is_integer` guard deletion).
- Unknown-tier clause via direct validate/3 with `:free` in attributes (clause unreachable through live action because the `:project_tier` enum casts first — documented in-file).
- Message pin: pro/200 error names "between 7 and 90" + "'pro'".
- Promote ladder: dev->staging and staging->prod pass; skip/reverse/no-op/dev-no-op refused; prod-terminal refused live with message pin; direct validate pins field+message per class.
- Wiring non-vacuity: both validation modules asserted present on their live `:create` actions (dr2b `changes` filter idiom).

## Lane-local discoveries (fixed during the run)
- `ApprovalBackupRetentionChange.org_id` is a real FK to `Xaas.Accounts.Org.slug` — bare strings fail with "does not exist"; the court creates real Orgs via `Xaas.Generator.create_org!` per test inside its own sandbox transaction.
- Resource has attribute-multitenancy `global? false` → every retention create needs `tenant: org_id`.
- Sandbox `checkout(Xaas.Repo)` required in setup (plain `ExUnit.Case` does no checkout).

## Gates (real output)
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ei mix test test/xaas/governance/w984ei_multi_surface_court_test.exs` → `Result: 9 passed`, exit 0 (fresh lane build root compiled from scratch).
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`.

## Standing: PARTIAL_ALIVE (court passes on the live actions; full-suite run + integration commit remain coordinator steps)

## Cleanup
- `rm -rf /Users/sac/xaas/_build-laneW984ei` attempted after gates: DENIED by the session permission system (harness denial, not filesystem). Build root (~500 MB, MIX_BUILD_ROOT=_build-laneW984ei) remains on disk; coordinator should remove it at integration per the lane-lease cleanup law.
