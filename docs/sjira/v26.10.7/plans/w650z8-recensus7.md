# W650z8 — coverage re-census addendum (fourth dated re-run)

Lane W650z8, v26.10.7 fleet seal, 2026-10-07. Fourth dated re-run of the
W984cj CamelCase-aware coverage map, following W650h8's third re-run
(`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md`, 829/634/176/19 baseline).
Same method re-implemented fresh (`/tmp/w650z8_coverage.exs`, derived from
W650h8's script; defmodule-source parsing, full-dotted-name + last-segment
alias passes, protocol/mix-task/config-class non-testable filter, column-0
def/defdelegate/defmacro pub heuristic). Real run, no project compile needed,
no build root created.

## Post-W650h13 walk

**829 files — 639 COVERED (78.8%), 171 UNCOVERED, 19 NON-TESTABLE.**

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| **W650z8 re-run** | **829** | **639** | **171** | **19** |

## Delta vs W650h8 baseline: 176 → 171 uncovered (−5)

The depth-probe wave names hypothesized in the lane order (spg_gate,
process_group, durable_close, substitution_policy, manifest_depth,
webhook_delivery, stale_struct, audit_chain_invariant, finding_lifecycle,
delivery_batch, atlassian_cursor, coordinator, override_decision,
sponsor_track, lock_persistence, lock_error_roundtrip, fibo_profile, ex4pm,
substitution) were **already COVERED at the W650h8 baseline** — none appear in
either uncovered list. The W650h13 landings retired a different, smaller set.
Zero newly-uncovered modules (no lib/ files added or renamed since W650h8;
file count unchanged at 829 — the W650h13 landings were test-only + receipt
docs).

Exactly 5 modules retired since W650h8, each spot-verified with a real test
file on disk:

| Retired module (was rank) | Court on disk |
|---|---|
| `Xaas.CS2.FleetContract` (was #1, 4 pub) | `test/xaas/cs2/fleet_contract_test.exs` |
| `Xaas.CS2.GeneratedFleetContract` (was #5, 3 pub) | `test/xaas/cs2/generated_fleet_contract_test.exs` |
| `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow` | `test/xaas/governance/w984dr2_audit_export_token_freeze_court_test.exs` |
| `Xaas.Operations.Validations.IncidentResolvedIsTerminal` | `test/xaas/governance/w984dr2_dr_failover_open_incident_court_test.exs` |
| `Xaas.Ultracode.Validations.LeaseAvailable` | `test/xaas/ultracode/validations_court_w984ds_test.exs` |

The hypothesized depth-probe retirement batch therefore retired **0 of the
176** — those modules were already covered by the earlier W984da–dr / W650w/y
waves; the real −5 came from the W984dr2/ds courts + the CS2 fleet-contract
courts (W650w2 Ex4Pm lineage). `ApprovalCastleVerbScheduleApprove` remains
uncovered in both runs (court landed as a different-name module — a
candidate for a follow-up naming pass, not counted as a retirement).

## New top-10 uncovered

| # | Pub | Module |
|---|---|---|
| 1 | 4 | `Xaas.Library.ILSRepo.FixtureAdapter` (disclosed historical exception — court optional) |
| 2 | 4 | `Xaas.Ultracode.ProviderMesh.ProviderWorker` |
| 3 | 3 | `Xaas.Billing.Changes.ApprovalPricingOverrideApprove` |
| 4 | 3 | `Xaas.Governance.Checks.FreezeWindowActive` |
| 5 | 3 | `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` |
| 6 | 3 | `Xaas.Ultracode.ProviderMesh.ReconciliationLoop` |
| 7 | 2 | `Xaas.Actuation.Validations.CausalAdmission` |
| 8 | 2 | `Xaas.AwsRepo.AwsAdapter` / `Xaas.AwsRepo.FixtureAdapter` |
| 9 | 2 | `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` |
| 10 | 2 | Billing changes/validations batch (ApprovalPatchSlaCreditApplyApprove, ApprovalQuotaOverrideApprove, ApprovalTierDowngradeTargetsLowerTier, SubscriptionChangeTierNotNoOp) |

Full 171-row list: `/tmp/w650z8_map.txt` (regenerable via
`/tmp/w650z8_coverage.exs`, method preserved above).

## Domain shifts (cov/uncov) vs W650h8

governance 53/70 → 54/69; ultracode 130/18 → 131/17; cs2 3/0 → 5/0
(FleetContract pair retired); library 23/3 unchanged (ILSRepo FixtureAdapter
still top). All other domains within ±1.

## Standing

ALIVE (as a map). Same limitations as the original W984cj map: indirect
DSL-attached coverage invisible; last-segment alias pass
conservative-toward-covered. Lane hygiene: `elixir` run directly, no
`_build-laneW650z8` created. Receipt:
`docs/sjira/v26.10.7/plans/w650z8-recensus-receipt.md`.
