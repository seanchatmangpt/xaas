# W650h8 — Coverage Re-Census (post-integration burn-down)

Lane: W650h8, xaas v26.10.7 fleet seal. Date: 2026-10-07.
Subject: branch `feat/playwright-surface`, working tree at run time.
Companion addendum: `docs/sjira/v26.10.6/plans/w984cj-coverage-map.md`
(third dated re-run section appended there; identical totals).

## Method

W984cj method, fresh implementation at `/tmp/w650h8_coverage.exs`. Real run:
`PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w650h8_coverage.exs` — pure file
walk, no project compile, no MIX_BUILD_ROOT (no `_build-laneW650h8` created).
Rules: defmodule-source parsing; COVERED iff full dotted name or last segment
(alias pass) appears in `test/**/*.exs` corpus; NON-TESTABLE = protocol-only,
Mix.Tasks.*, config-class last segments; pub = def/defdelegate/defmacro
line heuristic.

## Census delta table

- W984cj as-written: 825 files — 629 covered (76.2%), 193 uncovered, 15 NT
- W984cj re-run (+12 min): 826 — 629, 194, 15
- W650h8 re-run (this lane): 829 — 634 covered (78.3% of 810 testable), 176 uncovered, 19 NT

Uncovered 194 → 176 (delta −18). Coverage 76.2% → 78.3% of testable.
Non-testable 15 → 19: new config-class modules landed mid-campaign
(`Xaas.A2a.Catalog`, `Xaas.Graphlaw.Catalog`, `Xaas.Marketplace.Catalog`/`Pack`,
`Xaas.Witness.Catalog`) — same filter, not a method change.

## What the depth courts retired (spot-verified via real grep)

- `Xaas.SparqlBridge` (former #1, 7 pub) — `test/xaas/sparql_bridge_court_test.exs`
- `Xaas.Operations.AuthorityLedgerExport` (then rank #4, 6 pub) —
  `test/xaas/operations/authority_ledger_export_test.exs`
- `Xaas.Ultracode.SubstitutionPolicy` —
  `test/xaas/generation/substitution_policy_depth_test.exs`
- `Xaas.Ultracode.ProcessGroup` —
  `test/xaas/ultracode/process_group_court_test.exs`
- Also retired: `Xaas.Hddl.Mermaid`, `Xaas.Tunnel.Submit`,
  `Xaas.Accounts.Token.RevokeVerifier`, `Xaas.Actuation.SpgGate`,
  `Xaas.SelfDigest.Shadow`.
- W984cy3's O-corrected ultracode true-uncovered set {DurableClose,
  ProcessGroup, SubstitutionPolicy}: fully retired, all COVERED.

## New top-15 UNCOVERED (pub × zero courts)

1. 4 pub — `Xaas.CS2.FleetContract` (lib/xaas/cs2/fleet_contract.ex)
2. 4 pub — `Xaas.Library.ILSRepo.FixtureAdapter` (lib/xaas/library/ils_repo/fixture_adapter.ex)
3. 4 pub — `Xaas.Ultracode.ProviderMesh.ProviderWorker` (lib/xaas/ultracode/provider_mesh/provider_worker.ex)
4. 3 pub — `Xaas.Billing.Changes.ApprovalPricingOverrideApprove`
5. 3 pub — `Xaas.CS2.GeneratedFleetContract`
6. 3 pub — `Xaas.Governance.Checks.FreezeWindowActive`
7. 3 pub — `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed`
8. 3 pub — `Xaas.Ultracode.ProviderMesh.ReconciliationLoop`
9. 2 pub — `Xaas.Actuation.Validations.CausalAdmission`
10. 2 pub — `Xaas.AwsRepo.AwsAdapter` + `Xaas.AwsRepo.FixtureAdapter`
11. 2 pub — `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove`
12. 2 pub — billing batch: ApprovalPatchSlaCreditApplyApprove,
    ApprovalQuotaOverrideApprove, ApprovalTierDowngradeTargetsLowerTier,
    SubscriptionChangeTierNotNoOp
13. 2 pub — governance batch head: ApprovalBackupRetentionChangeApprove,
    ApprovalBreakGlassJustificationReviewApprove,
    ApprovalChangeOfControlNotifyApprove
14. 2 pub — governance batch tail: ApprovalCmekKeyBinding,
    ApprovalComplianceRotationBlock, ApprovalDeniedPartyOverride,
    ApprovalDeploymentQuarantine, ApprovalDrFailover, ApprovalDsarErasure, …
15. — full long tail: 176 rows at `/tmp/w650h8_map.txt` (non-durable;
    regenerable via the method above).

## Domain shifts (covered / uncovered)

- governance 51/73 → 53/70
- operations 31/28 → 35/26
- ultracode 129/21 → 130/18 raw (0 uncovered under W984cy3's O-corrected
  courtable view)
- platform 10/12 → 10/11; billing 23/7 → 23/6; runtime 60/5 (unchanged);
  research_runtime 22/20 (unchanged)

## Limitations

Same as W984cj: indirect DSL-attached coverage (changes/validations referenced
only inside resource DSL) is invisible — treat entries as "no direct court",
not "untested"; last-segment alias pass is conservative-toward-covered.

## Standing

ALIVE (as a map): real executed census, totals re-read from script output at
write time. Each backlog entry is UNKNOWN until a depth lane opens a direct
court. Lane hygiene: no build root created; nothing committed (per lane law).
