# Receipt — W984fh coverage re-census (sixth dated re-run)

- **Lane**: W984fh, xaas v26.10.6 campaign, 2026-10-07
- **Subject**: /Users/sac/xaas @ ed015775 (feat/playwright-surface, uncommitted
  working tree as-walked)
- **Task**: sixth re-census of the W984cj coverage map after the
  court/depth-probe wave (W984eh/en/eo/dy/dz/dx/dw/ee/ej/ea courts).
- **Method**: W984cj/W650h8/W650z8/W984du CamelCase-aware census, script-only
  (`/tmp/w984fh_coverage.exs`, byte-derived from `/tmp/w984du_coverage.exs` —
  output path changed only). No project compile, no build root, pinned asdf
  toolchain.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w984fh_coverage.exs > /tmp/w984fh_run.txt  # exit 0
# TOTAL_FILES=830 TESTABLE=811 COVERED=718 UNCOVERED=93 NON_TESTABLE=19
```

Output redirected to file per W984du's SIGPIPE disclosure — no transport
failure this run. Delta commands: sorted `sort`/`comm` over
`/tmp/w984du_map.txt` vs `/tmp/w984fh_map.txt` (raw `comm` without `sort` is
unsound here — the maps are pub-then-module ordered, not lexicographic), plus
real `grep -rl` spot-checks over `test/**/*.exs` — all exit 0.

## Delta table

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run | 829 | 639 | 171 | 19 |
| W984du re-run | 829 | 677 | 133 | 19 |
| **W984fh re-run** | **830** | **718** | **93** | **19** |

**Uncovered 133 → 93 (−40); zero newly-uncovered** (sorted comm: 40
retirements, 0 additions). File count 829 → 830 (+1: new
`lib/xaas/compat/otp29_map_update.ex` OS-20 typed guard, itself covered by
`test/xaas/compat/otp29_map_update_court_test.exs` — testable-covered +41 =
40 retirements + 1 new covered file; 88.5% covered, up from 83.6%).

## The 40 retirements, grouped (court citations)

- **Billing gov-long-tail / approval-approve courts** (`test/xaas/billing/gov_long_tail_court_w984ea_test.exs`
  + siblings, W984ea/ee/ej/ea family): the ~26 `Approval*Approve` change
  modules (CmekKeyBinding, PricingOverride, QuotaOverride,
  InvoiceReconciliationApprove, BackupRetention, BreakGlassJustificationReview,
  ChangeOfControlNotify, SsoRoleMappingUpdate, …).
- **`test/xaas/billing/` validations**: `ApprovalTierDowngradeTargetsLowerTier`
  remains covered-adjacent but the census still counts it uncovered — noted
  explicitly, not silently dropped.
- **`freeze_window_active_deepening_test.exs`** (W984eh): `FreezeWindowActive` (3 pub).
- **`causal_admission_depth_test.exs`** (W984en): `CausalAdmission` (2 pub).
- **`aws_repo_adapters_deepening_test.exs`** (W984dy): `AwsAdapter`,
  `FixtureAdapter`, `ILSRepo.FixtureAdapter` (former #1, 4 pub).
- **`retain_until_passed_w984dv_test.exs`** (W984dw): `RouteProjectsBackupsRetainUntilPassed` (3 pub).

## New top-10 uncovered

The list is flat: every remaining entry is 2-pub. Led by
`Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier` and a
Castle/Route-verb operations long tail (`ApprovalCastleVerbScheduleApprove`,
`ApprovalK8sFaultRemediateSuggestApprove`, `CastleVerbFortune5Requirements*`,
`CastleVerbInventoryComponents/Goals*`, `RouteCastleDeploy/Run/Schedule/Sunset*`
changes + matching `*RequiresApprover` validations, plus
`Platform.Changes.RouteFeatureFlagsApprove` / `RouteProjectsApprove`).

Full 93-row list at `/tmp/w984fh_map.txt` (regenerable).

## Spot-checks (real greps, real files)

| Retired module | Court grep hit |
|---|---|
| `ApprovalCmekKeyBindingApprove` | test/xaas/billing/gov_long_tail_court_w984ea_test.exs |
| `FreezeWindowActive` | test/xaas/governance/freeze_window_active_deepening_test.exs |
| `CausalAdmission` | test/xaas/actuation/causal_admission_depth_test.exs |
| `AwsAdapter` | test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs |
| `RouteProjectsBackupsRetainUntilPassed` | test/xaas/platform/retain_until_passed_w984dv_test.exs |

## Standing

ALIVE (as a map). Sixth dated re-run addendum appended to
`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` (W984du precedent),
citing W984du's fifth re-run
(`docs/sjira/v26.10.6/plans/w984du-recensus.md`, 829/677/133/19) as baseline
without duplicating its numbers beyond the delta-table row. Falsifier:
re-running `elixir /tmp/w984fh_coverage.exs` on the same tree reproduces
830/718/93/19; a differing total without an intervening lib/ change refutes
the walk. Known limitation unchanged: indirect DSL-attached coverage is
invisible; the census counts direct naming only. One census-integrity note:
the raw (unsorted) `comm` between maps is meaningless — maps are pub-then-
module ordered; sort before diffing.
Lane hygiene: no `_build-laneW984fh` created. NOT committed (lane law).
