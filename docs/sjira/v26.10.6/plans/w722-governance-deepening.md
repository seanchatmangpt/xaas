# W722 — Governance multitenant approval deepening court

- Lane: W722, xaas v26.10.6 campaign. Repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD `a0723bf6`. Not committed (lane contract).
- New file:
  `/Users/sac/xaas/test/xaas/governance/multitenant_approval_deepening_test.exs`
  (9 tests, `XaasWeb.ConnCase`, `async: false`, sandbox-backed real
  Postgres, real Ash actions, no mocks, no `:eu_ai_act` tag).

## Coverage (4 lenses over the 4 non-global-multitenancy Approval* resources)

- (a) Tenant isolation — org A tenant-scoped read of org B's row is `[]`
  and `Ash.get` under the wrong tenant is a typed
  `Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}`; an
  authorized cross-org `:approve` (org B actor/tenant on org A's row) is
  a real `Ash.Error.Forbidden{errors: [%Ash.Error.Forbidden.Policy{}]}`
  with the named fact `{Xaas.Governance.Checks.ActorOrgMatches, false}`
  in the refusal breakdown; same-org authorized approve control passes.
- (b) Maker-checker — same `requested_by` as `approved_by` is refused on
  all 4 resources with real `Ash.Error.Invalid` carrying "distinct" /
  "approved_by" messages; row re-read: still `approved_by == nil`.
- (c) State machine — approving a nonexistent id is impossible (the only
  lawful path to a record is a tenant-scoped get → typed NotFound);
  missing `approved_by` on `:approve` is a typed `Ash.Error.Invalid` on
  all 4 resources with row state still pending; double-approve pinned to
  its REAL current behavior.
- (d) `ResolveOrgActor` plug path — missing `X-Org-Id` on GET and PATCH
  (`:approve` route) for all 4 path segments is a real halted
  `400 {"error": "missing_org_id"}`; unknown slug is `404 org_not_found`
  (representative + smoke sibling).

## Typed gaps (disclosed, real, from this run)

1. **No double-approve state guard on any of the 4 resources.** None of
   `ApprovalDrFailover`/`ApprovalLegalHoldRelease`/
   `ApprovalDeploymentQuarantine`/`ApprovalBackupRetentionChange`
   carries an "already approved" validation
   (`lib/xaas/governance/validations/` holds only `*RequiresApprover`
   and payload-shape validations). Real observed behavior, pinned in the
   "double-approve" test: a second `:approve` SUCCEEDS and overwrites
   `approved_by` (approver-1 → approver-2, persisted row re-read
   confirms). Only mitigation is social, not mechanical. The test name
   documents this so any future state guard shows up as a real diff.
   (Ledger double-charge on `ApprovalBackupRetentionChange` is already
   separately guarded by `ApprovalBackupRetentionChangeChargeOverage`'s
   `newly_approved?/2` — see
   `test/xaas/governance/approval_backup_retention_change_test.exs`.)
2. `X-Org-Id` remains caller-asserted (not authenticated) — pre-existing
   disclosed limitation of `XaasWeb.Plugs.ResolveOrgActor` (its own
   moduledoc), confirmed unchanged by this court.
3. Pre-existing lib warning surfaced by the run (not session-introduced):
   `approval_dr_failover_requires_open_incident.ex:54` compares
   `region == nil` instead of `is_nil(region)`.

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW722 \
  mix test test/xaas/governance/multitenant_approval_deepening_test.exs
.........
Finished in 2.6 seconds (0.00s async, 2.6s sync)
Result: 9 passed
```

Two consecutive green runs (second run confirming determinism under a
fresh seed). No lint-worthy warnings introduced by the new file (final
run's only warnings are pre-existing in `ash_affidavit`).

## Standing

- The composed court: ALIVE (observed execution on the exact subject,
  2 green runs).
- Gaps 1-2: UNSUPPORTED (state guard / org authentication) — recorded,
  not refused silently.
