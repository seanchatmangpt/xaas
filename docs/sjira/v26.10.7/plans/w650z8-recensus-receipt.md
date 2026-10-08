# Receipt — W650z8 coverage re-census (fourth dated re-run)

- **Lane**: W650z8, v26.10.7 fleet seal, 2026-10-07
- **Subject**: /Users/sac/xaas @ 9f9fbecf (feat/playwright-surface, uncommitted working tree as-walked)
- **Task**: re-census the W984cj coverage map delta after W650h13 landings; W650h8's
  re-census (third re-run) was one generation stale.
- **Method**: W984cj/W650h8 CamelCase-aware census re-implemented fresh as
  `/tmp/w650z8_coverage.exs` (derived from `/tmp/w650h8_coverage.exs`, output path
  changed only). Script-only method — no project compile, no build root.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w650z8_coverage.exs   # exit 0
# TOTAL_FILES=829 TESTABLE=810 COVERED=639 UNCOVERED=171 NON_TESTABLE=19
```

Delta commands (sort/comm/grep over `/tmp/w650h8_map.txt` vs `/tmp/w650z8_map.txt`,
CamelCase spot-greps over `test/**/*.exs`) — all exit 0.

## Delta table

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| **W650z8 re-run** | **829** | **639** | **171** | **19** |

**Uncovered 176 → 171 (−5); zero newly-uncovered; file count unchanged at 829**
(W650h13 landings were test + receipt docs only — no new lib/ modules).

## Retirements (5, spot-verified)

| Module | Court on disk |
|---|---|
| `Xaas.CS2.FleetContract` (was uncovered #1) | `test/xaas/cs2/fleet_contract_test.exs` |
| `Xaas.CS2.GeneratedFleetContract` | `test/xaas/cs2/generated_fleet_contract_test.exs` |
| `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow` | `test/xaas/governance/w984dr2_audit_export_token_freeze_court_test.exs` |
| `Xaas.Operations.Validations.IncidentResolvedIsTerminal` | `exs: w984dr2_dr_failover_open_incident_court_test.exs` |
| `Xaas.Ultracode.Validations.LeaseAvailable` | `test/xaas/ultracode/validations_court_w984ds_test.exs` |

Depth-probe-name hypothesis (spg_gate, process_group, durable_close,
substitution_policy, manifest_depth, webhook_delivery, stale_struct,
audit_chain_invariant, finding_lifecycle, delivery_batch, atlassian_cursor,
coordinator, override_decision, sponsor_track, castle_verb_schedule,
lock_persistence, lock_error_roundtrip, fibo_profile, ex4pm, substitution):
**retired 0 of the 176** — all already COVERED at the W650h8 baseline; the real
−5 came from the W984dr2/ds + CS2 fleet-contract courts.

## New top-10 uncovered

1. `Xaas.Library.ILSRepo.FixtureAdapter` (4)
2. `Xaas.Ultracode.ProviderMesh.ProviderWorker` (4)
3. `Xaas.Billing.Changes.ApprovalPricingOverrideApprove` (3)
4. `Xaas.Governance.Checks.FreezeWindowActive` (3)
5. `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` (3)
6. `Xaas.Ultracode.ProviderMesh.ReconciliationLoop` (3)
7. `Xaas.Actuation.Validations.CausalAdmission` (2)
8. `Xaas.AwsRepo.AwsAdapter` / `Xaas.AwsRepo.FixtureAdapter` (2)
9. `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` (2)
10. Billing changes/validations 2-pub batch (PatchSlaCreditApply / QuotaOverride / TierDowngradeTargetsLowerTier / SubscriptionChangeTierNotNoOp)

## Standing

ALIVE (as a map). Addendum:
`docs/sjira/v26.10.7/plans/w650z8-recensus7.md`, citing W650h8's baseline in
`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md`. Falsifier: re-running
`elixir /tmp/w650z8_coverage.exs` on the same tree reproduces 829/639/171/19;
a differing total without an intervening lib/ change refutes the walk.
Lane hygiene: no `_build-laneW650z8` created. NOT committed (lane law).
