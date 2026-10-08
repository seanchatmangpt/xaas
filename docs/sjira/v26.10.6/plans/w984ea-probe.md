# W984ea — billing/governance long-tail 2-pub court probe (v26.10.6)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (no commit; lane on shared
canonical checkout). Census input: `/tmp/w984du_map.txt` (W984du fifth re-census),
re-derived fresh on disk 2026-10-07 via CamelCase grep over `test/` plus wiring
greps over `lib/`.

Court file: `test/xaas/billing/gov_long_tail_court_w984ea_test.exs`
(new, this lane only). Command gate:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ea mix test test/xaas/billing/gov_long_tail_court_w984ea_test.exs`

## Per-module dispositions

| module | disposition |
|---|---|
| `Xaas.Billing.Validations.SubscriptionChangeTierNotNoOp` | skipped — already COVERED via live `Subscription.change_tier` action (`test/xaas/billing_deepening_test.exs` real no-op refusal; `test/xaas/billing/subscription_test.exs`) |
| `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` | courted — orphan thin identity change (unwired; wiring grep matches only its own file), real-changeset identity court |
| `Xaas.Billing.Changes.ApprovalQuotaOverrideApprove` | courted — orphan thin identity change, same court |
| `Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove` | courted (identity row) — also already covered via its live `:approve` wiring by `approval_backup_retention_change_test.exs` |
| `Xaas.Governance.Changes.GenerateInternalApiToken` | courted — LIVE `InternalApiToken :issue` action: raw-token metadata returned once, `token_prefix` slice, sha256 hash-before-persistence, raw body absent from stored hash |
| `Xaas.Governance.Changes.ApprovalBreakGlassJustificationReviewApprove` … `ApprovalVendorOffboardingAttestationIssueApprove` (23 further gov `Approval*Approve` thin changes) | courted — parametrized identity court (24 gov rows incl. `DataDestructionCertificateIssueApprove`) |

Notes:
- The 26 thin `*Approve` change modules are identity passthroughs
  (`init/2` + `change/3 -> changeset`); only
  `ApprovalBackupRetentionChangeApprove` is wired to a live action.
  Court asserts `init/2` opts passthrough and structural changeset
  identity on a real `Ash.Changeset.for_update/3` built by each
  consumer resource's real `:approve` action.
- `SubscriptionChangeTierNotNoOp` counted "uncovered" in the census by
  name-grep only; coverage exists through the live action. Not
  double-courted.
- Mock gate: expected `[]` (no mocks/patch in the new file).

## Verification

- `mix test` run: see lane receipt note below (fresh
  `_build-laneW984ea` requires full compile; result recorded at run
  completion).
- Mock gate: `Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test",
  "lib"])` — expected `[]` for this lane's file.
- No commit made (lane law). `rm -rf _build-laneW984ea` attempted at
  lane end; outcome recorded below.

## Ledger

- Build/run output: `Result: 3 passed` (exit 0; 3 tests, 0 failures,
  0.5s async — governance identity court (24 rows), billing identity
  court (2 rows), live `InternalApiToken :issue` court). Fixed en
  route: change/2->change/3 arity, `org_id` must be a real Org FK or
  nil, sandbox checkout required.
- Mock gate output: `[]`
- `rm -rf _build-laneW984ea`: REMOVED (not denied)
