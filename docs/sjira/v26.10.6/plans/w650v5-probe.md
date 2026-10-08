# W650v5 — coverage burn-down court: ApprovalPatchSlaCreditApplyApprove (billing)

Standing: **ALIVE** (5/5 court tests green on the exact subject; in-family 25/25 regression green; mock gate clean).

## Coordination

All listed probes W984dj4/dj5/dl/dk/di/dm/dn/dp4/dq2/dq3/dr/dr2/dq6/ds2/dr3, W650y4, W650w2, W650v4 honored. Families NOT touched: spg, pentest/sso, gov-changes (running lanes), ultracode, semantics, operations, sjira, marketplace, conference, github-actions, autofde, durable-adapter, gov-types/batch, status-transition. This lane took the **billing** family (unclaimed by any lane).

## Census (2 candidate families + fresh root, `command grep -rlF <CamelCase>` over test/)

Note: the environment wraps `grep` with ugrep `--ignore-files` and census must use `command grep` + CamelCase content match (snake_case basename match misses aliased references — two earlier census passes false-positived on `RecipeWorker`/`SelfDigestRun`, both actually covered; disclosed as census methodology correction W650v5-M1).

1. **ledger/ferroplan bridges non-graphlaw**: `bridges.ex` 6, `ferroplan.ex` 12, `pplan.ex` 17, `ex4pm.ex` 22 test files referencing — **DISPOSITION: covered** (no court needed).
2. **Accounts non-sensitive remainder** (`accounts/checks/*`, `accounts/token/{enforce_single_revoke,revoke_nonce}.ex`, `accounts/validations/*`: 0 direct refs, but each is wired into `org.ex`/`org_membership.ex`/`token.ex` and exercised indirectly via the 7 files under `test/xaas/accounts/` and `accounts_deepening_test.exs` — **DISPOSITION: indirectly covered** (policy/change code fires under real resource-action tests; no standalone court needed).
3. **Fresh-census top state-bearing uncovered module**: initial top (self_digest_run.ex, 389L) and r2rml.ex (283L) were census false positives (alias references), re-censused and covered. True top: **`lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex`** (148 lines, 0 test refs). Confirmed gap: its resource's tests assert approval state only; no test asserts the real Ledger money movement, idempotency, or atomicity. **SELECTED.**

## Court: `test/xaas/billing/approval_patch_sla_credit_apply_approve_court_w650v5_test.exs`

5 tests, real invariants, mutation rationale per test (in the file moduledoc):

1. First approve credits the org's real `Xaas.Ledger` account exactly ($25.00) AND the dedicated `platform:revenue:sla-credits` liability account goes negative — witnesses the W785/W799/W835 `allow_overdraft` opt-in. Kills: skip-credit / wrong-amount / wrong-account mutants.
2. Exact cents→USD conversion: 12345c → $123.45. Kills: dropped `Decimal.div(_, 100)` mutant.
3. Second approve refused typed (`%Ash.Error.Invalid{}`) and no double-credit ($10.00 exactly once). Kills: dropped `filter(expr(is_nil(approved_by)))` guard or `newly_approved?/2` mutants.
4. Self-approval refused, no Ledger account opened. Kills: dropped `RequiresApprover` validation mutants.
5. Forced real `Ledger.Transfer` failure (org_id = platform identifier → from==to, real `VerifyTransfer` rejection) rolls back `approved_by` and leaves no orphaned ledger rows. Kills: `after_action/2`→`after_transaction/2` revert mutants (the module's own disclosed historical bug).

## Execution

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650v5 mix test test/xaas/billing/approval_patch_sla_credit_apply_approve_court_w650v5_test.exs` → **5 passed, 0 failed, 1.6s, EXIT=0** (fresh lane build root, all deps compiled from scratch).
- In-family regression: approval_sla_credit_apply_test + approval_lifecycle_deepening_court_test + approval_patch_sla_credit_apply_controller_test + atomic_retrofit_court_test → **25 passed, EXIT=0**.
- Mock gate `scan_mock_usage(["test"])` → `[]` (clean; final invocation re-ran after build-root deletion, same expected `[]` — the earlier run in the same lane build already printed clean).
- Lane build root `_build-laneW650v5`: deleted once after the court run per cleanup law; a post-deletion mock-gate rerun rebuilt it (full dep recompile, ~25 min) and the final deletion was **BLOCKED(cleanup-permission)** — `_build-laneW650v5` remains on disk for the coordinator to remove.

## Falsifier (what would overturn ALIVE)

Any of the 5 court tests failing on a descendant head, or a mutation of `approval_patch_sla_credit_apply_approve.ex` that survives all 5 (e.g. reverting to `after_transaction/2` yet staying green) — either makes this standing PARTIAL_ALIVE → re-court.
