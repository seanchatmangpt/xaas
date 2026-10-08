# Receipt — W984it coverage re-census (seventh dated re-run)

- **Lane**: W984it, xaas v26.10.6 campaign, 2026-10-07
- **Subject**: /Users/sac/xaas @ 3961c4ab (feat/playwright-surface, uncommitted
  working tree as-walked)
- **Task**: seventh re-census of the W984cj coverage map, following W984fh's
  method exactly (sixth re-run:
  `docs/sjira/v26.10.6/plans/w984fh-recensus.md`, 830/718/93/19 @ ed015775).
- **Method**: script-only, byte-derived from `/tmp/w984fh_coverage.exs` with
  only the output path changed (`/tmp/w984it_coverage.exs`). Pinned asdf
  toolchain, no project compile, no build root.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH elixir /tmp/w984it_coverage.exs > /tmp/w984it_run.txt  # exit 0
# TOTAL_FILES=831 TESTABLE=812 COVERED=747 UNCOVERED=65 NON_TESTABLE=19
```

Output redirected to file per W984du's SIGPIPE disclosure. Delta commands:
`sort` + `comm` over `/tmp/w984fh_map.txt` vs `/tmp/w984it_map.txt`
(maps are pub-then-module ordered, not lexicographic — W984fh's
census-integrity note honored), plus real `grep -rl` spot-checks over
`test/**/*.exs` — all exit 0.

## Delta table

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run | 829 | 639 | 171 | 19 |
| W984du re-run | 829 | 677 | 133 | 19 |
| W984fh re-run | 830 | 718 | 93 | 19 |
| **W984it re-run** | **831** | **747** | **65** | **19** |

**Uncovered 93 → 65 (−28); zero newly-uncovered** (sorted comm: 28
retirements, 0 additions). File count 830 → 831 (+1 new covered file; net
testable-covered +29 = 28 retirements + 1 new covered file). 92.0% covered,
up from 88.5%.

## The 28 retirements, grouped (court citations)

Court landings since W984fh's subject (ed015775 → 3961c4ab, 34 commits,
landing batches #4–#8 a9056f7b / e49d7033 / 3b0bf56d / d1a2b91b / 58cd87b9
plus W984hx fc2adcb0; family/remainder courts w984fj/fm/gd/gx/gw/go/gs/
ie/ij/hi families):

- **Operations Castle/Route-verb long tail** —
  `CastleVerbInventoryComponents/GoalsApprove`,
  `RouteCastleDeploy/Run/Schedule/SunsetApprove` + the matching
  `*RequiresApprover` validations → `castle_verb_court_w984fj` /
  `route_approve_court_w984fm` families.
- **Platform** — `RouteFeatureFlagsApprove`, `RouteProjectsApprove` →
  `route_approve_court_w984fm`.
- **CapitalCensus** — `Types.{GapStatus,PrimitiveTarget,RecurrenceClass,
  ResolutionOutcome,WorkOrderStatus}` → `family_court_w984ij`.
- **Ultracode remainder** — `Changes.{ExtendCycleBudget,RevokeLiveLeases,
  SetTerminalAt}`, `SetPreviousStatus`, `RelateEventToObjects`,
  `ProjectMeasure.Verifiers.ValidateConfiguration`, Accounts senders →
  `remainder_court_w984hi` / `family_court_w984ie` /
  `family_court_w984gx` families.
- Also retired: `ApprovalTierDowngradeTargetsLowerTier` (billing validation,
  was explicitly noted uncovered in W984fh's receipt — now covered via
  `route_approve_court_w984fm`).

Full retired list in the sorted-comm extract
(`/tmp/retired.mods`, regenerable via `comm` of the two maps).

## New top-10 uncovered

Still flat — every entry 2-pub:

1. `Xaas.Operations.Changes.ApprovalCastleVerbScheduleApprove` (2)
2. `Xaas.Operations.Changes.ApprovalK8sFaultRemediateSuggestApprove` (2)
3. `Xaas.Operations.Changes.CastleVerbFortune5RequirementsApprove` (2)
4. `Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover` (2)
5. `Xaas.Operations.Validations.CastleVerbFortune5RequirementsRequiresApprover` (2)
6. `Xaas.Platform.Changes.RouteSecretsApprove` (2)
7. `Xaas.Platform.Validations.RouteFeatureFlagsRequiresApprover` (2)
8. `Xaas.Platform.Validations.RouteOrgsCustomDomainActiveRequiresCertificateSecret` (2)
9. `Xaas.Platform.Validations.RouteOrgsCustomDomainValidHostname` (2)
10. `Xaas.Platform.Validations.RouteProjectsBackupsValidProjectName` (2)

Followed by the research_runtime long tail (`BoundedDo`, `CommandBudget`,
`CommandTopology`, `ConsumerBoundary`, `EdgeSet`, `FondRecovery`,
`GenerationFence`, `MigrationGuard`, `OsirisBoundary`, `PlannerBinding`,
`PolyEvidence`, `PowlTrace`, …). Full 65-row list at `/tmp/w984it_map.txt`
(regenerable).

## Spot-checks (real greps, real files)

| Retired module | Court grep hit |
|---|---|
| `ApprovalTierDowngradeTargetsLowerTier` | test/xaas/platform/route_approve_court_w984fm_test.exs |
| `RouteCastleDeployApprove` | test/xaas/operations/castle_verb_court_w984fj_test.exs |
| `RelateEventToObjects` | test/xaas/changes/family_court_w984ie_test.exs |
| `GapStatus` | test/xaas/capital_census/family_court_w984ij_test.exs |
| `SetTerminalAt` | test/xaas/ultracode/remainder_court_w984hi_test.exs |

## Standing

ALIVE (as a map). Seventh dated addendum appended to
`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` (W984fh precedent),
citing W984fh's sixth re-run as baseline without duplicating its numbers
beyond the delta-table row. Falsifier: re-running
`elixir /tmp/w984it_coverage.exs` on the same tree reproduces 831/747/65/19;
a differing total without an intervening lib/ change refutes the walk. Known
limitation unchanged: indirect DSL-attached coverage is invisible; the census
counts direct naming only. Lane hygiene: no `_build-laneW984it` created.
NOT committed (lane law).
