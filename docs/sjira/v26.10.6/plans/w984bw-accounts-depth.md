# W984bw — Accounts-family depth court (lane receipt)

Lane: W984bw, xaas v26.10.6, branch `feat/playwright-surface` (shared canonical checkout).
Date: 2026-10-07.
Subject: `test/xaas/accounts/org_suspension_validation_depth_test.exs` (new, 5 tests, uncommitted).

## Coverage gap found (evidence)

Read fresh: `lib/xaas/accounts/` (org.ex, org_membership.ex, user/, token/, checks/,
validations/), `test/xaas/accounts/` (4 files), plus `test/xaas_web/controllers/org_controller_test.exs`.

- `test/xaas/accounts/org_test.exs` — IAM read gating, `actor_present()` create,
  `ActorBelongsToOrg` update, slug uniqueness. Never touches `:status`.
- `test/xaas/accounts/org_membership_test.exs` (W980i) — `ActorBelongsToOrg` halves;
  never touches `:status`.
- `test/xaas_web/controllers/org_controller_test.exs` — the suspension validation is
  courted ONLY via HTTP PATCH, only two leaves: nil-reason rejected, with-reason
  succeeds. The empty-string branch, reactivation branch, active-status no-op branch,
  and the fail-closed `%Ash.ForbiddenField{}` branch are uncourted at the Ash layer.
- User/Token: sensitive (repo CLAUDE.md) — NOT courted, per lane contract.
- Conclusion: genuinely uncourted non-sensitive slice EXISTS — the branch-level
  behavior of `Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason` on
  `Org.:update`. Court written there. No typed-finding disposition needed.

## What landed

`test/xaas/accounts/org_suspension_validation_depth_test.exs` — 5 Chicago tests
(real Postgres sandbox, real Ash actions, real policies evaluated, no mocks):

1. empty-string `suspension_reason` suspend rejected (persisted state unchanged).
2. reactivation (suspended -> active) does NOT require a reason (asymmetric rule).
3. status-untouched rename never triggers the rule.
4. happy path at the Ash layer, authorized org-token actor, reason persists.
5. fail-closed `ForbiddenField` branch: actor-loaded (filter-check) data with no
   reason in the request is really rejected; persisted state unchanged.

## Execution receipt

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bw \
  mix test test/xaas/accounts/org_suspension_validation_depth_test.exs
  -> Result: 5 passed (0.8s)
PATH=... mix test test/xaas/accounts/   # x2 fresh runs
  -> Result: 34 passed (both runs)
```

## Mutation kills (non-vacuity)

Ran against `lib/xaas/accounts/validations/org_suspended_requires_suspension_reason.ex`
(backed up, restored after each; `git diff --quiet` clean after restore):

- M1 delete `blank?(%Ash.ForbiddenField{})` -> 4/5 pass, 1 FAIL (test 5). KILLED.
- M2 widen `status == :suspended` to any-status -> 3/5 pass, 2 FAIL (tests 2, 3). KILLED.
- M3 delete `blank?("")` -> **5 passed — SURVIVED** (honest disclosure). Cause:
  Ash casts `""` to `nil` for string attributes before the validation runs, so the
  `blank?("")` clause is dead code / redundant defense-in-depth, indistinguishable
  from `nil` at this layer. Not a hole (the rule still fails closed); a real
  redundancy finding for the validation's owner.

## Lane-process findings (worth the coordinator's attention)

- A stale in-memory struct after any authorized update (Ash re-loads via the read
  policy, so returned structs carry `Ash.ForbiddenField`) makes the next status
  mutation a ZERO-CHANGE no-op update — which Ash runs WITHOUT re-running
  validations. Two of my first-round test failures were my own test bugs from this;
  the test file now re-fetches between every mutation and documents why.
- Shared `lib/` was repeatedly broken mid-edit by other lanes during this lane
  (authority_ledger_export.ex, approval_causal_anatomy.ex, xaas.release_audit.ex,
  quiescent_stop.ex, 3x). All self-healed; waited out per compile-freeze SLA; no
  cross-lane fix applied.

## Standing

- Tests: ALIVE (5/5 green, x2 accounts-dir runs green, 2/3 mutations killed, 1
  disclosed survivor with root cause).
- Build root: `_build-laneW984bw` NOT deleted — `rm` denied by permission system;
  left for coordinator (same precedent as W984aj).
- Not committed, per lane contract. Files touched:
  - test/xaas/accounts/org_suspension_validation_depth_test.exs (new)
  - docs/sjira/v26.10.6/plans/w984bw-accounts-depth.md (this receipt)
