# Receipt — W984du coverage re-census (fifth dated re-run)

- **Lane**: W984du, xaas v26.10.6 campaign, 2026-10-07
- **Subject**: /Users/sac/xaas @ 53b905ac (feat/playwright-surface, uncommitted
  working tree as-walked)
- **Task**: fifth re-census of the W984cj coverage map after the depth-probe
  wave (~30 court files: W984dq3 durable-adapter, W984dq6 spg, W984ds
  validations, W984dr types, W984dr2/dr2b gov-batch, W650w/y families,
  W650h21 provider-mesh, W650za incident-lifecycle).
- **Method**: W984cj/W650h8/W650z8 CamelCase-aware census, script-only
  (`/tmp/w984du_coverage.exs`, derived from `/tmp/w650z8_coverage.exs` — output
  path changed only). No project compile, no build root.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w984du_coverage.exs > /tmp/w984du_run.txt  # exit 0
# TOTAL_FILES=829 TESTABLE=810 COVERED=677 UNCOVERED=133 NON_TESTABLE=19
```

(First invocation piped through `head` — SIGPIPE killed the run before the map
file was written; re-run redirected to a file, exit 0. Disclosed transport
failure, no data impact.)

Delta commands: sort/comm over `/tmp/w650z8_map.txt` vs `/tmp/w984du_map.txt`;
CamelCase `grep -rl` spot-checks over `test/**/*.exs` — all exit 0.

## Delta table

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run (baseline) | 829 | 639 | 171 | 19 |
| **W984du re-run** | **829** | **677** | **133** | **19** |

**Uncovered 171 → 133 (−38); zero newly-uncovered; file count unchanged at
829** — the depth-probe wave landed test files only, so the file count held
while covered rose 639 → 677 (+38, exactly the retirement count).

## The 38 retirements, grouped

- **Governance thin-batch courts** (`test/xaas/governance/w984dr2b_gov_thin_batch_court_test.exs`,
  `w984ds2_sso_mappings_depth_court_test.exs`, siblings): all 24 remaining
  governance `Approval*RequiresApprover` / `Approval*Valid*` validations +
  `InternalApiTokenNotAlreadyRevoked` (25 modules).
- **Operations incident-lifecycle court** (`test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs`):
  `IncidentPostmortemFinalRequiresResolved`, `IncidentResolvedAtRequiresResolved`,
  `ApprovalPatchSlaCreditApplyApprove` (3).
- **Ultracode provider-mesh court** (`test/xaas/ultracode/provider_mesh/runtime_loop_worker_court_w650h21_test.exs`):
  `ProviderWorker` (4 pub), `ReconciliationLoop` (3), `CapabilitySet`,
  `FailureSet` (4).
- **Library court** (`test/xaas/library/reactors/student_profile_sub_reactor_test.exs`):
  `StudentProfileSubReactor` (1).

Full 38-row list at `/tmp/w984du_run.txt` / regenerable via the script above;
sort/comm diff against `/tmp/w650z8_map.txt` reproduces exactly these 38 with
zero symmetric-difference entries.

## New top-10 uncovered

| # | Pub | Module |
|---|---|---|
| 1 | 4 | `Xaas.Library.ILSRepo.FixtureAdapter` |
| 2 | 3 | `Xaas.Billing.Changes.ApprovalPricingOverrideApprove` |
| 3 | 3 | `Xaas.Governance.Checks.FreezeWindowActive` |
| 4 | 3 | `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` |
| 5 | 2 | `Xaas.Actuation.Validations.CausalAdmission` |
| 6 | 2 | `Xaas.AwsRepo.AwsAdapter` / `Xaas.AwsRepo.FixtureAdapter` |
| 7 | 2 | `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` |
| 8 | 2 | `Xaas.Billing.Changes.ApprovalQuotaOverrideApprove` |
| 9 | 2 | `Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier` / `SubscriptionChangeTierNotNoOp` |
| 10 | 2 | Governance changes 2-pub long tail (BackupRetention, BreakGlassJustificationReview, ChangeOfControlNotify, CmekKeyBinding, …) |

Full 133-row list at `/tmp/w984du_map.txt` (regenerable).

## Spot-checks (real greps, real files)

| Retired module | Court grep hit |
|---|---|
| `ApprovalCmekKeyBindingRequiresApprover` | test/xaas/governance/w984dr2b_gov_thin_batch_court_test.exs |
| `ApprovalSsoRoleMappingUpdateValidMappings` | w984dr2b… + test/xaas/governance/w984ds2_sso_mappings_depth_court_test.exs |
| `ProviderWorker` / `CapabilitySet` | test/xaas/ultracode/provider_mesh/runtime_loop_worker_court_w650h21_test.exs |
| `StudentProfileSubReactor` | test/xaas/library/reactors/student_profile_sub_reactor_test.exs |
| `IncidentPostmortemFinalRequiresResolved` | test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs |

## Standing

ALIVE (as a map). Fifth dated re-run addendum appended to
`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` (W650h8 precedent), citing
W650z8's fourth re-run (`docs/sjira/v26.10.7/plans/w650z8-recensus-receipt.md`)
as baseline without duplicating its numbers. Falsifier: re-running
`elixir /tmp/w984du_coverage.exs` on the same tree reproduces 829/677/133/19;
a differing total without an intervening lib/ change refutes the walk.
Known limitation unchanged: indirect DSL-attached coverage is invisible;
retired gov/ops validations may be exercised indirectly — the census counts
direct naming only.
Lane hygiene: no `_build-laneW984du` created. NOT committed (lane law).
